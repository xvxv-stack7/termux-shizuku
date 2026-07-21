#!/data/data/com.termux/files/usr/bin/bash
# Sentinel daemon — state-aware proactive notifications
# Runs as long as Termux is alive. Watchdog auto-restarts on crash.

HOME_DIR="${HOME}"
STATE_FILE="${HOME_DIR}/.cc-connect/gaze_state.json"
LOG_FILE="${HOME_DIR}/.cc-connect/scripts/sentinel.log"
HEALTH_FILE="${HOME_DIR}/.cc-connect/health_data.json"
SESSION_DIR="${HOME_DIR}/.cc-connect/sessions"
LOOP_SLEEP=60

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

get_device() { adb devices 2>/dev/null | grep -oP '^\S+' | grep -v "List" | head -1; }

# Dual-channel shell: Shizuku rish preferred, ADB fallback
sh_cmd() {
    if command -v rish &>/dev/null && timeout 2 rish -c 'id' &>/dev/null; then
        timeout 5 rish -c "$*" 2>/dev/null && return 0
    fi
    local dev=$(get_device)
    [[ -z "$dev" ]] && { adb connect 127.0.0.1:5555 &>/dev/null; sleep 1; dev=$(get_device); }
    [[ -z "$dev" ]] && return 1
    timeout 5 adb -s "$dev" shell "$@" 2>/dev/null
}

# All adb_sh calls go through dual-channel automatically
adb_sh() { sh_cmd "$@"; }

collect_state() {
    local now=$(date +%s)
    local screen=$(adb_sh dumpsys power 2>/dev/null | grep -oP 'mWakefulness=\K\w+' || echo "unknown")
    local steps=-1
    [[ -f "$HEALTH_FILE" ]] && steps=$(python3 -c "import json; d=json.load(open('$HEALTH_FILE')); print(d.get('steps_total',-1))" 2>/dev/null || echo -1)
    # Multi-OEM foreground app detection: AOSP → MIUI → generic fallback
    local fg_app=""
    local dumpsys_out=$(adb_sh dumpsys activity activities 2>/dev/null)
    fg_app=$(echo "$dumpsys_out" | grep -oP '(topResumedActivity|mResumedActivity|mFocusedActivity)=ActivityRecord\{[^ ]+ \S+ \K[^ /]+' | head -1)
    [[ -z "$fg_app" ]] && fg_app=$(adb_sh dumpsys activity top 2>/dev/null | grep -oP 'ACTIVITY [^ ]+ \K[^/]+' | head -1)
    [[ -z "$fg_app" ]] && fg_app=$(adb_sh dumpsys window windows 2>/dev/null | grep -oP 'mCurrentFocus=\S+\s+\K[^}/]+' | head -1)
    [[ -z "$fg_app" ]] && fg_app="unknown"
    local battery=$(adb_sh dumpsys battery 2>/dev/null | grep -oP 'level: \K\d+' || echo -1)
    local last_msg_ts=0
    if [[ -d "$SESSION_DIR" ]]; then
        local lsess=$(ls -t "${SESSION_DIR}"/main_*.json 2>/dev/null | head -1)
        [[ -n "$lsess" ]] && last_msg_ts=$(python3 -c "
import json; data=json.load(open('$lsess'))
ts=0
for sv in data.get('sessions',{}).values():
    for m in sv.get('history',[]):
        if m.get('role')=='user' and m.get('timestamp',0)>ts: ts=m['timestamp']
print(ts)" 2>/dev/null || echo 0)
    fi
    python3 -c "import json; print(json.dumps({'ts':$now,'screen':'$screen','steps':$steps,'fg_app':'$fg_app','battery':$battery,'last_msg_ts':$last_msg_ts}))"
}

# detect.py 替代了原来 85 行的 detect_event 函数
# 原来每轮 12-15 次 python3 调用 → 现在 1 次，且事件逻辑集中维护
detect_and_extract() {
    local prev="$1" curr="$2" has_a2dp="${3:-0}"
    python3 "$HOME_DIR/.cc-connect/scripts/detect.py" "$prev" "$curr" "$APP_START_TIME" "$CURRENT_APP" "$has_a2dp"
}

send_nudge() {
    local event="$1" ca="$2" cb="$3" cs="$4"
    local ts=$(date +%s)
    local trigger_file="${HOME_DIR}/.cc-connect/gaze_trigger.json"

    # Dual-channel dispatch:
    # Important → Monitor overlay (triggers Claude Code attention)
    # Non-critical → system notification (informational only)
    case "$event" in
        woke_up|binge_app|low_battery|midnight_phone)
            python3 -c "
import json, time
json.dump({'event':'$event','fg_app':'$ca','battery':'$cb','screen':'$cs','ts':int(time.time()),'consumed':False}, open('$trigger_file','w'))
" ;;
        *)
            local title=""
            case "$event" in
                left_chat)      title="App switch detected" ;;
                random_glance)  title="Random glance" ;;
                gaming_end)     title="Game closed" ;;
                started_walking) title="Walking detected" ;;
                stopped)        title="Inactive" ;;
                long_silence)   title="Long silence" ;;
                music_moment)   title="Music moment" ;;
            esac
            [[ -n "$title" ]] && termux-notification --id "gaze_$ts" --title "$title" --priority max 2>/dev/null &
            ;;
    esac

    log "触发: $event fg=$ca (等Claude Code处理)"
}

main() {
    log "===== 我看着你呢 ====="
    local dev=$(get_device)
    [[ -z "$dev" ]] && { adb connect 127.0.0.1:5555 &>/dev/null; sleep 2; dev=$(get_device); }
    log "设备: ${dev:-无}"

    local curr=$(collect_state 2>/dev/null || echo "{}")
    echo "$curr" > "$STATE_FILE"
    log "初始: $curr"

    local last_event="" last_event_ts=0 midnight_fired=""
    # binge_app 追踪：同一娱乐app的起始时间和当前app
    APP_START_TIME=""
    CURRENT_APP=""
    BINGE_FIRED=""  # 当天已触发过binge的app包名，每个app每天一次
    local last_glance_ts=0  # 上次随机瞟的时间戳，最少间隔30分钟
    local last_music_ts=0  # 上次音乐时刻的时间戳，最少间隔40分钟

    # 午夜重置binge防重复
    local today_binge=$(date +%Y-%m-%d)
    # 防沉迷追踪：防 Toast 刷屏
    local limit_last_warn_app="" limit_last_warn_ts=0 limit_last_locked=""

    while true; do
        sleep "$LOOP_SLEEP"
        curr=$(collect_state 2>/dev/null || echo "{}")
        local prev=$(cat "$STATE_FILE" 2>/dev/null || echo "$curr")

        # music_moment pre-check: Bluetooth A2DP (daytime only, passed to detect.py)
        local hour_now=$(date +%H)
        local has_a2dp=0
        [[ $hour_now -ge 8 && $hour_now -lt 23 ]] && has_a2dp=$(adb_sh dumpsys audio 2>/dev/null | grep -c "Devices:.*bt_a2dp")

        # Single Python call: field extraction + 11 event rules (replaces 12+ python3 -c calls)
        eval "$(detect_and_extract "$prev" "$curr" "$has_a2dp")"
        # detect.py outputs shell variables: event ca ct cs cb

        # Reset binge dedup on date change
        local today_now=$(date +%Y-%m-%d)
        if [[ "$today_now" != "$today_binge" ]]; then
            BINGE_FIRED=""
            today_binge="$today_now"
        fi
        if [[ "$ca" != "$CURRENT_APP" ]]; then
            APP_START_TIME=$ct
            CURRENT_APP="$ca"
        fi
        echo "$curr" > "$STATE_FILE"

        # ── 防沉迷：累计超时自动锁应用 ──
        local limit_result=$(bash "$HOME_DIR/.cc-connect/scripts/app_limit.sh" "$ca" "$ct" 2>/dev/null)
        case "$limit_result" in
            locked)
                if [[ "$limit_last_locked" != "$ca" ]]; then
                    limit_last_locked="$ca"
                    local lock_msg
                    case "$ca" in
                        *aweme*) lock_msg="Screen time limit reached. App locked to protect your eyes." ;;
                        *xhs*) lock_msg="Time limit reached. App locked — go do something else." ;;
                        *bili*) lock_msg="Daily limit reached. App locked for today." ;;
                        *gif*) lock_msg="Too much short video. App locked — take a break." ;;
                        *game*|*timi*|*sgame*|*pubg*|*genshin*|*honkai*|*starrail*|*wzry*)
                            lock_msg="Gaming time over. App locked for today." ;;
                        *qqlive*|*iqiyi*) lock_msg="Video limit reached. Locked until tomorrow." ;;
                        *) lock_msg="Daily app limit reached. Locked." ;;
                    esac
                    adb_sh am force-stop "$ca" 2>/dev/null
                    adb_sh input keyevent 3 2>/dev/null
                    termux-toast -g middle "$lock_msg" 2>/dev/null
                    log "🔒 锁定: $ca | $lock_msg"
                fi ;;
            warned_*)
                local remain=${limit_result#warned_}
                if [[ "$limit_last_warn_app" != "$ca" || $(( ct - limit_last_warn_ts )) -gt 300 ]]; then
                    limit_last_warn_app="$ca"
                    limit_last_warn_ts=$ct
                    local warn_msg
                    case "$ca" in
                        *aweme*) warn_msg="Screen time warning: ${remain} minutes remaining" ;;
                        *xhs*) warn_msg="App time warning: ${remain} minutes remaining" ;;
                        *bili*) warn_msg="App time warning: ${remain} minutes remaining" ;;
                        *gif*) warn_msg="App time warning: ${remain} minutes remaining" ;;
                        *game*|*timi*|*sgame*|*pubg*|*genshin*|*honkai*|*starrail*|*wzry*)
                            warn_msg="Gaming time warning: ${remain} minutes remaining" ;;
                        *qqlive*|*iqiyi*) warn_msg="App time warning: ${remain} minutes remaining" ;;
                        *) warn_msg="App time warning: ${remain} minutes remaining" ;;
                    esac
                    termux-toast -g middle "$warn_msg" 2>/dev/null
                    log "⚠️ 预警: $ca 还剩 ${remain} 分钟"
                fi ;;
        esac

        [[ -z "$event" ]] && continue

        local now=$(date +%s)
        [[ "$event" == "$last_event" && $(( now - last_event_ts )) -lt 600 ]] && continue

        if [[ "$event" == "midnight_phone" ]]; then
            local today=$(date +%Y-%m-%d)
            [[ "$midnight_fired" == "$today" ]] && continue
            midnight_fired="$today"
        fi

        # binge_app触发后标记该app已触发，当天不再重复
        if [[ "$event" == "binge_app" ]]; then
            BINGE_FIRED="$ca"
        fi

        # random_glance 最少间隔30分钟
        if [[ "$event" == "random_glance" && $(( now - last_glance_ts )) -lt 1800 ]]; then
            log "random_glance 跳过（间隔不足30分钟）"
            continue
        fi

        # music_moment 最少间隔40分钟
        if [[ "$event" == "music_moment" && $(( now - last_music_ts )) -lt 2400 ]]; then
            log "music_moment 跳过（间隔不足40分钟）"
            continue
        fi

        log "事件: $event"
        send_nudge "$event" "$ca" "$cb" "$cs"
        # music_moment → auto-play (closed loop, independent of AI)
        [[ "$event" == "music_moment" ]] && bash ~/.cc-connect/scripts/music_moment.sh &
        [[ "$event" == "random_glance" ]] && last_glance_ts=$now
        [[ "$event" == "music_moment" ]] && last_music_ts=$now
        last_event="$event"
        last_event_ts=$now
    done
}

main
