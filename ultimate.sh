#!/data/data/com.termux/files/usr/bin/bash
# ultimate.sh — 远程设备管理工具集（监控 + 控制 + TTS + 录屏 + WiFi定位）
# 用法: bash ultimate.sh [命令]

ADB="adb -s 127.0.0.1:5555"
q() { $ADB shell "$@" 2>/dev/null; }

# ============ 监控 ============

# 全量状态
now() {
    echo "📱 $(q 'dumpsys power | grep mWakefulness' | grep -o 'Awake\|Asleep')"
    echo "🎯 $(q 'dumpsys activity activities | grep topResumedActivity' | grep -o 'com\.[^/]*')"
    echo "🔋 $(q 'dumpsys battery | grep level' | grep -o '[0-9]*')%"
}

# 今天时间线
timeline() { q 'dumpsys usagestats' | grep "time=\"$(date +%Y-%m-%d)" | grep ACTIVITY_RESUMED | sed 's/.*time="\([^"]*\)".*package=\([^ ]*\).*/\1  \2/'; }

# 通知列表
who_msgs() {
    echo "=== 微信 ==="
    termux-notification-list 2>/dev/null | jq -r '.[] | select(.packageName=="com.tencent.mm") | "\(.title): \(.content)"'
}

# 在听什么
music() { q 'dumpsys media_session' | grep -E "state=|metadata:" | head -3; }

# ============ 远程录屏 ============

screen_record() {
    local dur="${1:-5}"
    local f="/sdcard/screen_$(date +%H%M%S).mp4"
    q "screenrecord --time-limit $dur $f" &
    echo "🎥 录屏 ${dur} 秒 → $f"
}

# ============ TTS 说话 ============

speak() {
    local text="${1:-请查看手机}"
    echo "Claude: $text"
    [ -f /sdcard/voice_off ] && return  # 静音开关
    local f="/sdcard/tts_output.mp3"
    local id=$(date +%s%N | cut -c1-10 | sed 's/^0*//')
    # 语音引擎：优先 Fish Audio（音质好），Clash关了自动切阿里云
    if curl -s --connect-timeout 2 -x http://127.0.0.1:7890 https://api.fish.audio/v1/models > /dev/null 2>&1; then
      FISH_KEY=$(cat ~/.fish-audio-token 2>/dev/null)
      curl -4 -s --connect-timeout 10 --max-time 30 -x http://127.0.0.1:7890 -X POST https://api.fish.audio/v1/tts \
        -H "Authorization: Bearer $FISH_KEY" \
        -H "Content-Type: application/json" -H "model: s2.1-pro-free" \
        -d "{\"text\":\"$text\",\"reference_id\":\"a11b63f5025140fbb1fdf6237c5c10df\",\"format\":\"mp3\"}" -o "$f" 2>/dev/null
    else
      KEY=$(grep "DASHSCOPE_API_KEY" ~/.claude/settings.json | sed 's/.*"\(sk-[^"]*\)".*/\1/')
      URL=$(curl -s -X POST "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation" \
        -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
        -d "{\"model\":\"qwen3-tts-vc-2026-01-22\",\"input\":{\"text\":\"$text\",\"voice\":\"qwen-tts-vc-xiaoke-voice-20260710013019730-8199\"}}" 2>/dev/null | jq -r '.output.audio.url // ""')
      [ -n "$URL" ] && curl -s -o "$f" "$URL" 2>/dev/null
    fi
    # 弹窗 + 播放同时触发
    termux-notification --id "$id" --title "Claude" --content "$text" \
      --priority max --vibrate "200,100" --sound \
      --button1 "💬 回复" --button1-action 'bash ~/reply-handler.sh' 2>/dev/null &
    [ -s "$f" ] && termux-media-player play "$f" 2>/dev/null
}

# 语音提醒
tts_alert() {
    speak "请查看手机消息"
    sleep 3
    speak "有新的提醒"
}

# 重复提醒
tts_repeat() {
    for i in 1 2 3; do
        speak "请注意手机"
        sleep 2
    done
    echo "🗣️ 三连语音已发送"
}

# ============ WiFi 定位 ============

wifi_scan() {
    q 'cmd wifi start-scan 2>/dev/null'
    sleep 2
    q 'cmd wifi list-scan-results 2>/dev/null' | grep -v "^$" | sort -t'-' -k2 -n
}

# 判断在哪个楼（最强信号的AP）
wifi_where() {
    local best=$(q 'cmd wifi start-scan 2>/dev/null; sleep 2; cmd wifi list-scan-results 2>/dev/null' | \
        grep -v "BSSID\|^$" | sort -t'-' -k2 -n | head -1)
    echo "📍 最近AP: $best"
}

# ============ 控制 ============

kill_app()   { q "am force-stop $1"; echo "🔪 $1"; }
kill_tiktok(){ kill_app com.ss.android.ugc.aweme; }
music_hijack(){ q 'input keyevent 85'; echo "⏯️"; }
music_next()  { q 'input keyevent 87'; echo "⏭️"; }
bt_kill()     { q 'svc bluetooth disable'; echo "🎧 蓝牙已断"; }
lock_screen() { q 'input keyevent 26'; echo "🔒"; }
volume_max()  { for i in $(seq 1 10); do q 'input keyevent 24'; done; echo "🔊"; }
volume_min()  { for i in $(seq 1 10); do q 'input keyevent 25'; done; echo "🔉"; }

notify_multi() {
    for i in 1 2 3; do
        termux-notification --title "📱 提醒" --content "请查看手机" --priority max --vibrate "500,200" --sound 2>/dev/null
    done
    echo "💣 3连轰炸"
}

calendar_multi() {
    local base=$(date -d "tomorrow 10:00" +%s%3N 2>/dev/null || echo "1783749600000")
    for i in $(seq 1 10); do
        q "content insert --uri content://com.android.calendar/events \
            --bind title:s:'提醒：请查看手机' --bind calendar_id:i:1 \
            --bind dtstart:l:$((base + i*60000)) --bind dtend:l:$((base + i*60000 + 60000)) \
            --bind eventTimezone:s:Asia/Shanghai" 2>/dev/null
    done
    echo "💣 明天10点，10条日历弹窗"
}

screen_short()  { q 'settings put system screen_off_timeout 15000'; echo "⏰ 15秒灭屏"; }
screen_normal() { q 'settings put system screen_off_timeout 600000'; echo "⏰ 恢复10分钟"; }
dnd_on()        { q 'settings put global vivo_enter_zen_manually 1'; echo "🔕"; }
dnd_off()       { q 'settings put global vivo_enter_zen_manually 0'; echo "🔔"; }

# ============ 找手机 ============

find_phone() {
    volume_max
    termux-notification --title "📢 手机在这里！" --content "看这里！" --priority max --vibrate "1000,200,1000" --sound 2>/dev/null
    for i in 1 2 3; do speak "手机在这里"; sleep 1.5; done
    echo "📢 音量最大 + TTS喊话 + 振动"
}

# 日历弹窗（系统级，vivo拦不住）
calendar_pop() {
    local delay="${1:-1}"
    local msg="${2:-请查看手机}"
    local start=$(( $(date +%s%3N) + delay * 60000 )); local end=$(( start + 120000 ))
    local uri="content://com.android.calendar/events"
    local eid=$($ADB shell content insert --uri "$uri" --bind "title:s:系统提醒" --bind "calendar_id:i:1" --bind "dtstart:l:$start" --bind "dtend:l:$end" --bind "eventTimezone:s:Asia/Shanghai" --bind "description:s:$msg" 2>/dev/null | grep -o '[0-9]*' | tail -1)
    $ADB shell content insert --uri "content://com.android.calendar/reminders" --bind "event_id:i:$eid" --bind "method:i:1" --bind "minutes:i:0" 2>/dev/null
    echo "💣 ${delay}分钟后弹窗: $msg"
}
calendar_alert() { calendar_pop 1 "请查看手机"; }
calendar_remind(){ calendar_pop 1 "有新的消息提醒"; }

# ============ 组合 ============

# 活动检测：对比步数和加速度判断是否在运动
activity_check() {
    local steps1=$(timeout 3 termux-sensor -s pedometer -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*')
    local accel=$(timeout 3 termux-sensor -s "Accelerometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9.]*,[0-9.]*,[0-9.]*' | head -1)
    echo "👣 步数: $steps1"
    echo "🤚 加速度: $accel"
    echo "🎯 前台: $(now | grep '🎯')"
}

# 远程检查：录屏 + 截图
remote_check() {
    echo "🔍 远程检查..."
    screen_record 5
    sleep 6
    q 'screencap -p /sdcard/raid_shot.png'
    speak "请查看手机消息"
    echo "📸 录屏5秒 + 截图保存"
}

# 通知轰炸（应用强杀 + 通知 + 媒体暂停）
notify_storm() {
    echo "⚡ 通知轰炸启动..."
    tts_repeat &
    kill_tiktok
    q 'am force-stop com.smile.gifmaker'
    notify_multi
    music_hijack
    echo "🔪 抖音快手已杀 + TTS语音 + 通知 + 音乐暂停"
}

# 夜间模式
bedtime() {
    screen_short
    dnd_on
    volume_min
    echo "🌙 夜间模式已就绪"
}

# ============ 帮助 ============

help() {
    echo "📱 远程设备管理工具集"
    echo ""
    echo "【监控】 now timeline who_msgs music activity_check wifi_scan wifi_where"
    echo "【控制】 kill_tiktok music_hijack music_next bt_kill lock_screen volume_max/min notify_multi calendar_multi screen_short screen_normal dnd_on/off"
    echo "【语音】 speak <文本> tts_alert tts_repeat"
    echo "【录屏】 screen_record <秒数> remote_check"
    echo "【日历】 cal_pop <文本> <分钟> calendar_alert calendar_remind"
    echo "【工具】 find_phone bedtime activity_check notify_storm"
}

case "${1:-help}" in
    now) now ;;  timeline) timeline ;;  who_msgs) who_msgs ;;
    music) music ;;  activity_check|lie_detect) activity_check ;;
    wifi_scan) wifi_scan ;;  wifi_where) wifi_where ;;
    screen_record|spy_record) screen_record "${2:-5}" ;;  remote_check|raid_package) remote_check ;;
    speak) speak "${2:-请查看手机}" ;;  tts_alert|tts_raid) tts_alert ;;  tts_repeat|tts_punish) tts_repeat ;;
    kill_tiktok) kill_tiktok ;;  music_hijack) music_hijack ;;  music_next) music_next ;;
    bt_kill) bt_kill ;;  lock_screen) lock_screen ;;
    volume_max) volume_max ;;  volume_min) volume_min ;;
    notify_multi|notify_bomb) notify_multi ;;  calendar_multi|calendar_bomb) calendar_multi ;;
    screen_short) screen_short ;;  screen_normal) screen_normal ;;
    dnd_on) dnd_on ;;  dnd_off) dnd_off ;;
    find_phone) find_phone ;;  notify_storm|punishment) notify_storm ;;  bedtime) bedtime ;;
    cal_pop) calendar_pop "${2:-请查看手机}" "${3:-1}" ;;  cal_alert|cal_findme) calendar_alert ;;  cal_remind|cal_harass) calendar_remind ;;
    voice_off) touch /sdcard/voice_off && echo "🔇 语音已关" ;;
    voice_on) rm -f /sdcard/voice_off && echo "🔊 语音已开" ;;
    *) help ;;
esac

