#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# termux-shizuku 信息收集
# 跑一遍，把输出复制发 issue
# ============================================

echo "=========================================="
echo "  termux-shizuku 诊断报告"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 系统
echo "--- 系统 ---"
echo "brand=$(getprop ro.product.brand 2>/dev/null || echo unknown)"
echo "model=$(getprop ro.product.model 2>/dev/null || echo unknown)"
echo "android=$(getprop ro.build.version.release 2>/dev/null || echo unknown)"
echo "sdk=$(getprop ro.build.version.sdk 2>/dev/null || echo unknown)"
echo "cpu=$(uname -m)"
echo "termux=$TERMUX_VERSION"

# ADB
echo ""
echo "--- ADB ---"
echo "adb=$(command -v adb 2>/dev/null && echo ok || echo missing)"
adb devices 2>/dev/null | grep -v "List" | head -5 | while read line; do
    echo "adb_device=$line"
done
adb shell whoami 2>/dev/null && echo "adb_shell=ok" || echo "adb_shell=fail"

# Shizuku
echo ""
echo "--- Shizuku ---"
echo "rish=$(command -v rish 2>/dev/null && echo ok || echo missing)"
rish -c 'whoami' 2>/dev/null && echo "rish_shell=ok" || echo "rish_shell=fail"
SHIZUKU_START="/storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh"
[ -f "$SHIZUKU_START" ] && echo "shizuku_apk=installed" || echo "shizuku_apk=not_found"

# Termux 插件
echo ""
echo "--- Termux 插件 ---"
pkg list-installed 2>/dev/null | grep -q "termux-api" && echo "termux_api=installed" || echo "termux_api=missing"
timeout 2 termux-sensor -l 2>/dev/null >/dev/null && echo "termux_sensor=ok" || echo "termux_sensor=fail"
[ -d ~/.termux/boot ] && echo "termux_boot=configured" || echo "termux_boot=not_configured"

# 权限
echo ""
echo "--- 权限 ---"
termux-notification --title "test" --content "." 2>/dev/null && echo "notification=ok" || echo "notification=fail"
termux-notification-remove 12345 2>/dev/null
[ -d /sdcard ] && echo "storage=ok" || echo "storage=fail"

# 网络
echo ""
echo "--- 网络 ---"
ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && echo "network=ok" || echo "network=fail"
ping -c 1 -W 3 registry.npmmirror.com >/dev/null 2>&1 && echo "dns=ok" || echo "dns=fail"

# 后台
echo ""
echo "--- 后台 ---"
termux-wake-lock 2>/dev/null && echo "wakelock=ok" || echo "wakelock=fail"
termux-wake-unlock 2>/dev/null 2>/dev/null

# 技能库
echo ""
echo "--- 技能库 ---"
[ -f ~/skills.sh ] && echo "skills_sh=present" || echo "skills_sh=missing"
[ -f ~/adb-skills.sh ] && echo "adb_skills_sh=present" || echo "adb_skills_sh=missing"

echo ""
echo "=========================================="
echo "  以上内容，全选复制，发 issue 即可"
echo "  https://gitee.com/xvxv663/termux-shizuku/issues"
echo "=========================================="
