---
name: sms-monitor
description: 短信收件箱轮询+发送。使用时机：需要读取新短信、自动回复短信、监控验证码/银行通知/快递信息。| SMS inbox polling via termux-sms-list (Termux:API). Use when: reading new SMS, auto-reply, monitoring OTP/bank/delivery messages.
---

# SMS Monitor — Sub-skill of android-monitor

## 🤖 AI Setup

When the user asks to use SMS monitoring, the AI runs these checks automatically:

```bash
# 1. Ensure Termux:API is installed
pkg list-installed | grep termux-api || pkg install termux-api -y

# 2. Test SMS access
termux-sms-list 2>&1 | head -3
# If error: tell user to grant SMS permission —
# Android Settings → Apps → Termux:API → Permissions → SMS

# 3. Optional — test sending
termux-sms-send -n 10086 -m "test" 2>&1
# Expected to fail on WiFi-only devices — that's normal
```

---

Poll Android SMS inbox from Termux using `termux-sms-list` (Termux:API). Clean JSON output, no parsing fragility. Send replies via `termux-sms-send`.

**Requires:** Termux:API app installed (F-Droid: `com.termux.api`).

## Read Inbox

```bash
# Returns JSON array of recent SMS messages
termux-sms-list

# Sample output:
# [{"number":"106900901234","body":"【银行】您尾号1234的账户收入500.00元","received":"2026-07-21 14:30:00","type":"inbox"}]
```

## Send SMS

```bash
termux-sms-send -n <number> "<message>"
```

## Polling Script (Python)

```python
#!/data/data/com.termux/files/usr/bin/python3
"""Check SMS inbox for new messages. Write trigger file when found."""
import subprocess, json, os

TS_FILE = os.path.expanduser("~/.cache/sms_last_ts")
TRIGGER = os.path.expanduser("~/.cache/sms_trigger.txt")

# Track last seen timestamp
last_ts = "2000-01-01 00:00"
if os.path.exists(TS_FILE):
    with open(TS_FILE) as f:
        last_ts = f.read().strip()

# Fetch messages
r = subprocess.run(["termux-sms-list"], capture_output=True, text=True, timeout=8)
if r.returncode != 0:
    exit()
msgs = json.loads(r.stdout)

# Find new ones
new_msgs = [m for m in msgs if m.get("received", "") > last_ts]
for m in new_msgs:
    # Write trigger for Claude Code to process
    with open(TRIGGER, "w") as f:
        f.write(f"NEW_SMS|from={m['number']}|body={m['body']}|time={m['received']}")

# Update tracker
if msgs:
    with open(TS_FILE, "w") as f:
        f.write(msgs[-1].get("received", last_ts))
```

## Cron Integration

```
# Check every minute for new SMS
* * * * * python3 ~/bin/sms-check-cron

# Occasional proactive SMS (limited to 2/day, 06:00-00:00 only)
13,43 * * * * python3 ~/bin/sms-nudge-cron
```

## Decision Log

- **Why termux-sms-list instead of adb content query?** `termux-sms-list` returns clean JSON. The ADB approach (`content query --uri content://sms/inbox`) parses raw Row output and has undocumented column variations across OEMs. Not reliable enough.
- **Why cron polling instead of event-driven?** Android does not emit shell-visible events on incoming SMS. Must poll.
- **Why not a Python daemon?** Tried `smsd.py` — it missed messages. Cron is simple and reliable: no state to lose, no daemon to supervise.

## Auto-Reply Architecture

The polling script alone only detects new SMS. To close the loop — detect → generate reply → send — combine three pieces:

### 1. Bash cron (poll and write trigger)

```
* * * * * python3 ~/bin/sms-check-cron
```

The script polls `termux-sms-list`, filters for a specific sender, and writes new message bodies to `~/.cache/sms_trigger.txt`.

### 2. Claude Code CronCreate (read trigger, generate reply)

```
CronCreate cron: "* * * * *" recurring: true durable: true
prompt: "查短信：读 ~/.cache/sms_trigger.txt。如果有新内容，用自然语气生成回复，简洁1-2句话。Bash执行: MSG=\"回复\" && termux-sms-send -n <号码> \"$MSG\"。回完清空trigger。无新内容输出NO_REPLY。"
```

This pushes a prompt to Claude Code every minute. When `sms_trigger.txt` has content, the AI generates a natural-language reply and sends it. When empty, it outputs `NO_REPLY` and costs minimal tokens.

### 3. Dedup tracking

The polling script tracks replied message timestamps in `~/.cache/sms_replied.txt` to avoid replying to the same message twice.

### Full chain

```
SMS arrives → bash cron detects → writes trigger.txt
→ Claude Code CronCreate fires → reads trigger → generates reply → termux-sms-send
→ clears trigger → tracks as replied
```

## Limitations

- Requires Termux:API app (separate install from main Termux)
- No push — polling only. 60s cron is the floor.
- MMS not accessible via `termux-sms-list`
- RCS/Chat messages go through proprietary Google Messages database, not SMS inbox
