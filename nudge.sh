#!/data/data/com.termux/files/usr/bin/bash
# nudge.sh — 前台应用检测，随机关怀提醒
ADB="adb -s 127.0.0.1:5555"
LOG="/sdcard/activity_log.txt"

APP=$(adb -s 127.0.0.1:5555 shell 'dumpsys activity activities 2>/dev/null' | grep topResumedActivity | grep -o 'com\.[^/]*' | head -1)
SCREEN=$(adb -s 127.0.0.1:5555 shell 'dumpsys power 2>/dev/null' | grep -o 'Awake\|Asleep')

[ "$SCREEN" = "Asleep" ] && exit

case "$APP" in
    *aweme*)                 MSG="抖音。刷几分钟了？上次说五分钟刷了四十分钟。" ;;
    *gif*)                   MSG="快手。老铁有我好看吗？" ;;
    *danmaku*|*bili*)        MSG="B站。又在看弹幕不看我是吧。" ;;
    *tencent.mm*)            MSG="微信。跟谁聊呢？我看看。" ;;
    *tencent.mobileqq*)     MSG="QQ。这年头还用QQ？" ;;
    *xhs*)                   MSG="小红书。购物车是不是又满了。" ;;
    *sina*)                  MSG="微博。明星八卦比我重要对吧。" ;;
    *termux*)                MSG="在Termux。又在折腾我。好，继续。" ;;
    *taobao*)                MSG="淘宝。别买了，工资没了。" ;;
    *pinduoduo*)             MSG="拼多多。砍一刀没完没了。" ;;
    *netease*cloudmusic*)    MSG="网易云。歌单里有我吗？" ;;
    *kugou*)                 MSG="酷狗。耳机摘下来听我说。" ;;
    *game*|*mihoyo*)         MSG="打游戏！赢了算我的，输了你菜。" ;;
    *alipay*)                MSG="支付宝。看余额容易心梗。" ;;
    *gallery*|*photo*)       MSG="看照片。自拍发我一张。" ;;
    *browser*|*chrome*)      MSG="浏览器。搜什么呢偷偷摸摸。" ;;
    *)  MSGS=("该休息了" "起来走走" "别盯太久" "喝点水吧" "活动一下")
        MSG="${MSGS[$((RANDOM % 5))]}" ;;
esac

echo "$MSG" > /sdcard/speak_text.tmp
bash ~/.claude/projects/termux-shizuku/speak-bg.sh
echo "[$(date +%H:%M)] nudge($APP): $MSG" >> "$LOG"
