---
name: sms-monitor
description: SMS inbox polling via ADB — read, filter, and forward incoming SMS content without Android permissions or APK installation
---

# SMS Monitor — Sub-skill of android-monitor

Poll the Android SMS inbox from Termux shell without any app-level permissions. Uses `content query` on the system SMS content provider via ADB.

## Why This Works

Android's SMS content provider (`content://sms/inbox`) is readable by the shell user (ADB). No root, no SMS permission, no APK needed. The only catch: the URI and column names vary slightly by Android version.

## Quick Commands

```bash
# Latest 5 SMS messages
adb shell content query --uri content://sms/inbox --projection address,body,date --sort "date DESC" | head -20

# Unread only (read=0)
adb shell content query --uri content://sms/inbox --projection address,body,date --where "read=0"

# From a specific sender
adb shell content query --uri content://sms/inbox --projection address,body,date --where "address LIKE '%1069%'" --sort "date DESC"

# Count unread
adb shell content query --uri content://sms/inbox --projection _id --where "read=0" | grep "Row:" | wc -l
```

## Polling Script (minimal)

```bash
#!/data/data/com.termux/files/usr/bin/bash
# sms_poll.sh — check inbox every N seconds, flag new messages
LAST_ID_FILE="$HOME/.cc-connect/.sms_last_id"
INTERVAL=60

while true; do
    LATEST=$(adb shell content query --uri content://sms/inbox --projection _id,address,body,date --sort "date DESC" 2>/dev/null | head -3)
    ID=$(echo "$LATEST" | grep -oP 'Row: \d+ _id=\K\d+' | head -1)
    LAST=$(cat "$LAST_ID_FILE" 2>/dev/null || echo 0)

    if [ "$ID" -gt "$LAST" ]; then
        ADDR=$(echo "$LATEST" | grep -oP 'address=\K[^,]+' | head -1)
        BODY=$(echo "$LATEST" | grep -oP 'body=\K[^,]+' | head -1)
        echo "NEW_SMS|from=$ADDR|body=$BODY|id=$ID"
        echo "$ID" > "$LAST_ID_FILE"
    fi

    sleep "$INTERVAL"
done
```

Integration with android-monitor: add this loop to gaze.sh or run as a separate nohup process. Events can feed into the same `gaze_trigger.json` pipeline.

## Content Provider Reference

| Android Version | URI | Notes |
|---|---|---|
| 4.4–7.x (API 19–25) | `content://sms/inbox` | Standard. `address`, `body`, `date`, `read`, `_id` columns. |
| 8.0+ (API 26+) | `content://sms/inbox` | Same URI. Some OEMs add `seen` column. Samsung adds `sim_id`. |
| 10+ (API 29+) | `content://sms/inbox` | Still works via ADB. App-level access restricted by `READ_SMS` permission, but shell is exempt. |

**Caveat**: On some Android 11+ devices, `content query` may return empty if the default SMS app is not set. Set a default SMS app in Settings first.

## Sending SMS

```bash
# Via am start (opens compose UI — user must manually tap send)
adb shell am start -a android.intent.action.SENDTO -d sms:<number> --es sms_body "<message>"

# Via service call (background send, requires root or Shizuku on some devices)
adb shell service call isms 7 i32 0 s16 "com.android.mms" s16 "<number>" s16 "null" s16 "<message>" s16 "null" s16 "null"
```

The `service call` method is fragile — the service number (`7`) and parameter order change between Android versions and OEMs. Always test on the target device.

## Use Cases

- **OTP/verification code forwarding**: Poll for SMS from short numbers, extract code via regex, forward to another channel
- **Bank/payment alerts**: Monitor transaction notifications, flag unusual amounts
- **Delivery tracking**: Extract tracking numbers from courier SMS
- **Inbox health**: Detect spam accumulation or unread backlog

## Limitations

- **No push**: Must poll. SMS content provider does not emit shell-visible events on new messages.
- **Deletion risk**: Some OEMs auto-delete OTP messages after 24h. Content provider won't find them.
- **MMS**: Not accessible via `content://sms/`. Requires `content://mms/` which has different column schema.
- **RCS/Chat messages**: Not in SMS inbox. These go through Google Messages' proprietary database.
