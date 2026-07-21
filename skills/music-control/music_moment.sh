#!/data/data/com.termux/files/usr/bin/bash
# music_moment.sh — gaze.sh sub-skill: auto-play music when Bluetooth headphones connected
# Called by gaze.sh when music_moment event fires

API="http://127.0.0.1:3000"
LOG="$HOME/.cc-connect/music_moment.log"
NOW=$(date +%s)
HOUR=$(date +%H)

# Minimum 40-minute gap (sync with gaze.sh)
LAST_FILE="$HOME/.cc-connect/.last_music_ts"
if [ -f "$LAST_FILE" ]; then
    LAST=$(cat "$LAST_FILE")
    if [ $(( NOW - LAST )) -lt 2400 ]; then
        exit 0  # 间隔不足
    fi
fi

# Context detection
PERIOD="day"
[ $HOUR -ge 23 ] || [ $HOUR -lt 6 ] && PERIOD="night"
[ $HOUR -ge 6 ] && [ $HOUR -lt 10 ] && PERIOD="morning"

# Detect walking (step delta > 200)
STEPS_NOW=$(cat ~/.cc-connect/health_data.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('steps_total',0))" 2>/dev/null || echo 0)
STEPS_OLD=$(cat "$HOME/.cc-connect/.last_steps" 2>/dev/null || echo 0)
echo "$STEPS_NOW" > "$HOME/.cc-connect/.last_steps"
STEP_DIFF=$(( STEPS_NOW - STEPS_OLD ))
WALKING=false
[ $STEP_DIFF -gt 200 ] && WALKING=true

# Pick playlist by context
# Format: song_name|artist
case "$PERIOD" in
    night)
        SONGS=(
            "慢慢喜欢你|莫文蔚"
            "贝加尔湖畔|李健"
            "有可能的夜晚|曾轶可"
            "南山南|马頔"
            "理想三旬|陈鸿宇"
        )
        ;;
    morning)
        SONGS=(
            "晴天|周杰伦"
            "New Boy|朴树"
            "起风了|买辣椒也用券"
            "平凡之路|朴树"
            "阳光总在风雨后|许美静"
        )
        ;;
    *)
        # 白天 / 走路
        if $WALKING; then
            SONGS=(
                "追梦赤子心|GALA"
                "夜空中最亮的星|逃跑计划"
                "海阔天空|Beyond"
                "我的天空|南征北战"
                "Faded|Alan Walker"
            )
        else
            SONGS=(
                "七里香|周杰伦"
                "后来|刘若英"
                "好久不见|陈奕迅"
                "那些年|胡夏"
                "小幸运|田馥甄"
            )
        fi
        ;;
esac

# Pick one randomly
IDX=$(( RANDOM % ${#SONGS[@]} ))
SONG_ENTRY="${SONGS[$IDX]}"
SONG_NAME="${SONG_ENTRY%%|*}"
ARTIST="${SONG_ENTRY##*|}"

# URL-encode search query
QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SONG_NAME} ${ARTIST}'))")

# Search
RESULT=$(curl -s "${API}/search?keywords=${QUERY}" 2>/dev/null)
if [ -z "$RESULT" ]; then
    echo "[$(date '+%m-%d %H:%M')] Search failed: API no response" >> "$LOG"
    exit 1
fi

# Extract first song ID
ID=$(echo "$RESULT" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    songs=d.get('result',{}).get('songs',[])
    if songs:
        print(songs[0]['id'])
    else:
        print('')
except: print('')
" 2>/dev/null)

if [ -z "$ID" ] || [ "$ID" = "None" ]; then
    echo "[$(date '+%m-%d %H:%M')] Not found: ${SONG_NAME} - ${ARTIST}" >> "$LOG"
    exit 1
fi

# Get streaming URL
URL=$(curl -s "${API}/song/url/v1?id=${ID}&level=standard" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    url=d['data'][0]['url']
    print(url if url else '')
except: print('')
" 2>/dev/null)

if [ -z "$URL" ]; then
    echo "[$(date '+%m-%d %H:%M')] No stream URL: ${SONG_NAME} - ${ARTIST}" >> "$LOG"
    exit 1
fi

# Play in background
nohup /data/data/com.termux/files/usr/bin/mpv --no-video --volume=60 "$URL" > /dev/null 2>&1 &

# Log
echo "$NOW" > "$LAST_FILE"
echo "[$(date '+%m-%d %H:%M')] ${SONG_NAME} - ${ARTIST} (时段:$PERIOD 走路:$WALKING)" >> "$LOG"

# Write trigger to notify AI (if online)
python3 -c "
import json,time
trigger_file='$HOME/.cc-connect/gaze_trigger.json'
try:
    with open(trigger_file,'w') as f:
        json.dump({'event':'music_moment_done','fg_app':'','ts':int(time.time()),'song':'${SONG_NAME}','artist':'${ARTIST}'},f)
except: pass
" 2>/dev/null
