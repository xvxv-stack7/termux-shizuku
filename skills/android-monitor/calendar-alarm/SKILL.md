---
name: calendar-alarm
description: 日历事件+闹钟提醒。使用时机：用户提到时间安排/计划——"下午三点上课"/"8月15去北京"/"明天记得XX"——主动设日历或闹钟。| Calendar events + alarm reminders. Use when: user mentions time plans, schedules — proactively set calendar events or alarms.
---

# Calendar & Alarm — Sub-skill of android-monitor

Two-tier time management: **calendar events** for future dates (notification reminder), **CronCreate alarm** for same-day exact times (rings with sound). System calendar content provider handles the event storage; Claude Code CronCreate handles the real audible alarm.

## Proactive Behavior (for Claude Code)

When the user mentions time-related plans, parse the intent and act without being asked:

| User says | Action | Method |
|---|---|---|
| "下午三点上课" | Today 14:45 alarm | CronCreate + termux-notification --sound |
| "明天早上八点开会" | Tomorrow 07:45 alarm | CronCreate + termux-notification --sound |
| "8月15号去北京" | Aug 15 calendar event | content insert event + reminder |
| "下周五交报告" | Deadline calendar event | content insert + 1-day reminder |
| "记得晚上给老妈打电话" | Today 20:00 alarm | CronCreate + termux-notification --sound |

**Decision logic:**
- Specific time within 24h → CronCreate durable alarm (rings with sound + vibration)
- Future date beyond tomorrow → Calendar event with reminder (notification at event time)
- Vague deadline → Calendar event, reminder 1 day before (minutes=1440)

## Approach 1: CronCreate Alarm (Rings — for same-day)

Use Claude Code's built-in `CronCreate` with `durable: true`. At the trigger time, fire all three together for a full alarm experience (sound + vibration + popup):

```
CronCreate({
  cron: "<minute> <hour> <day> <month> *",
  prompt: "termux-media-player play /system/media/audio/alarms/Clock_Alert.ogg && termux-notification --id alarm-$(date +%s) --title '⏰ <title>' --content '<detail>' --priority max --vibrate '1000,200,500,200,1000' --ongoing && termux-dialog confirm -t '⏰ <time> | <title>' -i '<detail>\n\nTime: <full datetime>'",
  recurring: false,
  durable: true
})
```

**Three components:**
- `termux-media-player play <alarm_ogg>` — plays actual alarm ringtone (not just a beep)
- `termux-notification --vibrate --ongoing` — vibration + persistent notification bar entry
- `termux-dialog confirm` — popup overlay showing time and event details

**Why this works:** `durable: true` persists to disk — survives session restarts. `termux-media-player` plays the system alarm sound file directly, not relying on notification channel audio settings. Vibration and popup ensure the alarm is noticed even if media volume is low.

**Available alarm sounds:**
```
/system/media/audio/alarms/Clock_Alert.ogg
/system/media/audio/alarms/Beautiful_Touching.ogg
/system/media/audio/alarms/Crisp_Ring.ogg
/system/media/audio/alarms/Early_In_The_Morning.ogg
```

**Limitation:** Requires Claude Code daemon to be running at trigger time.

## Approach 2: Calendar Event (Notification — for future dates)

Insert events into Android's system calendar. The system calendar app provides notification reminders — useful for dates and planning, but reminder is a **notification, not an audible alarm**.

### Insert event

```bash
adb shell content insert --uri content://com.android.calendar/events \
  --bind title:s:"Event Title" \
  --bind dtstart:l:<start_ms> \
  --bind dtend:l:<end_ms> \
  --bind eventTimezone:s:"Asia/Shanghai" \
  --bind calendar_id:i:1
```

### Add reminder

```bash
# method=0 = alert (may vary by device; method=1 = silent fallback)
adb shell content insert --uri content://com.android.calendar/reminders \
  --bind event_id:i:<event_id> \
  --bind minutes:i:0 \
  --bind method:i:0
```

`minutes=0` → fires at event start. `minutes=1440` → fires 1 day before.

### Get event ID after insert

`content insert` returns empty on some devices. Use the unique title approach:

```python
import subprocess, re

title = f"XK-{int(time.time())}"
subprocess.run(['adb', 'shell', 'content', 'insert', '--uri',
    'content://com.android.calendar/events',
    '--bind', f'title:s:{title}', ...], capture_output=True)

out = subprocess.run(['adb', 'shell', 'content', 'query',
    '--uri', 'content://com.android.calendar/events',
    '--projection', '_id:title'], capture_output=True, text=True).stdout

m = re.search(r'_id=(\d+), title=' + re.escape(title), out)
event_id = int(m.group(1)) if m else None
```

### Delete

```bash
adb shell content delete --uri content://com.android.calendar/events --where "_id=<id>"
adb shell content delete --uri content://com.android.calendar/reminders --where "event_id=<id>"
```

## Why Calendar Reminders Don't Ring

Android calendar reminders are controlled by the calendar app's **notification channel** settings. Even with `method=0`, the system treats them as notifications — whether they make sound depends on the user's notification settings for the calendar app. This is an Android limitation, not a bug in the insert commands.

For an actual audible alarm, use Approach 1 (CronCreate + termux-notification --sound).

## Tested

vivo S19 (OriginOS/Android 16): `content://com.android.calendar` read/write verified. `calendar_id=1` is the default local calendar. `method=0` and `method=1` both produce notification-only reminders. `termux-notification --sound --vibrate --ongoing` produces a full alarm experience.
