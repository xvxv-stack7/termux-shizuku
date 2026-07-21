---
name: android-monitor
description: Android device background monitoring with anti-addiction — gaze.sh daemon + app usage limits + Claude Code event-driven alerts via termux-notification
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
3. **Paths** — This skill assumes `~/.cc-connect/` as the data directory. Adjust `HOME_DIR` in gaze.sh if different.
4. **ADB device** — gaze.sh auto-connects to `127.0.0.1:5555`. Change the fallback in `main()` if using USB or a different port.
5. **Monitor command** — The Claude Code Monitor command in this doc references `~/.cc-connect/gaze_trigger.json`. Match this to your actual path.

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

## Files

| Path | Purpose |
|---|---|
| `gaze.sh` | Main daemon |
| `app_limit.sh` | Usage tracker + limiter |
| `app_limit_config.json` | Per-app daily minute limits |
| `sensors/SKILL.md` | 43-sensor reference catalog |
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

## Customization

- Adjust `LOOP_SLEEP` in gaze.sh (default 60s)
- Modify `app_limit_config.json` for different apps/limits
- Extend `detect_event()` for custom triggers
- Edit fallback messages in `check_fallback()` for custom wording
