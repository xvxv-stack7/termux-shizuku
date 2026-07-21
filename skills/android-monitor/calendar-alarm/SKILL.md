---
name: calendar-alarm
description: 日历事件+提醒(闹钟模式)。使用时机：用户提到时间安排/计划/日程——"下午三点上课"/"8月15去北京"/"明天记得XX"——主动写入系统日历并设提醒。| Calendar events with reminders (alarm mode). Use when: user mentions time plans, schedules, appointments — proactively insert into system calendar with alarm.
---

# Calendar Alarm — Sub-skill of android-monitor

Insert calendar events with reminders via ADB `content` commands. The Android system calendar handles the actual alarm/notification natively — no separate alarm app needed.

## Proactive Behavior (for Claude Code)

When the user mentions time-related plans in conversation, parse the intent and act without being asked:

| User says | Action |
|---|---|
| "下午三点上课" | Insert today 15:00 event + 0-min reminder |
| "明天早上八点开会" | Insert tomorrow 08:00 event + 0-min reminder |
| "8月15号去北京" | Insert Aug 15 all-day event + 1440-min reminder (day before) |
| "下周五之前交报告" | Insert next Friday 09:00 event + 60-min reminder |
| "记得晚上给老妈打电话" | Insert today 20:00 event + 0-min reminder |

**Decision logic:**
- Time within 24h with specific hour → same-day event, reminder at event time (minutes=0)
- Future date → that date, reminder 1 day before (minutes=1440) or at event time
- Vague deadline ("下周之前") → insert on the deadline date, reminder 1 day before
- After inserting, briefly mention it: "已加到日历，到时候提醒你"

## How It Works

Two-step insert into Android's calendar content provider:

### Step 1: Insert event

```bash
adb shell content insert --uri content://com.android.calendar/events \
  --bind title:s:"Event Title" \
  --bind dtstart:l:<start_timestamp_ms> \
  --bind dtend:l:<end_timestamp_ms> \
  --bind eventTimezone:s:"Asia/Shanghai" \
  --bind calendar_id:i:1
```

### Step 2: Add reminder (alarm mode)

```bash
adb shell content insert --uri content://com.android.calendar/reminders \
  --bind event_id:i:<event_id_from_step1> \
  --bind minutes:i:<minutes_before_event> \
  --bind method:i:1
```

`minutes=0` → alarm fires at event start time (闹钟模式).
`minutes=1440` → alarm fires 1 day before (提前提醒).
`method=0` → 闹钟提醒（响铃+振动）。`method=1` → 静默通知栏提示。

## Python Helper

```python
#!/data/data/com.termux/files/usr/bin/python3
"""calendar_alarm.py — Insert calendar event with alarm reminder."""
import subprocess, re, time, sys

def adb(cmd):
    r = subprocess.run(['adb', 'shell'] + cmd, capture_output=True, text=True)
    return r.stdout

def add_event(title, dt_start_ms, dt_end_ms, minutes_before=0):
    """Insert calendar event + reminder. Returns event_id or None."""
    # Insert event
    adb(['content', 'insert', '--uri', 'content://com.android.calendar/events',
         '--bind', f'title:s:{title}',
         '--bind', f'dtstart:l:{dt_start_ms}',
         '--bind', f'dtend:l:{dt_end_ms}',
         '--bind', 'eventTimezone:s:Asia/Shanghai',
         '--bind', 'calendar_id:i:1'])
    
    # Get newest event ID
    out = adb(['content', 'query', '--uri', 'content://com.android.calendar/events',
                '--projection', '_id:title'])
    ids = re.findall(r'_id=(\d+)', out)
    eid = int(ids[-1]) if ids else None
    
    if eid:
        # Add reminder
        adb(['content', 'insert', '--uri', 'content://com.android.calendar/reminders',
             '--bind', f'event_id:i:{eid}',
             '--bind', f'minutes:i:{minutes_before}',
             '--bind', 'method:i:1'])
    
    return eid

if __name__ == '__main__':
    # Usage: python3 calendar_alarm.py "上课" "2026-07-22 15:00" 0
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('title')
    p.add_argument('datetime')  # YYYY-MM-DD HH:MM
    p.add_argument('--minutes-before', type=int, default=0)
    args = p.parse_args()
    
    from datetime import datetime
    dt = datetime.strptime(args.datetime, '%Y-%m-%d %H:%M')
    ts_ms = int(dt.timestamp() * 1000)
    
    eid = add_event(args.title, ts_ms, ts_ms + 3600000, args.minutes_before)
    print(f'Event {eid}: {args.title} at {args.datetime}' if eid else 'Failed')
```

## Delete Events

```bash
# Delete by ID
adb shell content delete --uri content://com.android.calendar/events --where "_id=<id>"
adb shell content delete --uri content://com.android.calendar/reminders --where "event_id=<id>"
```

## Query Upcoming

```bash
# Events starting from now
adb shell content query --uri content://com.android.calendar/events \
  --projection _id:title:dtstart \
  --where "dtstart > <now_timestamp_ms>" \
  --sort "dtstart ASC"
```

## Known Limitations

- **calendar_id varies**: `calendar_id=1` is the default local calendar on most devices. Verify with `content query --uri content://com.android.calendar/calendars --projection _id:_sync_account` if insert fails.
- **No delete confirmation**: `content delete` silently returns. Double-check with query after deleting.
- **vivo-specific**: `content insert` returns empty on success — don't rely on return value. Always query for the newest event ID after insertion.
- **hasAlarm field**: Set automatically by the system when a reminder row exists. Do not manually set on insert.
