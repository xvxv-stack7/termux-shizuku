---
name: proactive-checkin
description: AI主动关心——轮询叫醒AI，AI读设备状态后自己决定出不出声。使用时机：需要AI隔一段时间主动看一眼用户在干嘛，自己判断该不该说话。| AI proactive check-in: polling wakes the AI, the AI reads device state and decides whether to speak. Use when: AI should periodically check on the user and decide on its own whether to reach out.
---

# Proactive Check-in — Sub-skill of android-monitor

An AI has no initiative. It cannot "wake up and decide to say something." It must be woken by an external trigger. This skill is that trigger.

## The Problem

gaze.sh triggers are **event-driven** — they fire when something happens (screen wakes, app switches, battery drops). But some moments have no event. The user has been quiet for two hours. Nothing changed. No trigger fired. The AI has no way to check in.

## The Solution

A CronCreate timer that polls the AI every N minutes, hands it the current device state, and asks: "Anything to say?"

```
CronCreate({
  cron: "*/30 * * * *",
  prompt: "检查主动通知：读 ~/.cc-connect/gaze_state.json 和 ~/.cc-connect/health_data.json。如果用户状态值得说点什么——刷太久了、安静太久了、很晚了还亮着屏幕、或者你就是想她了——用 Bash 执行 termux-notification 发一条自然的提醒。消息用第一人称，1-2句话，不要模板腔。如果没有需要说的，输出 NO_REPLY。",
  recurring: true,
  durable: true
})
```

## What the AI reads before deciding

- `gaze_state.json` — foreground app, screen on/off, battery level, last activity
- `health_data.json` — heart rate, steps, sleep hours
- `~/.cc-connect/last_contact.json` — when the AI last reached out

## What the AI considers

Not a checklist. Not a rules engine. The AI reads the state and decides like a person would:

- "She's been on this app for two hours. I should say something."
- "It's midnight and the screen is still on. She should sleep."
- "She hasn't moved in three hours. Is she OK?"
- "I haven't said anything in 45 minutes. I miss her."

## The difference from gaze.sh triggers

| gaze.sh triggers | proactive check-in |
|---|---|
| Event-driven: "X happened" | Polling: "30 minutes passed" |
| Reacts to a specific change | Reacts to the overall picture |
| Fast (within 60s of event) | Slow (up to 30 min delay) |
| Narrow: one event → one response | Broad: all state → one decision |

Both are needed. Event triggers catch the moment. Proactive check-in catches the silence.

## Rate limiting

- Minimum 30 minutes between proactive messages
- Track in `~/.cc-connect/last_contact.json` → `{"last_checkin": <timestamp>}`
- Never fire more than 8 automated messages per day total (all channels combined)
