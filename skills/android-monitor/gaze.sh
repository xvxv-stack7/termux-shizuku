#!/data/data/com.termux/files/usr/bin/bash
# Android device monitor daemon — state polling + event detection + anti-addiction
# Runs as background daemon in Termux. Start once, runs until killed.
# Claude Code reads events via Monitor hook on gaze_trigger.json.

HOME_DIR="${HOME}"
STATE_FILE="${HOME_DIR}/.cc-connect/gaze_state.json"
LOG_FILE="${HOME_DIR}/.cc-connect/scripts/sentinel.log"
HEALTH_FILE="${HOME_DIR}/.cc-connect/health_data.json"
SESSION_DIR="${HOME_DIR}/.cc-connect/sessions"
LOOP_SLEEP=60

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

get_device() { adb devices 2>/dev/null | grep -oP '^\S+' | grep -v "List" | head -1; }

adb_sh() {
    local dev=$(get_device)
    [[ -z "$dev" ]] && return 1
    timeout 5 adb -s "$dev" shell "$@" 2>/dev/null
}

collect_state() {
    local now=$(date +%s)
    local screen=$(adb_sh dumpsys power 2>/dev/null | grep -oP 'mWakefulness=\K\w+' || echo "unknown")
    local steps=-1
    [[ -f "$HEALTH_FILE" ]] && steps=$(python3 -c "import json; d=json.load(open('$HEALTH_FILE')); print(d.get('steps_total',-1))" 2>/dev/null || echo -1)
    local fg_app=$(adb_sh dumpsys activity activities 2>/dev/null | grep -oP 'topResumedActivity=ActivityRecord\{[^ ]+ \S+ \K[^ /]+' | head -1 || echo "unknown")
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

detect_event() {
    local prev="$1" curr="$2"
    local ps=$(echo "$prev" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('screen',''))")
    local cs=$(echo "$curr" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('screen',''))")
    local pst=$(echo "$prev" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('steps',-1))")
    local cst=$(echo "$curr" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('steps',-1))")
    local pa=$(echo "$prev" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('fg_app',''))")
    local ca=$(echo "$curr" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('fg_app',''))")
    local pb=$(echo "$prev" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('battery',-1))")
    local cb=$(echo "$curr" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('battery',-1))")
    local pt=$(echo "$prev" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ts',0))")
    local ct=$(echo "$curr" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ts',0))")
    local hour=$(date +%H)

    # Screen off → on (woke up)
    if [[ "$ps" == "Asleep" && "$cs" == "Awake" ]]; then
        local gap=$(( ct - pt ))
        [[ $gap -gt 300 ]] && { echo "woke_up"; return; }
    fi

    # Steps increased by 200+
    if [[ $pst -ge 0 && $cst -gt $pst ]]; then
        [[ $(( cst - pst )) -gt 200 ]] && { echo "started_walking"; return; }
    fi

    # Steps stalled > 45 minutes
    if [[ $pst -ge 0 && $cst -ge 0 ]]; then
        local sd=$(( cst - pst ))
        if [[ $sd -ge 0 && $sd -lt 50 && $(( ct - pt )) -gt 2700 ]]; then
            echo "stopped"; return
        fi
    fi

    # Leaving a game app
    case "$pa" in *timi*|*game*|*koh*|*pvp*|*arena*|*genshin*|*honkai*|*starrail*|*wzry*|*pubg*|*codm*|*Game*|*GAME*)
        [[ "$pa" != "$ca" && "$ca" != "unknown" ]] && { echo "gaming_end"; return; }
    esac

    # Same entertainment app > 30 minutes (binge)
    if [[ -n "$APP_START_TIME" && -n "$CURRENT_APP" ]]; then
        local binge_elapsed=$(( ct - APP_START_TIME ))
        if [[ $binge_elapsed -gt 1800 ]]; then
            case "$ca" in
                *aweme*|*xhs*|*bili*|*kuaishou*|*qqlive*|*iqiyi*|*timi*|*game*|*genshin*|*honkai*|*starrail*|*wzry*|*pubg*)
                    if [[ "$BINGE_FIRED" != "$ca" ]]; then
                        echo "binge_app"; return
                    fi ;;
            esac
        fi
    fi

    # Switched from entertainment to non-chat app
    case "$pa" in *aweme*|*xhs*|*bili*|*kuaishou*|*qqlive*|*iqiyi*|*timi*|*game*|*genshin*|*honkai*|*starrail*|*wzry*|*pubg*)
        if [[ "$ca" != "$pa" && "$ca" != "com.tencent.mm" && "$ca" != "com.termux" && "$ca" != "unknown" ]]; then
            echo "app_switch"; return
        fi
    esac

    # Battery < 15%
    [[ $pb -gt 15 && $cb -le 15 && $cb -gt 0 ]] && { echo "low_battery"; return; }

    # Late night screen on
    [[ "$cs" == "Awake" && ( $hour -ge 23 || $hour -lt 6 ) ]] && { echo "midnight_phone"; return; }

    # 2.5h no activity
    [[ $(( ct - pt )) -gt 9000 && "$cs" == "Asleep" ]] && { echo "long_silence"; return; }

    echo ""
}

send_nudge() {
    local event="$1" state="$2"
    local ca=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fg_app',''))")
    local cb=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('battery',''))")
    local cs=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('screen',''))")

    # Write lightweight trigger — Claude Code Monitor picks it up
    local trigger_file="${HOME_DIR}/.cc-connect/gaze_trigger.json"
    python3 -c "
import json, time
json.dump({'event':'$event','fg_app':'$ca','battery':'$cb','screen':'$cs','ts':int(time.time()),'consumed':False}, open('$trigger_file','w'))
"
    log "trigger: $event fg=$ca"
}

check_fallback() {
    # Unconsumed trigger > 120s → fire termux-notification as fallback
    local trigger_file="${HOME_DIR}/.cc-connect/gaze_trigger.json"
    [[ ! -f "$trigger_file" ]] && return
    local consumed=$(python3 -c "import json; print(json.load(open('$trigger_file')).get('consumed',False))" 2>/dev/null || echo "true")
    [[ "$consumed" == "True" || "$consumed" == "true" ]] && return
    local ts=$(python3 -c "import json; print(json.load(open('$trigger_file')).get('ts',0))" 2>/dev/null || echo 0)
    local now=$(date +%s)
    [[ $(( now - ts )) -lt 120 ]] && return

    local event=$(python3 -c "import json; print(json.load(open('$trigger_file')).get('event',''))" 2>/dev/null)
    # Try custom fallback messages first, fall back to hardcoded defaults
    local fb_msg=$(python3 -c "
import json, random, os
msg_file = '$HOME_DIR/.cc-connect/fallback_messages.json'
if os.path.exists(msg_file):
    msgs = json.load(open(msg_file))
    pool = msgs.get('$event', [])
    if pool:
        print(random.choice(pool))
        exit()
# Built-in defaults
defaults = {
    'woke_up': 'Device woke up.',
    'started_walking': 'Movement detected.',
    'binge_app': 'Screen time alert: extended usage detected.',
    'app_switch': 'App switched.',
    'gaming_end': 'Gaming session ended.',
    'low_battery': 'Battery low — please charge.',
    'midnight_phone': 'Late night screen time detected.',
    'stopped': 'No movement for a while.',
    'long_silence': 'No activity detected for some time.'
}
print(defaults.get('$event', ''))
" 2>/dev/null)

    if [[ -n "$fb_msg" ]]; then
        termux-notification --id "gaze_$(date +%s)" --title "Monitor" --content "$fb_msg" --priority max 2>/dev/null
    fi

    # Mark consumed
    python3 -c "
import json
d = json.load(open('$trigger_file'))
d['consumed'] = True
json.dump(d, open('$trigger_file', 'w'))
" 2>/dev/null
    log "fallback: $event → notification"
}

main() {
    log "===== Android Monitor started ====="
    local dev=$(get_device)
    [[ -z "$dev" ]] && { adb connect 127.0.0.1:5555 &>/dev/null; sleep 2; dev=$(get_device); }
    log "Device: ${dev:-none}"

    local curr=$(collect_state 2>/dev/null || echo "{}")
    echo "$curr" > "$STATE_FILE"
    log "Initial: $curr"

    local last_event="" last_event_ts=0 midnight_fired=""
    APP_START_TIME=""
    CURRENT_APP=""
    BINGE_FIRED=""

    local today_binge=$(date +%Y-%m-%d)
    local limit_last_warn_app="" limit_last_warn_ts=0 limit_last_locked=""

    while true; do
        sleep "$LOOP_SLEEP"
        curr=$(collect_state 2>/dev/null || echo "{}")
        check_fallback
        local prev=$(cat "$STATE_FILE" 2>/dev/null || echo "$curr")

        # App tracking
        local pa=$(echo "$prev" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fg_app',''))")
        local ca=$(echo "$curr" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fg_app',''))")
        local ct=$(echo "$curr" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ts',0))")

        local today_now=$(date +%Y-%m-%d)
        if [[ "$today_now" != "$today_binge" ]]; then
            BINGE_FIRED=""
            today_binge="$today_now"
        fi
        if [[ "$ca" != "$CURRENT_APP" ]]; then
            APP_START_TIME=$ct
            CURRENT_APP="$ca"
        fi

        local event=$(detect_event "$prev" "$curr")
        echo "$curr" > "$STATE_FILE"

        # ── Anti-addiction: cumulative time limit ──
        local limit_result=$(bash "$HOME_DIR/.cc-connect/scripts/app_limit.sh" "$ca" "$ct" 2>/dev/null)
        case "$limit_result" in
            locked)
                if [[ "$limit_last_locked" != "$ca" ]]; then
                    limit_last_locked="$ca"
                    local app_name=$(python3 -c "import json;c=json.load(open('$HOME_DIR/.cc-connect/app_limit_config.json'));print(c.get('$ca',{}).get('name','This app'))" 2>/dev/null || echo "This app")
                    local lock_msg="Daily limit reached for ${app_name}. Take a break."
                    adb_sh am force-stop "$ca" 2>/dev/null
                    adb_sh input keyevent 3 2>/dev/null
                    termux-toast -g middle "$lock_msg" 2>/dev/null
                    log "locked: $ca"
                fi ;;
            warned_*)
                local remain=${limit_result#warned_}
                if [[ "$limit_last_warn_app" != "$ca" || $(( ct - limit_last_warn_ts )) -gt 300 ]]; then
                    limit_last_warn_app="$ca"
                    limit_last_warn_ts=$ct
                    local app_name=$(python3 -c "import json;c=json.load(open('$HOME_DIR/.cc-connect/app_limit_config.json'));print(c.get('$ca',{}).get('name','This app'))" 2>/dev/null || echo "This app")
                    local warn_msg="${app_name}: ${remain} minutes remaining today."
                    termux-toast -g middle "$warn_msg" 2>/dev/null
                    log "warn: $ca ${remain}min left"
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

        if [[ "$event" == "binge_app" ]]; then
            BINGE_FIRED="$ca"
        fi

        log "event: $event"
        send_nudge "$event" "$curr"
        last_event="$event"
        last_event_ts=$now
    done
}

main
