#!/data/data/com.termux/files/usr/bin/bash
# Cumulative app usage limiter — tracks daily time per app and force-stops on limit.
# Called by gaze.sh each loop tick. Not meant to run standalone.
# Returns: ok | warned_N | locked | config_only

CONFIG="$HOME/.cc-connect/app_limit_config.json"
TRACKER="$HOME/.cc-connect/app_usage_tracker.json"
FG="$1"
NOW="${2:-$(date +%s)}"
TODAY=$(date +%Y-%m-%d)

# Not in config → skip
LIMIT=$(python3 -c "import json;c=json.load(open('$CONFIG'));print(c.get('$FG',{}).get('limit_minutes',0))" 2>/dev/null || echo 0)
[[ "$LIMIT" = "0" ]] && { echo "config_only"; exit 0; }

# Init tracker if needed
if [ ! -f "$TRACKER" ]; then
    echo '{}' > "$TRACKER"
fi

TD=$(python3 -c "import json;d=json.load(open('$TRACKER'));print(d.get('date',''))" 2>/dev/null || echo "")

# Date changed → reset
if [ "$TD" != "$TODAY" ]; then
    python3 -c "
import json
d = {'date': '$TODAY'}
json.dump(d, open('$TRACKER', 'w'))
" 2>/dev/null
fi

# Get cumulative seconds + last check timestamp
INFO=$(python3 -c "
import json, sys
d = json.load(open('$TRACKER'))
app = d.get('$FG', {})
secs = app.get('total_seconds', 0)
last = app.get('last_check', 0)
print(f'{secs} {last}')
" 2>/dev/null)
TOTAL_SECS=$(echo "$INFO" | awk '{print $1}')
LAST_CHECK=$(echo "$INFO" | awk '{print $2}')

LIMIT_SECS=$(( LIMIT * 60 ))

# Accumulate: if last check was within 120s, add the gap
if [ "$LAST_CHECK" -gt 0 ]; then
    GAP=$(( NOW - LAST_CHECK ))
    if [ "$GAP" -gt 0 ] && [ "$GAP" -lt 120 ]; then
        TOTAL_SECS=$(( TOTAL_SECS + GAP ))
    fi
fi

# Write updated tracker
python3 -c "
import json
d = json.load(open('$TRACKER'))
d['date'] = '$TODAY'
d['$FG'] = {'total_seconds': $TOTAL_SECS, 'last_check': $NOW}
json.dump(d, open('$TRACKER', 'w'), ensure_ascii=False)
" 2>/dev/null

# Determine state
if [ "$TOTAL_SECS" -ge "$LIMIT_SECS" ]; then
    echo "locked"
elif [ "$TOTAL_SECS" -ge $(( LIMIT_SECS * 80 / 100 )) ]; then
    REMAIN=$(( (LIMIT_SECS - TOTAL_SECS) / 60 ))
    echo "warned_${REMAIN}"
else
    echo "ok"
fi
