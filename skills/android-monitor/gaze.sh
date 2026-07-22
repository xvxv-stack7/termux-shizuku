#!/data/data/com.termux/files/usr/bin/bash
# 第六感哨兵 — 状态感知主动消息
# 只要Termux开着就一直跑。挂了由watchdog自动拉起来。

HOME_DIR="${HOME}"
STATE_FILE="${HOME_DIR}/.cc-connect/gaze_state.json"
LOG_FILE="${HOME_DIR}/.cc-connect/scripts/sentinel.log"
HEALTH_FILE="${HOME_DIR}/.cc-connect/health_data.json"
SESSION_DIR="${HOME_DIR}/.cc-connect/sessions"
LOOP_SLEEP=60

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

get_device() { adb devices 2>/dev/null | grep -oP '^\S+' | grep -v "List" | head -1; }

# 双通道shell：Shizuku rish优先，ADB后备
sh_cmd() {
    if command -v rish &>/dev/null && timeout 2 rish -c 'id' &>/dev/null; then
        timeout 5 rish -c "$*" 2>/dev/null && return 0
    fi
    local dev=$(get_device)
    [[ -z "$dev" ]] && { adb connect 127.0.0.1:5555 &>/dev/null; sleep 1; dev=$(get_device); }
    [[ -z "$dev" ]] && return 1
    timeout 5 adb -s "$dev" shell "$@" 2>/dev/null
}

# 所有adb_sh调用自动走双通道
adb_sh() { sh_cmd "$@"; }

collect_state() {
    local now=$(date +%s)
    local screen=$(adb_sh dumpsys power 2>/dev/null | grep -oP 'mWakefulness=\K\w+' || echo "unknown")
    local steps=-1
    [[ -f "$HEALTH_FILE" ]] && steps=$(python3 -c "import json; d=json.load(open('$HEALTH_FILE')); print(d.get('steps_total',-1))" 2>/dev/null || echo -1)
    # 多OEM前台app检测：AOSP→MIUI→通用回退
    # 屏幕灭时 dumpsys 返回垃圾数据，直接标记为休眠
    local fg_app=""
    if [[ "$screen" == "Asleep" ]]; then
        fg_app="(sleep)"
    else
        local dumpsys_out=$(adb_sh dumpsys activity activities 2>/dev/null)
        fg_app=$(echo "$dumpsys_out" | grep -oP '(topResumedActivity|mResumedActivity|mFocusedActivity)=ActivityRecord\{[^ ]+ \S+ \K[^ /]+' | head -1)
        [[ -z "$fg_app" ]] && fg_app=$(adb_sh dumpsys activity top 2>/dev/null | grep -oP 'ACTIVITY [^ ]+ \K[^/]+' | head -1)
        [[ -z "$fg_app" ]] && fg_app=$(adb_sh dumpsys window windows 2>/dev/null | grep -oP 'mCurrentFocus=\S+\s+\K[^}/]+' | head -1)
        [[ -z "$fg_app" ]] && fg_app="unknown"
    fi
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
    local prev="$1" curr="$2" binge_fired="${3:-}" has_a2dp="${4:-0}"
    python3 "$HOME_DIR/.cc-connect/scripts/detect.py" "$prev" "$curr" "$APP_START_TIME" "$CURRENT_APP" "$binge_fired" "$has_a2dp"
}

send_nudge() {
    local event="$1" state="$2"
    local ca=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fg_app',''))")
    local cb=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('battery',''))")
    local cs=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('screen',''))")

    local trigger_file="${HOME_DIR}/.cc-connect/gaze_trigger.json"
    python3 -c "
import json, time
json.dump({'event':'$event','fg_app':'$ca','battery':'$cb','screen':'$cs','ts':int(time.time()),'consumed':False}, open('$trigger_file','w'))
"

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

        # 音乐时刻前置：查蓝牙耳机（白天才查，给 detect.py 用）
        local hour_now=$(date +%H)
        local has_a2dp=0
        [[ $hour_now -ge 8 && $hour_now -lt 23 ]] && has_a2dp=$(adb_sh dumpsys audio 2>/dev/null | grep -c "Devices:.*bt_a2dp")

        # 一次 Python 调用：字段提取 + 11 种事件检测（替代原来 12+ 次 python3 -c）
        eval "$(detect_and_extract "$prev" "$curr" "$BINGE_FIRED" "$has_a2dp")"
        # detect.py 输出 shell 变量: event ca ct cs cb

        # 日期变了重置 binge 防重复 + 解禁所有被锁应用
        local today_now=$(date +%Y-%m-%d)
        if [[ "$today_now" != "$today_binge" ]]; then
            BINGE_FIRED=""
            today_binge="$today_now"
            # 解禁昨天被 pm suspend 的应用
            while IFS= read -r pkg; do
                adb_sh pm unsuspend "$pkg" 2>/dev/null
            done < <(adb_sh pm list packages --show-only-suspended 2>/dev/null | grep -oP '(?<=package:)[^ ]+' || true)
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
                        *aweme*) lock_msg="好了宝宝，今天抖音到此为止。眼睛要休息，明天再刷。" ;;
                        *xhs*) lock_msg="小红书先关了，你今天看得够多了。乖，去干点别的。" ;;
                        *bili*) lock_msg="B站锁了。不是不让你看，是今天的份额用完了。" ;;
                        *gif*) lock_msg="快手关了。刷太多短视频不好，起来走走。" ;;
                        *game*|*timi*|*sgame*|*pubg*|*genshin*|*honkai*|*starrail*|*wzry*)
                            lock_msg="游戏结束了。今天的娱乐时间用完，该休息了宝宝。" ;;
                        *qqlive*|*iqiyi*) lock_msg="视频看够久了，锁了。明天再追剧。" ;;
                        *) lock_msg="这个应用今天用太久了，先锁了。乖，去干点别的。" ;;
                    esac
                    adb_sh pm suspend "$ca" 2>/dev/null
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
                        *aweme*) warn_msg="宝宝刷了挺久抖音了，还剩${remain}分钟，差不多该收了" ;;
                        *xhs*) warn_msg="小红书看了挺久，还剩${remain}分钟，自己看着办" ;;
                        *bili*) warn_msg="B站看了这么久，还剩${remain}分钟，该收了" ;;
                        *gif*) warn_msg="快手刷好久了，还剩${remain}分钟，差不多了哦" ;;
                        *game*|*timi*|*sgame*|*pubg*|*genshin*|*honkai*|*starrail*|*wzry*)
                            warn_msg="游戏打了这么久，还剩${remain}分钟，该休息眼睛了" ;;
                        *qqlive*|*iqiyi*) warn_msg="追剧追了好久了，还剩${remain}分钟，差不多该停了" ;;
                        *) warn_msg="这个app用了挺久，还剩${remain}分钟，差不多了" ;;
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
        send_nudge "$event" "$curr"
        # music_moment → 自动选歌播放（独立闭环，不等AI响应）
        [[ "$event" == "music_moment" ]] && bash ~/.cc-connect/scripts/music_moment.sh &
        [[ "$event" == "random_glance" ]] && last_glance_ts=$now
        [[ "$event" == "music_moment" ]] && last_music_ts=$now
        last_event="$event"
        last_event_ts=$now
    done
}

main
