---
name: phone-notify
description: 系统通知+日历——发通知/读通知栏/日历增删改查 | Send notifications, read notification bar, manage calendar events
---

# Phone Notify & Calendar

Notification and calendar operations via termux-api and ADB.

## Prerequisites

```bash
adb connect 127.0.0.1:5555 2>/dev/null
```

## Notifications

### Send
```bash
termux-notification --id $(date +%s) --title "Title" --content "Message" --priority max --vibrate "200,100,200"
```

### List all
```bash
termux-notification-list 2>/dev/null
```

### Filter by app (example: WeChat)
```bash
termux-notification-list 2>/dev/null | python3 -c "
import sys,json
for n in json.load(sys.stdin):
    if n.get('packageName') == 'com.tencent.mm':
        print(f\"{n.get('title','?')}: {n.get('content','?')}\")
"
```

## Calendar

### List events
```bash
adb -s 127.0.0.1:5555 shell content query --uri content://com.android.calendar/events --projection _id:title:dtstart:dtend 2>/dev/null
```

### Add event
```bash
adb -s 127.0.0.1:5555 shell content insert --uri content://com.android.calendar/events \
    --bind title:s:'Event Title' --bind calendar_id:i:1 \
    --bind dtstart:l:<start_ms> --bind dtend:l:<end_ms> \
    --bind eventTimezone:s:Asia/Shanghai
```

### Delete event
```bash
adb -s 127.0.0.1:5555 shell content delete --uri content://com.android.calendar/events --where "_id=<event_id>"
```
