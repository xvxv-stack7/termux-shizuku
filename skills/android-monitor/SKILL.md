---
name: android-monitor
description: 安卓后台监控+防沉迷系统。使用时机：需要后台监控手机状态、限制应用使用时长、自动锁应用、事件驱动弹窗提醒。| Android background monitoring with anti-addiction. Use when: background phone monitoring, app time limits, auto force-stop, event-driven notifications needed.
---

# Android Monitor — Claude Code Skill

Lightweight background monitoring for Android devices via Termux + ADB. Continuously tracks device state and pushes meaningful events to Claude Code through a Monitor hook, enabling real-time AI-generated notifications. Includes a cumulative app usage limiter with progressive enforcement.

## Sub-skills

- **[Sensors Reference](sensors/SKILL.md)** — 43-sensor catalog with composite inference patterns. Covers motion, orientation, environmental, activity recognition, and event detection sensors accessible via `dumpsys sensorservice`.

## Architecture

```
gaze.sh (system daemon, 60s loop)
  ├─ collect_state()     → dumpsys power / activity / battery
  ├─ detect_event()      → screen wake, walking, binge, low battery, midnight
  ├─ app_limit.sh        → cumulative time tracking + force-stop at threshold
  ├─ send_nudge()        → writes lightweight trigger for Claude Code Monitor
  └─ check_fallback()    → termux-notification if trigger unread for 120s

Claude Code session
  └─ Monitor (persistent) → watches trigger file → AI generates notification message
```

- **gaze.sh** runs as a background daemon (60s poll interval)
- Events go through **Monitor** (event-driven, not cron-polled) to Claude Code
- Claude Code generates natural-language **termux-notification** messages in real time
- Offline **fallback**: if no Claude Code session consumes the trigger within 120s, gaze.sh fires a template notification
- **app_limit.sh** tracks cumulative daily usage per app and force-stops on limit

## Requirements

- Android device with Termux
- ADB over TCP (127.0.0.1:5555) or USB
- `termux-notification` (termux-api package)
- `python3` in Termux
- Claude Code with Monitor tool access

## ⚠️ Configuration Required — Read Before Deploy

**This skill ships with template configs. You MUST customize these before use:**

### Must-change:
1. **`app_limit_config.json`** — Replace example packages (TikTok/RED/Bilibili) with the apps on your device. Find package names via:
   ```bash
   adb shell dumpsys activity activities | grep -oP 'topResumedActivity=\S+\s+\S+\s+\K[^/]+'
   ```
2. **`gaze.sh` — `detect_event()`** — The entertainment app pattern list (`*aweme*|*xhs*|*bili*|...`) uses common Chinese apps. Replace with your target apps' package name fragments.

### Should-check:
3. **`fallback_messages.json`** — Copy the template to `~/.cc-connect/` and rewrite messages in your own voice. gaze.sh will use these instead of the built-in defaults.
4. **Paths** — This skill assumes `~/.cc-connect/` as the data directory. Adjust `HOME_DIR` in gaze.sh if different.
5. **ADB device** — gaze.sh auto-connects to `127.0.0.1:5555`. Change the fallback in `main()` if using USB or a different port.
6. **Monitor command** — The Claude Code Monitor command in this doc references `~/.cc-connect/gaze_trigger.json`. Match this to your actual path.
7. **Calendar (for calendar-alarm sub-skill)** — Verify `calendar_id` with `adb shell content query --uri content://com.android.calendar/calendars --projection _id:name`. Default is `calendar_id=1`.

## Quick Start

### 1. Deploy gaze.sh as background daemon

```bash
# Ensure ADB is connected
adb connect 127.0.0.1:5555

# Start the daemon
nohup bash ~/.cc-connect/scripts/gaze.sh > /dev/null 2>&1 &
```

### 2. Configure app limits

Edit `~/.cc-connect/app_limit_config.json`:

```json
{
  "com.ss.android.ugc.aweme": {"name": "TikTok", "limit_minutes": 40},
  "com.xingin.xhs": {"name": "RED", "limit_minutes": 30},
  "tv.danmaku.bili": {"name": "Bilibili", "limit_minutes": 60}
}
```

### 3. In Claude Code session — set up Monitor

Use the `polling-on` pattern:

```
Monitor persistent: true, command:
TRIGGER="$HOME/.cc-connect/gaze_trigger.json"; LAST_TS=0; while true; do if [ -f "$TRIGGER" ]; then TS=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('ts',0))" 2>/dev/null || echo 0); if [ "$TS" -gt "$LAST_TS" ]; then LAST_TS=$TS; EVENT=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('event',''))" 2>/dev/null || echo ""); FG=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('fg_app',''))" 2>/dev/null || echo ""); echo "TRIGGER:$EVENT|app=$FG|ts=$TS"; fi; fi; sleep 3; done
```

When a trigger arrives, Claude Code generates a natural notification via:

```bash
termux-notification --id "$(date +%s)" --title "Monitor" --content "your message" --priority max
```

## Event Types

| Event | Trigger | Fallback notification |
|---|---|---|
| `woke_up` | Screen off → on (gap > 5 min) | "Screen woke up." |
| `started_walking` | Steps +200 | "Started moving." |
| `stopped` | Steps stalled > 45 min | "No movement for a while." |
| `binge_app` | Same entertainment app > 30 min (per-app once/day) | "Been scrolling a while, take a break." |
| `app_switch` | Leaving entertainment app → non-chat app | "Switched away from entertainment app." |
| `gaming_end` | Left a game app | "Gaming session ended." |
| `low_battery` | Battery dropped below 15% | "Battery low, charge soon." |
| `midnight_phone` | Screen on at 23:00–06:00 (once/night) | "Late night screen time." |
| `long_silence` | No state change > 2.5h | "No activity for a while." |

## Anti-Addiction (app_limit.sh)

Tracks **cumulative daily usage** per app (not just continuous session). Logic:

- Each loop tick: if foreground app is in the config, accumulate elapsed seconds since last check
- Gap ≤ 120s counts as continuous; longer gaps do not accumulate
- **80% threshold** → `warned_N` → termux-toast with remaining minutes (every 5 min max)
- **100% threshold** → `locked` → `am force-stop` + home key + toast
- Resets at midnight

Called automatically by gaze.sh every loop — no separate process needed.

## Custom Fallback Messages

gaze.sh supports custom fallback messages via `~/.cc-connect/fallback_messages.json`. If this file exists, `check_fallback()` randomly picks a message from it instead of using the built-in defaults.

Format:
```json
{
  "woke_up": ["msg1", "msg2", "msg3"],
  "binge_app": ["...", "..."],
  ...
}
```

A template file is provided in this skill directory — copy it to `~/.cc-connect/` and customize. Claude Code can update this file at runtime to inject fresh, contextual fallback messages, keeping the offline voice aligned with the online voice.

## Proactive Notification Pattern

gaze.sh detects events independently. Claude Code can layer a proactive check-in on top:

- Every 30 minutes of silence → check gaze_state.json
- If the user is on an entertainment app, low battery, late-night screen, or has been stationary → generate a custom notification regardless of whether a trigger fired
- Not a cron job — state-driven, not time-driven

Track last contact time in a simple JSON file to avoid spamming:
```json
{"last_notification": <timestamp>, "last_wechat": <timestamp>}
```

## Files

| Path | Purpose |
|---|---|
| `gaze.sh` | Main daemon |
| `app_limit.sh` | Usage tracker + limiter |
| `app_limit_config.json` | Per-app daily minute limits |
| `fallback_messages.json` | Custom fallback messages (template) |
| `sensors/SKILL.md` | 43-sensor reference catalog |
| `sms/SKILL.md` | SMS inbox polling via ADB content provider |
| `calendar-alarm/SKILL.md` | Calendar events with alarm reminders |
| `gaze_state.json` | Current device snapshot (written by gaze.sh) |
| `gaze_trigger.json` | Latest event trigger (consumed by Monitor) |
| `sentinel.log` | Event log |

## Dedup Strategy

- Same event type: max once per 10 minutes
- `binge_app`: once per app per day
- `midnight_phone`: once per night
- `locked` (anti-addiction): once per app per day
- Warn toast: max once per 5 minutes per app

## Token Efficiency

- gaze.sh uses 60s polling (lightweight bash, no LLM involved)
- Trigger file contains only 5 fields: `event`, `fg_app`, `battery`, `screen`, `ts`
- Monitor pushes only when trigger updates (~3–6 events/hour after dedup)
- Anti-addiction enforcement and fallback notifications run entirely in bash
- No CronCreate — Monitor is event-driven, not time-polled

## Design: Why Bash Polling?

The 60-second polling loop in gaze.sh looks naive compared to modern event-driven architectures (inotify, Android BroadcastReceiver, AccessibilityService). It's a deliberate choice based on Android's constraints:

### The Problem
Android does not expose foreground-app-change events or sensor streams to command-line tools. The alternatives all hit walls:

| Approach | Why It Fails |
|---|---|
| **inotify** | No filesystem event fires when the user switches apps. `/proc` and `/sys` don't reflect Activity Manager state changes. |
| **BroadcastReceiver** | Requires a Java/Kotlin APK with `PACKAGE_USAGE_STATS` permission. Can't be triggered from Termux shell scripts. |
| **AccessibilityService** | Needs a signed APK + user consent via Settings. Overkill for a shell-script monitoring system. |
| **logcat tail** | `logcat -s ActivityManager` can stream app-switch events, but logcat output is vendor-specific, rate-limited, and pruned by Android. Not reliable enough for a persistent daemon. |
| **UsageStatsManager API** | Only accessible via Java/Kotlin. No command-line bridge without a helper APK or Shizuku. |

### The Solution
`dumpsys` is the only universal, permission-free interface that exposes real-time Activity Manager state from the shell. The trade-off:

- **Cost**: One `dumpsys activity activities` call per loop (~200ms, negligible CPU)
- **Gain**: Works on every Android device without APK installation, root, or Accessibility consent
- **Compromise**: 60s polling is the floor for reliability — lower intervals risk dumpsys contention and battery drain

### The Bridge to Claude Code
Even with efficient bash polling, piping raw events into Claude Code would burn tokens on noise. The two-layer filter solves this:

```
gaze.sh (bash, always-on)
  → dedup + throttle (same event ≤ 1/10min, binge ≤ 1/day/app)
  → writes 5-field trigger only on meaningful state changes
  → Monitor (Claude Code hook, session-scoped)
    → AI generates custom notification only when trigger fires
```

The Monitor hook adds near-zero token overhead when idle — it only pushes when `gaze_trigger.json` actually changes. This is the key insight: **bash handles the constant monitoring so Claude Code only pays for the interesting moments.**

## Android Version Compatibility

| Feature | Min API | Notes |
|---|---|---|
| `dumpsys activity activities` | 21 (5.0) | Core state query. Stable across all versions. |
| `dumpsys power` | 21 (5.0) | `mWakefulness` field name varies by OEM. Test on target device. |
| `dumpsys battery` | 21 (5.0) | Universal. |
| `dumpsys sensorservice` | 21 (5.0) | Sensor count/names vary by OEM. 43 on vivo S19 (API 35), ~20-30 typical. |
| `dumpsys usagestats` | 23 (6.0) | Required for sleep-analyze. Requires `--user 0` on some devices. |
| `am force-stop` | 21 (5.0) | Anti-addiction enforcement. Universal. |
| `termux-notification` | — | Requires termux-api package. Independent of Android version. |
| `input keyevent 3` | 21 (5.0) | Home key simulation. Works without Accessibility. |
| Shizuku `rish` | 24 (7.0) | Optional: higher-privilege shell for some OEMs where adb is restricted. |
| vivo_activity sensor | 31+ (12+) | Vendor-specific. Not available on all devices. |

**Minimum target**: Android 6.0 (API 23) for full functionality. Android 5.0 (API 21) works with reduced features (no usagestats).

**OEM quirks**: Huawei blocks `dumpsys activity` in EMUI 12+. Xiaomi throttles background dumpsys calls on MIUI 14+. Samsung's `mWakefulness` is under `mWakefulness=` (no regex issue, just note the field exists). Always test on the target device.

## Sub-skills

- **[Sensors Reference](sensors/SKILL.md)** — 43-sensor catalog with composite inference patterns
- **[SMS Monitor](sms/SKILL.md)** — SMS inbox polling + content forwarding via ADB
- **[Calendar Alarm](calendar-alarm/SKILL.md)** — Calendar events with alarm-style reminders via content provider

## Customization

- Adjust `LOOP_SLEEP` in gaze.sh (default 60s)
- Modify `app_limit_config.json` for different apps/limits
- Extend `detect_event()` for custom triggers
- Edit fallback messages in `check_fallback()` for custom wording
