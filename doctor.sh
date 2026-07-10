#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# termux-shizuku 环境诊断
# 退出码: 0=全部通过 1=有警告 2=有致命错误
# ============================================

FATAL=0
WARN=0

pass() { echo -e "  [✓] $1"; }
fail() { echo -e "  [✗] $1"; FATAL=$((FATAL + 1)); }
warn() { echo -e "  [!] $1"; WARN=$((WARN + 1)); }
info() { echo -e "       $1"; }

echo ""
echo "=========================================="
echo "  termux-shizuku 环境诊断"
echo "=========================================="

# ====== 系统 ======
echo ""
echo "--- 系统 ---"
BRAND=$(getprop ro.product.brand 2>/dev/null || echo "?")
echo "  品牌: $BRAND"
echo "  型号: $(getprop ro.product.model 2>/dev/null || echo ?)"
echo "  Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)"
echo "  CPU: $(uname -m)"

# ====== ADB ======
echo ""
echo "--- ADB ---"

command -v adb &>/dev/null && pass "adb 命令" || fail "adb 未安装 → pkg install android-tools"

if adb devices 2>/dev/null | grep -q "127.0.0.1:5555.*device"; then
    pass "adb 5555 已连接"
elif adb devices 2>/dev/null | grep -qv "List" | grep -q "device"; then
    warn "adb 已连接但非 5555 端口 → 运行 bash bootstrap.sh"
else
    fail "adb 未连接 → 打开USB调试或无线调试"
fi

adb shell whoami &>/dev/null 2>&1 && pass "adb shell" || fail "adb shell 不可用（手机弹授权框？）"

# ====== Shizuku ======
echo ""
echo "--- Shizuku ---"

if command -v rish &>/dev/null; then
    pass "rish 命令"
    rish -c 'whoami' &>/dev/null 2>&1 && pass "rish 可用" || {
        fail "rish 不可用"
        info "打开 Shizuku app → 点击「启动」"
    }
else
    fail "rish 未安装 → 安装 Shizuku: https://shizuku.rikka.app/"
fi

# ====== Termux 插件 ======
echo ""
echo "--- Termux 插件 ---"

pkg list-installed 2>/dev/null | grep -q "termux-api" && pass "termux-api 包" || {
    fail "termux-api 包未安装 → pkg install termux-api"
}
timeout 2 termux-sensor -l 2>/dev/null | grep -q "Accelerometer" && pass "termux-sensor" || {
    warn "termux-sensor 无输出 → F-Droid 搜 Termux:API 安装 APK"
}

[ -d ~/.termux/boot ] && pass "Termux:Boot 目录" || warn "Termux:Boot 未配置（开机自启需要）"

# ====== 权限 ======
echo ""
echo "--- 权限 ---"

termux-notification --id 99999 --title "test" --content "." 2>/dev/null && {
    pass "通知权限"
    termux-notification-remove 99999 2>/dev/null
} || fail "通知权限 → 设置允许 Termux 通知"

[ -d /sdcard ] && touch /sdcard/.doctor-test 2>/dev/null && {
    pass "存储权限"
    rm -f /sdcard/.doctor-test
} || warn "存储权限 → termux-setup-storage"

# ====== 网络 ======
echo ""
echo "--- 网络 ---"

ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && pass "网络" || fail "网络不通"
ping -c 1 -W 3 registry.npmmirror.com >/dev/null 2>&1 && pass "DNS" || fail "DNS 不通"

# ====== 后台 ======
echo ""
echo "--- 后台 ---"

termux-wake-lock 2>/dev/null && { pass "Wake Lock"; termux-wake-unlock 2>/dev/null; } || fail "Wake Lock"

# ====== 品牌 ======
echo ""
echo "--- 品牌提醒 ---"
case "$(echo "$BRAND" | tr '[:upper:]' '[:lower:]')" in
    xiaomi|redmi)
        info "小米: 需开启 USB调试 + USB调试（安全设置）";;
    vivo)
        info "vivo: 需允许高耗电 + 自启动";;
    oppo|oneplus|realme)
        info "OPPO: adb connect localhost:5555（非127.0.0.1）";;
    huawei|honor)
        info "华为/荣耀: 部分版本 adb tcpip 被禁，弹窗点始终允许";;
    samsung|google|pixel)
        pass "兼容良好" ;;
    *) ;;
esac

# ====== 结果 ======
echo ""
if [ "$FATAL" -gt 0 ]; then
    echo "=========================================="
    echo "  结果: 有 $FATAL 个致命问题（退出码 2）"
    echo "  先修 [✗] 再跑 bootstrap.sh"
    echo "=========================================="
    exit 2
elif [ "$WARN" -gt 0 ]; then
    echo "=========================================="
    echo "  结果: $WARN 个警告（退出码 1）"
    echo "  可以继续，但建议先修 [!]"
    echo "=========================================="
    exit 1
else
    echo "=========================================="
    echo "  结果: 全部通过（退出码 0）"
    echo "=========================================="
    exit 0
fi
