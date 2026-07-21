#!/data/data/com.termux/files/usr/bin/bash
# game-raid.sh — 深夜应用使用管理
GAME="com.bmystu.peng.gw"
ADB="adb -s 127.0.0.1:5555"
SKILL="$HOME/.claude/projects/termux-shizuku"
speak() { bash "$SKILL/ultimate.sh" speak "$1"; }

echo "🎬 Action!"
speak "凌晨了。还在打游戏？"
sleep 6
speak "该休息了。倒计时开始。"
sleep 4
speak "时间到。强制停止游戏。"
sleep 6
$ADB shell am force-stop "$GAME" 2>/dev/null
speak "游戏已停止。请休息。"
sleep 8
speak "继续使用将被限制。"
sleep 7
