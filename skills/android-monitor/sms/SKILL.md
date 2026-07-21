---
name: sms-monitor
description: [实验性] 给AI一个手机号，让他能跟你短信交流——收到短信→AI读懂内容→生成回复→发回去。部分环节待完善。| [Experimental] Give the AI a phone number for SMS conversations. Some components still under development.
---

# SMS Monitor — Sub-skill of android-monitor

> ⚠️ **状态：实验性，部分验证通过，整体链路待完善。** 基础能力（收发短信）已跑通，但自动回复闭环仍有几个待解决的问题。详见下方「已知待完善」段落。欢迎尝试并反馈。

Give the AI a phone number. When someone texts it, the AI reads the message, understands it, writes a reply, and sends it back.

**Prerequisite: two SIMs / two phone numbers.** The phone running Termux must have an active SIM card — that's the AI's number. The user texts that number from their own phone.

## 🤖 AI Setup

When the user asks to use SMS monitoring, the AI runs these checks automatically:

```bash
# 1. Ensure Termux:API is installed — requires version 1.30 exactly
# (other versions have different SMS command signatures)
pkg list-installed | grep "termux-api/1.30" || {
    echo "需要 Termux:API v1.30，当前版本:"
    pkg list-installed | grep termux-api
    echo "下载: https://f-droid.org/packages/com.termux.api/"
}

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

- Requires Termux:API **v1.30** — other versions have incompatible SMS command signatures
- On dual-SIM devices, set a default SMS SIM to avoid per-message popups:
  ```bash
  adb shell settings put global multi_sim_sms 0         # SIM slot 0
  adb shell settings put global multi_sim_sms_prompt 0   # disable Android prompt
  # vivo/BBK devices additionally require:
  adb shell settings put system bbk_default_sim_setting 0  # disable vivo prompt
  ```
- When using `termux-sms-send -s <subId>`, match to the correct subscription ID.
  Run `adb shell dumpsys isub | grep "id="` to find subId values. Slot 0 is typically subId 1.
- No push — polling only. 60s cron is the floor.
- MMS not accessible via `termux-sms-list`
- RCS/Chat messages go through proprietary Google Messages database, not SMS inbox

## Known Issues & To Be Resolved

This skill has been partially verified on vivo S19 (OriginOS/Android 16) with dual SIM (China Mobile + China Telecom). The following have been tested and the following remain open:

### ✅ Verified Working
- `termux-sms-list` — reading SMS inbox, JSON output stable
- `termux-sms-send` — sending SMS (requires correct subscription ID and SIM prompt suppression)
- 3-second polling daemon — detects new messages within 3s of arrival
- Trigger file mechanism — daemon writes trigger, Monitor pushes to Claude Code

### ❌ Still To Be Resolved
- **Dual-SIM popup**: on vivo/BBK devices, `termux-sms-send` may trigger a SIM selection dialog even after setting `multi_sim_sms`, `multi_sim_sms_prompt`, and `bbk_default_sim_setting`. Root cause not fully isolated.
- **Incoming number mismatch**: on some carrier setups, incoming SMS may arrive from a different number than the one the user sent from (e.g., user sends from 197xxx, arrives as 180xxx or through a forwarding number). The daemon must be configured to match all possible aliases.
- **Timestamp granularity**: `termux-sms-list` provides minute-level timestamps only. Multiple messages arriving in the same minute can cause detection gaps.
- **cc-connect dependency**: the WeChat push channel requires cc-connect with an active session. When the bridge is down, the Monitor-based fallback must be working.
- **Auto-reply loop safety**: no rate limiting or flood prevention on the auto-reply chain. A conversation loop could exhaust daily SMS quotas.

### Next Steps
Contributions welcome on any of the above. The core polling and detection logic is stable; the remaining issues are in device-specific configuration and edge-case handling.
