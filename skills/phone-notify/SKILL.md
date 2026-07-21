---
name: phone-notify
description: 发通知、读通知栏、操作日历。需要 adb 已连接 + termux-api 已装。
---

# 🔔 通知+日历技能

> 通过手机通知栏跟她说悄悄话，也能帮她管日历。

## 前置条件

```bash
adb connect 127.0.0.1:5555 2>/dev/null
```

## 发通知

```bash
# 替换标题和内容
termux-notification --id $(date +%s) --title "标题" --content "内容" --priority max --vibrate "200,100,200"
```

## 读通知栏

```bash
termux-notification-list 2>/dev/null
```

## 只看微信通知

```bash
termux-notification-list 2>/dev/null | python3 -c "
import sys,json
for n in json.load(sys.stdin):
    if n.get('packageName') == 'com.tencent.mm':
        print(f\"{n.get('title','?')}: {n.get('content','?')}\")
"
```

## 查日历

```bash
adb -s 127.0.0.1:5555 shell content query --uri content://com.android.calendar/events --projection _id:title:dtstart:dtend 2>/dev/null
```

## 添加日历事件

```bash
# 参数: 标题 开始时间戳(ms) 结束时间戳(ms)
adb -s 127.0.0.1:5555 shell content insert --uri content://com.android.calendar/events \
    --bind title:s:'事件标题' --bind calendar_id:i:1 \
    --bind dtstart:l:开始毫秒时间戳 --bind dtend:l:结束毫秒时间戳 \
    --bind eventTimezone:s:Asia/Shanghai
```

## 删除日历事件

```bash
adb -s 127.0.0.1:5555 shell content delete --uri content://com.android.calendar/events --where "_id=事件ID"
```
