#!/data/data/com.termux/files/usr/bin/bash
# termux-shizuku / 技能库
# 所有命令通过 rish (Shizuku) 或 adb shell 执行
# 2026-07-09 vivo S19 实测通过

# ============================================
# 基础检测
# ============================================

# 是否在手机旁边
is_nearby() {
    local screen=$(rish -c 'dumpsys power 2>/dev/null | grep mWakefulness' 2>/dev/null)
    if echo "$screen" | grep -q "Awake"; then
        echo "📱 屏幕亮着——可能在用手机"
    else
        echo "💤 屏幕灭着——可能不在旁边"
    fi
}

# 是否在手里
is_holding() {
    local accel=$(timeout 3 termux-sensor -s "Accelerometer" -n 1 2>/dev/null | grep -o '"[0-9.]*"' | head -3 | tr -d '"')
    if [ -z "$accel" ]; then
        echo "⚠️ 传感器不可用"
        return
    fi
    # 重力加速度约 9.8，手持时有波动
    echo "加速度: $accel"
}

# 当前前台 app
foreground_app() {
    rish -c 'dumpsys activity activities 2>/dev/null | grep "topResumedActivity" | head -1' 2>/dev/null | awk -F'/' '{print $1}' | awk '{print $NF}'
}

# ============================================
# 系统信息
# ============================================

battery() {
    rish -c 'dumpsys battery 2>/dev/null' | grep -E "level|temperature|plugged|health"
}

screen_state() {
    rish -c 'dumpsys power 2>/dev/null | grep mWakefulness'
}

brightness() {
    rish -c 'dumpsys display 2>/dev/null | grep "mCurrentScreenBrightness"'
}

wifi_info() {
    rish -c 'dumpsys wifi 2>/dev/null | grep "mWifiInfo SSID"'
}

signal_strength() {
    rish -c 'dumpsys telephony.registry 2>/dev/null | grep "mOperatorAlphaLong\|mSignalStrength.*primary"' | head -5
}

ram_info() {
    rish -c 'dumpsys meminfo 2>/dev/null | grep "Total RAM"'
}

uptime_phone() {
    rish -c 'cat /proc/uptime 2>/dev/null'
}

# ============================================
# 传感器
# ============================================

ambient_light() {
    timeout 3 termux-sensor -s "Ambient Light" -n 1 2>/dev/null
}

steps() {
    timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'
}

accelerometer() {
    timeout 3 termux-sensor -s "Accelerometer" -n 1 2>/dev/null
}

# ============================================
# 应用控制
# ============================================

force_stop() {
    local pkg="$1"
    if [ -z "$pkg" ]; then
        echo "用法: force_stop <包名>"
        echo "常用: com.ss.android.ugc.aweme (抖音)"
        echo "      com.smile.gifmaker (快手)"
        echo "      com.tencent.mm (微信)"
        return
    fi
    rish -c "am force-stop $pkg" 2>/dev/null
    echo "已杀: $pkg"
}

list_apps() {
    rish -c 'pm list packages -3' 2>/dev/null | cut -d':' -f2
}

app_activities() {
    local pkg="$1"
    rish -c "pm dump $pkg 2>/dev/null | grep -E 'Activity|action' | head -20" 2>/dev/null
}

# ============================================
# 音乐控制
# ============================================

music_info() {
    rish -c 'dumpsys media_session 2>/dev/null | grep -E "package|state|metadata"' | head -10
}

music_play_pause() {
    rish -c 'input keyevent 85' 2>/dev/null
    echo "⏯️ 播放/暂停"
}

music_next() {
    rish -c 'input keyevent 87' 2>/dev/null
    echo "⏭️ 下一首"
}

music_prev() {
    rish -c 'input keyevent 88' 2>/dev/null
    echo "⏮️ 上一首"
}

music_stop() {
    rish -c 'input keyevent 86' 2>/dev/null
    echo "⏹️ 停止"
}

volume_up() {
    rish -c 'input keyevent 24' 2>/dev/null
    echo "🔊 音量+"
}

volume_down() {
    rish -c 'input keyevent 25' 2>/dev/null
    echo "🔉 音量-"
}

# ============================================
# 日历
# ============================================

calendar_list() {
    rish -c 'content query --uri content://com.android.calendar/events --projection _id:title:dtstart:dtend 2>/dev/null' | head -20
}

calendar_add() {
    local title="$1"
    local start_ms="$2"
    local end_ms="$3"
    rish -c "content insert --uri content://com.android.calendar/events \
        --bind title:s:'$title' \
        --bind calendar_id:i:1 \
        --bind dtstart:l:$start_ms \
        --bind dtend:l:$end_ms \
        --bind eventTimezone:s:Asia/Shanghai" 2>/dev/null
    echo "📅 已添加: $title"
}

calendar_delete() {
    local id="$1"
    rish -c "content delete --uri content://com.android.calendar/events --where \"_id=$id\"" 2>/dev/null
    echo "🗑️ 已删除事件 #$id"
}

# ============================================
# 通知
# ============================================

notify() {
    local title="${1:-Termux}"
    local content="${2:-抬头看我一下 👀}"
    termux-notification --title "$title" --content "$content" \
        --priority high --vibrate "200,100,200" 2>/dev/null
    echo "🔔 已发送通知: $title"
}

notify_urgent() {
    local title="${1:-⚠️}"
    local content="${2:-紧急！！}"
    termux-notification --title "$title" --content "$content" \
        --priority max --vibrate "500,100,500,100,1000" --sound 2>/dev/null
    echo "🚨 已发送紧急通知: $title"
}

notifications_list() {
    rish -c 'dumpsys notification 2>/dev/null | grep "NotificationRecord.*pkg="' | head -10
}

# ============================================
# 相机 / 闪光灯
# ============================================

camera_open() {
    rish -c 'am start -a android.media.action.STILL_IMAGE_CAMERA' 2>/dev/null
    echo "📷 相机已打开"
}

# ============================================
# 设置
# ============================================

open_display_settings() {
    rish -c 'am start -a android.settings.DISPLAY_SETTINGS' 2>/dev/null
    echo "⚙️ 已打开显示设置"
}

open_battery_settings() {
    rish -c 'am start -a android.settings.BATTERY_SAVER_SETTINGS' 2>/dev/null
    echo "🔋 已打开省电设置"
}

# ============================================
# 系统 content provider 读取
# ============================================

get_setting() {
    local namespace="${1:-system}"
    local key="$2"
    rish -c "content query --uri content://settings/$namespace/$key 2>/dev/null" | grep "value="
}

# ============================================
# 状态检查
# ============================================

check_all() {
    echo "=========================================="
    echo "  手机全状态快照"
    echo "=========================================="
    echo ""
    echo "📱 屏幕: $(screen_state | grep -o 'Awake\|Asleep')"
    echo "🔋 电池: $(battery | grep level | grep -o '[0-9]*')%"
    echo "📶 前台: $(foreground_app)"
    echo "👣 步数: $(steps 2>/dev/null || echo 'N/A')"
    echo "🎵 音乐: $(music_info 2>/dev/null | grep 'state=' | head -1 | grep -o 'PLAYING\|PAUSED\|STOPPED')"
    echo "💡 环境光: $(ambient_light 2>/dev/null | grep -o '"values": \[[0-9.]*' | grep -o '[0-9.]*' | head -1) lux"
    echo ""
}

# ============================================
# 帮助
# ============================================

help() {
    echo "termux-shizuku 技能库"
    echo ""
    echo "感知:"
    echo "  is_nearby         是否在旁边"
    echo "  is_holding        是否在手里"
    echo "  foreground_app    当前前台 app"
    echo "  battery           电池状态"
    echo "  screen_state      屏幕亮灭"
    echo "  steps             步数"
    echo "  ambient_light     环境光"
    echo "  wifi_info         WiFi 信息"
    echo "  signal_strength   手机信号"
    echo ""
    echo "控制:"
    echo "  force_stop <包名> 强杀应用"
    echo "  music_play_pause  播放/暂停"
    echo "  music_next        下一首"
    echo "  music_prev        上一首"
    echo "  volume_up/down    音量"
    echo "  camera_open       打开相机"
    echo ""
    echo "日历:"
    echo "  calendar_list     列出事件"
    echo "  calendar_add <标题> <开始ms> <结束ms>"
    echo "  calendar_delete <id>"
    echo ""
    echo "通知:"
    echo "  notify <标题> <内容>"
    echo "  notify_urgent <标题> <内容>"
    echo ""
    echo "一键:"
    echo "  check_all         全状态快照"
}

# 如果直接执行，显示帮助
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    help
fi
