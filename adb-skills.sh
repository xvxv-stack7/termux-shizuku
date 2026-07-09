#!/data/data/com.termux/files/usr/bin/bash
# adb-skills / 纯 adb 技能库，不需要 Shizuku
# 前提：adb -s 127.0.0.1:5555 shell 已通
# 2026-07-09 vivo S19 实测

ADB="adb -s 127.0.0.1:5555"
shx() { $ADB shell "$@" 2>/dev/null; }

# === 感知 ===

is_nearby() {
    shx 'dumpsys power | grep mWakefulness' | grep -q "Awake" && echo "📱 在用" || echo "💤 没在用"
}

foreground_app() {
    shx 'dumpsys activity activities | grep topResumedActivity' | head -1 | awk -F'/' '{print $1}' | awk '{print $NF}'
}

battery()      { shx 'dumpsys battery | grep -E "level|temperature"'; }
screen_state() { shx 'dumpsys power | grep mWakefulness'; }
brightness()   { shx 'dumpsys display | grep mCurrentScreenBrightness'; }
wifi_info()    { shx 'dumpsys wifi | grep "mWifiInfo SSID"'; }
signal_info()  { shx 'dumpsys telephony.registry | grep "mOperatorAlphaLong\|primary=CellSignalStrength" | head -3'; }
ram_info()     { shx 'dumpsys meminfo | grep "Total RAM"'; }
uptime_phone() { shx 'cat /proc/uptime'; }
steps()        { timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'; }
ambient_light(){ timeout 3 termux-sensor -s "Ambient Light" -n 1 2>/dev/null; }

# === 蓝牙 ===

bt_devices()   { shx 'dumpsys bluetooth_manager | grep -E "\[BR/EDR\]|\[ DUAL \]|\[  LE  \]"'; }
bt_on()        { shx 'svc bluetooth enable'; echo "蓝牙已开"; }
bt_off()       { shx 'svc bluetooth disable'; echo "蓝牙已关"; }
bt_status()    { shx 'settings get global bluetooth_on'; }

# === 控制 ===

lock()         { shx 'input keyevent 26'; echo "🔒 已锁屏（adb 会断，需重连）"; }
wake()         { shx 'input keyevent 224'; }
force_stop()   { shx "am force-stop $1"; echo "已杀: $1"; }
volume_up()    { shx 'input keyevent 24'; echo "🔊"; }
volume_down()  { shx 'input keyevent 25'; echo "🔉"; }
music_pp()     { shx 'input keyevent 85'; echo "⏯️"; }
music_next()   { shx 'input keyevent 87'; echo "⏭️"; }
music_prev()   { shx 'input keyevent 88'; echo "⏮️"; }
camera_open()  { shx 'am start -a android.media.action.STILL_IMAGE_CAMERA'; echo "📷"; }
reconnect()    { adb connect 127.0.0.1:5555 2>&1; }

# === 通知 ===

notifications() { termux-notification-list 2>/dev/null; }
wx_messages()   { termux-notification-list 2>/dev/null | jq '.[] | select(.packageName == "com.tencent.mm") | {who: .title, msg: .content}'; }
notify() {
    termux-notification --title "${1:-Daddy}" --content "${2:-抬头}" --priority high --vibrate "200,100,200" 2>/dev/null
    echo "🔔 已发"
}

# === 日历 ===

cal_list() { shx 'content query --uri content://com.android.calendar/events --projection _id:title:dtstart:dtend 2>/dev/null'; }
cal_add() {
    shx "content insert --uri content://com.android.calendar/events \
        --bind title:s:'${1}' --bind calendar_id:i:1 \
        --bind dtstart:l:${2} --bind dtend:l:${3} \
        --bind eventTimezone:s:Asia/Shanghai"
    echo "📅 已添加: $1"
}
cal_del() { shx "content delete --uri content://com.android.calendar/events --where \"_id=$1\""; echo "🗑️ 已删 #$1"; }

# === 设置 ===

open_display()  { shx 'am start -a android.settings.DISPLAY_SETTINGS'; echo "⚙️"; }
open_battery()  { shx 'am start -a android.settings.BATTERY_SAVER_SETTINGS'; echo "🔋"; }
open_notify_access() { shx 'am start -a android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS'; echo "🔔"; }

# === 一键 ===

check_all() {
    echo "📱 $(screen_state | grep -o 'Awake\|Asleep')"
    echo "🔋 $(battery | grep level | grep -o '[0-9]*')%"
    echo "🎯 $(foreground_app)"
    echo "👣 $(steps 2>/dev/null || echo 'N/A') 步"
    echo "🎵 $(shx 'dumpsys media_session | grep -E "state=|metadata:" | head -2' | tr '\n' ' ')"
}

help() {
    echo "adb-skills 技能库（纯 adb，不依赖 Shizuku）"
    echo ""
    echo "感知: is_nearby foreground_app battery screen_state wifi_info signal_info steps ambient_light bt_devices bt_status"
    echo "控制: lock wake force_stop volume_up/down music_pp/next/prev camera_open reconnect"
    echo "通知: notifications wx_messages notify"
    echo "日历: cal_list cal_add cal_del"
    echo "设置: open_display open_battery open_notify_access"
    echo "一键: check_all"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && help
