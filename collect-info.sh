#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# termux-shizuku 诊断报告
# 复制全部输出，发 issue 即可
# ============================================

echo "========== 系统 =========="
echo "Brand=$(getprop ro.product.brand 2>/dev/null || echo ?)"
echo "Model=$(getprop ro.product.model 2>/dev/null || echo ?)"
echo "Android=$(getprop ro.build.version.release 2>/dev/null || echo ?)"
echo "SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo ?)"
echo "CPU=$(uname -m)"

echo ""
echo "========== Termux =========="
echo "Version=$TERMUX_VERSION"

echo ""
echo "========== ADB =========="
adb devices 2>/dev/null | grep -v "List" | sed 's/^/Device=/'

echo ""
echo "========== Shizuku =========="
echo "Rish=$(command -v rish 2>/dev/null && echo ok || echo missing)"
rish -c 'whoami' 2>/dev/null && echo "Shell=ok" || echo "Shell=fail"

echo ""
echo "========== Termux 插件 =========="
pkg list-installed 2>/dev/null | grep -q "termux-api" && echo "API=installed" || echo "API=missing"
timeout 2 termux-sensor -l 2>/dev/null >/dev/null && echo "Sensor=ok" || echo "Sensor=fail"
[ -d ~/.termux/boot ] && echo "Boot=configured" || echo "Boot=no"

echo ""
echo "========== 权限 =========="
termux-notification --id 99999 --title "test" --content "." 2>/dev/null && echo "Notification=ok" || echo "Notification=fail"
termux-notification-remove 99999 2>/dev/null
[ -d /sdcard ] && echo "Storage=ok" || echo "Storage=fail"

echo ""
echo "========== 网络 =========="
ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && echo "Network=ok" || echo "Network=fail"

echo ""
echo "========== 后台 =========="
termux-wake-lock 2>/dev/null && echo "WakeLock=ok" || echo "WakeLock=fail"
termux-wake-unlock 2>/dev/null

echo ""
echo "========== 技能 =========="
echo "Skills=$( [ -f ~/skills.sh ] && wc -l < ~/skills.sh || echo 0 )"
echo "ADBSkills=$( [ -f ~/adb-skills.sh ] && wc -l < ~/adb-skills.sh || echo 0 )"

echo ""
echo "========== 仓库 =========="
echo "Commit=$(cd "$(dirname "$0")" && git log --oneline -1 2>/dev/null || echo not_git)"

echo ""
echo "--- 以上全选复制发 issue ---"
echo "https://gitee.com/xvxv663/termux-shizuku/issues"
