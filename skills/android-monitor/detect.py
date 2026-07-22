#!/usr/bin/env python3
"""gaze.sh event detection — merged replacement for detect_event + main-loop field extraction.
Single Python invocation instead of 12-15 per cycle."""

import sys, json, random
from datetime import datetime

def main():
    if len(sys.argv) < 3:
        print('event=""\nca=""\nct=0\ncs=""\ncb=-1')
        return

    prev = json.loads(sys.argv[1])
    curr = json.loads(sys.argv[2])
    app_start_time = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 0
    current_app = sys.argv[4] if len(sys.argv) > 4 else ""
    binge_fired = sys.argv[5] if len(sys.argv) > 5 else ""
    has_a2dp = int(sys.argv[6]) if len(sys.argv) > 6 else 0

    # Extract all fields (previously 8 separate python3 -c calls in detect_event)
    ps = prev.get('screen', '')
    cs = curr.get('screen', '')
    pst = prev.get('steps', -1)
    cst = curr.get('steps', -1)
    pa = prev.get('fg_app', '')
    ca = curr.get('fg_app', '')
    pb = prev.get('battery', -1)
    cb = curr.get('battery', -1)
    pt = prev.get('ts', 0)
    ct = curr.get('ts', 0)

    hour = datetime.now().hour
    event = ""

    # 1. woke_up — screen off→on, gap > 5min
    if ps == "Asleep" and cs == "Awake" and ct - pt > 300:
        event = "woke_up"

    # 2. started_walking — steps +200
    if not event and pst >= 0 and cst > pst and cst - pst > 200:
        event = "started_walking"

    # 3. stopped — steps stalled 45min (delta < 50, elapsed > 2700s)
    if not event and pst >= 0 and cst >= 0:
        sd = cst - pst
        if 0 <= sd < 50 and ct - pt > 2700:
            event = "stopped"

    # 4. gaming_end — switched away from game
    if not event:
        game_kw = ['timi', 'game', 'koh', 'pvp', 'arena', 'genshin', 'honkai',
                   'starrail', 'wzry', 'pubg', 'codm', 'Game', 'GAME']
        if any(kw in pa for kw in game_kw) and pa != ca and ca != "unknown":
            event = "gaming_end"

    # 5. binge_app — same entertainment app > 30min (once per app per day)
    if not event and app_start_time > 0 and current_app and binge_fired != ca:
        binge_elapsed = ct - app_start_time
        if binge_elapsed > 1800:
            ent_kw = ['aweme', 'xhs', 'bili', 'kuaishou', 'qqlive', 'iqiyi',
                      'timi', 'game', 'genshin', 'honkai', 'starrail', 'wzry', 'pubg']
            if any(kw in ca for kw in ent_kw):
                event = "binge_app"

    # 6. left_chat — left chat apps
    if not event:
        if pa in ("com.termux", "com.tencent.mm") and ca not in ("com.termux", "com.tencent.mm"):
            event = "left_chat"

    # 7. low_battery — battery < 15%
    if not event and pb > 15 and 0 < cb <= 15:
        event = "low_battery"

    # 8. midnight_phone — late night + screen on
    if not event and cs == "Awake" and (hour >= 23 or hour < 6):
        event = "midnight_phone"

    # 9. long_silence — 2.5h no activity
    if not event and ct - pt > 9000 and cs == "Asleep":
        event = "long_silence"

    # 10. random_glance — 3% probability, only when awake
    if not event and cs == "Awake" and random.random() < 0.03:
        event = "random_glance"

    # 11. music_moment — A2DP headphones + daytime + not in media app + 2% probability
    if not event and cs == "Awake" and 8 <= hour < 23 and has_a2dp > 0:
        ent_kw = ['aweme', 'kuaishou', 'bili', 'qqlive', 'iqiyi', 'youtube',
                  'tiktok', 'cloudmusic', 'qqmusic', 'kugou', 'spotify']
        if not any(kw in ca for kw in ent_kw) and random.random() < 0.02:
            event = "music_moment"

    # Output shell eval format — single call yields all variables
    print(f'event="{event}"')
    print(f'ca="{ca}"')
    print(f'ct="{ct}"')
    print(f'cs="{cs}"')
    print(f'cb="{cb}"')

if __name__ == "__main__":
    main()
