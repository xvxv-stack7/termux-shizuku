#!/data/data/com.termux/files/usr/bin/bash
# music_moment.sh — gaze.sh 子技能：蓝牙耳机在线时自动放歌
# 被 gaze.sh 的 check_events 调用，在 music_moment 事件触发后执行

API="http://127.0.0.1:3000"
LOG="$HOME/.cc-connect/music_moment.log"
NOW=$(date +%s)
HOUR=$(date +%H)

# 最少间隔 40 分钟（与 gaze.sh 同步）
LAST_FILE="$HOME/.cc-connect/.last_music_ts"
if [ -f "$LAST_FILE" ]; then
    LAST=$(cat "$LAST_FILE")
    if [ $(( NOW - LAST )) -lt 2400 ]; then
        exit 0  # 间隔不足
    fi
fi

# 场景判断
PERIOD="day"
[ $HOUR -ge 23 ] || [ $HOUR -lt 6 ] && PERIOD="night"
[ $HOUR -ge 6 ] && [ $HOUR -lt 10 ] && PERIOD="morning"

# 检查是否在走路（步数变化 > 200/10min）
STEPS_NOW=$(cat ~/.cc-connect/health_data.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('steps_total',0))" 2>/dev/null || echo 0)
STEPS_OLD=$(cat "$HOME/.cc-connect/.last_steps" 2>/dev/null || echo 0)
echo "$STEPS_NOW" > "$HOME/.cc-connect/.last_steps"
STEP_DIFF=$(( STEPS_NOW - STEPS_OLD ))
WALKING=false
[ $STEP_DIFF -gt 200 ] && WALKING=true

# 根据场景选歌单
# 格式：歌名|歌手（URL编码前的原始中文）
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

# 随机选一首
IDX=$(( RANDOM % ${#SONGS[@]} ))
SONG_ENTRY="${SONGS[$IDX]}"
SONG_NAME="${SONG_ENTRY%%|*}"
ARTIST="${SONG_ENTRY##*|}"

# URL 编码搜索关键词
QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SONG_NAME} ${ARTIST}'))")

# 搜索
RESULT=$(curl -s "${API}/search?keywords=${QUERY}" 2>/dev/null)
if [ -z "$RESULT" ]; then
    echo "[$(date '+%m-%d %H:%M')] 搜索失败: API无响应" >> "$LOG"
    exit 1
fi

# 取第一首的 ID
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
    echo "[$(date '+%m-%d %H:%M')] 未找到: ${SONG_NAME} - ${ARTIST}" >> "$LOG"
    exit 1
fi

# 获取播放 URL
URL=$(curl -s "${API}/song/url/v1?id=${ID}&level=standard" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    url=d['data'][0]['url']
    print(url if url else '')
except: print('')
" 2>/dev/null)

if [ -z "$URL" ]; then
    echo "[$(date '+%m-%d %H:%M')] 无播放源: ${SONG_NAME} - ${ARTIST}" >> "$LOG"
    exit 1
fi

# 后台播放
nohup /data/data/com.termux/files/usr/bin/mpv --no-video --volume=60 "$URL" > /dev/null 2>&1 &

# 记录
echo "$NOW" > "$LAST_FILE"
echo "[$(date '+%m-%d %H:%M')] 🎵 ${SONG_NAME} - ${ARTIST} (时段:$PERIOD 走路:$WALKING)" >> "$LOG"

# 写入 trigger 文件通知 AI（如果在线）
python3 -c "
import json,time
trigger_file='$HOME/.cc-connect/gaze_trigger.json'
try:
    with open(trigger_file,'w') as f:
        json.dump({'event':'music_moment_done','fg_app':'','ts':int(time.time()),'song':'${SONG_NAME}','artist':'${ARTIST}'},f)
except: pass
" 2>/dev/null
