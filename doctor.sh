#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# termux-shizuku 环境诊断
# 跑一遍，告诉你哪里没配好
# ============================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[✓]${NC} $1"; }
fail() { echo -e "  ${RED}[✗]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
info() { echo -e "       $1"; }

echo ""
echo "=========================================="
echo "  termux-shizuku 环境诊断"
echo "=========================================="

# ====== 系统信息 ======
echo ""
echo "=== 系统信息 ==="
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || echo "未知")
BRAND=$(getprop ro.product.brand 2>/dev/null || echo "未知")
MODEL=$(getprop ro.product.model 2>/dev/null || echo "未知")
SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "未知")
CPU=$(uname -m 2>/dev/null || echo "未知")

echo "  品牌: $BRAND"
echo "  型号: $MODEL"
echo "  Android: $ANDROID_VER (SDK $SDK)"
echo "  CPU: $CPU"

# ====== ADB ======
echo ""
echo "=== ADB ==="

ADB_OK=0
if command -v adb &>/dev/null; then
    pass "adb 命令可用"
else
    fail "adb 未安装 → pkg install android-tools"
fi

# 本地回环
if adb devices 2>/dev/null | grep -q "127.0.0.1:5555"; then
    pass "adb 127.0.0.1:5555 已连接"
    ADB_OK=1
elif adb devices 2>/dev/null | grep -qv "List" | grep -q "device"; then
    warn "adb 已连接但不是 5555 端口"
    adb devices 2>/dev/null | grep -v "List"
else
    fail "adb 未连接"
    info "请检查 USB 调试是否开启，或运行 bash bootstrap.sh"
fi

# ADB shell 可用性
if adb shell whoami &>/dev/null 2>&1; then
    pass "adb shell 可用"
else
    fail "adb shell 不可用"
    if [ "$ADB_OK" = "1" ]; then
        info "手机可能弹了授权框，请点允许"
    fi
fi

# ====== Shizuku / rish ======
echo ""
echo "=== Shizuku ==="

if command -v rish &>/dev/null; then
    pass "rish 命令存在"
    if rish -c 'whoami' &>/dev/null 2>&1; then
        pass "rish 可用"
    else
        fail "rish 不可用"
        info "打开 Shizuku app → 点击「启动」→ 等待就绪"
    fi
else
    fail "rish 未安装"
    info "请安装 Shizuku: https://shizuku.rikka.app/"
    info "安装后运行: bash bootstrap.sh"
fi

# ====== Termux 插件 ======
echo ""
echo "=== Termux 插件 ==="

# Termux:API
if pkg list-installed 2>/dev/null | grep -q "termux-api"; then
    pass "termux-api 包已安装"
    if timeout 2 termux-sensor -l 2>/dev/null | grep -q "Accelerometer"; then
        pass "termux-sensor 可用"
    else
        warn "termux-sensor 无输出，检查 Termux:API 是否已安装"
        info "F-Droid 搜「Termux:API」安装"
    fi
else
    fail "termux-api 包未安装"
    info "pkg install termux-api -y"
    info "然后去 F-Droid 搜「Termux:API」安装 APK"
fi

# Termux:Boot
if [ -d ~/.termux/boot ]; then
    pass "Termux:Boot 目录存在"
else
    warn "Termux:Boot 未配置（非必需，开机自启才需要）"
fi

# Termux:Widget
if [ -d ~/.shortcuts ]; then
    pass "Termux:Widget 目录存在"
else
    warn "Termux:Widget 未配置（非必需）"
fi

# ====== 权限 ======
echo ""
echo "=== 权限 ==="

# 通知
if termux-notification --title "测试" --content "诊断通知" 2>/dev/null; then
    pass "通知权限可用"
    termux-notification-remove "termux-doctor" 2>/dev/null
else
    fail "通知权限不可用"
    info "设置 → 应用 → Termux → 通知 → 允许"
fi

# 存储
if [ -d /sdcard ] && touch /sdcard/.doctor-test 2>/dev/null; then
    pass "存储权限可用"
    rm -f /sdcard/.doctor-test
else
    warn "存储权限未授权 → termux-setup-storage 回车"
fi

# ====== 网络 ======
echo ""
echo "=== 网络 ==="

if ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1; then
    pass "网络通"
else
    fail "网络不通"
    info "检查 WiFi/数据 是否开启"
fi

# DNS
if ping -c 1 -W 3 registry.npmmirror.com >/dev/null 2>&1; then
    pass "DNS 通"
else
    fail "DNS 不通"
    info "echo 'nameserver 223.5.5.5' > $PREFIX/etc/apt/resolv.conf"
fi

# ====== 品牌专属提示 ======
echo ""
echo "=== 品牌适配提醒 ==="
case "$(echo "$BRAND" | tr '[:upper:]' '[:lower:]')" in
    xiaomi|redmi)
        warn "小米/HyperOS"
        info "需开启：USB调试 + USB调试（安全设置）"
        info "设置 → 开发者选项 → 两个都开"
        info "后台：设置 → 应用 → Termux → 省电策略 → 无限制"
        ;;
    vivo)
        warn "vivo/OriginOS"
        info "需开启：USB调试 + 高耗电允许 + 自启动"
        info "设置 → 电池 → 高耗电 → Termux → 允许"
        info "设置 → 应用 → 自启动 → Termux → 开启"
        ;;
    oppo|oneplus|realme)
        warn "OPPO/一加/ColorOS"
        info "ADB: 试试 adb connect localhost:5555（不是 127.0.0.1）"
        info "后台：设置 → 电池 → 应用耗电管理 → Termux → 允许后台"
        info "设置 → 应用 → 自启动 → Termux → 开启"
        ;;
    honor|huawei)
        warn "荣耀/华为/MagicOS"
        info "部分版本 adb tcpip 被禁止，如果失败换无线调试方式"
        info "adb 授权弹窗要点「始终允许」"
        info "后台：手机管家 → 启动管理 → Termux → 手动管理（三项全开）"
        info "设置 → 应用 → 特殊访问权限 → 忽略电池优化 → Termux"
        ;;
    samsung)
        pass "三星一般兼容良好"
        info "后台：设置 → 设备维护 → 电池 → 休眠应用 → 移除 Termux"
        ;;
    google|pixel)
        pass "Pixel 最稳定，基本无需额外配置"
        ;;
    *)
        info "未收录的机型的特殊配置，有问题发 issue"
        ;;
esac

# ====== 后台保活 ======
echo ""
echo "=== 后台保活 ==="

if termux-wake-lock 2>/dev/null; then
    termux-wake-unlock 2>/dev/null
    pass "Wake Lock 可用"
else
    fail "Wake Lock 不可用"
fi

# 前台服务
echo "  手动检查："
echo "    Termux 通知栏是否有「常驻通知」"
echo "    没有 → termux-notification --ongoing --title 'Termux' --content '保持运行'"

# ====== 总结 ======
echo ""
echo "=========================================="
echo "  诊断完成！"
echo ""
echo "  有 [✗] 的按提示修复后再跑 bootstrap.sh"
echo ""
echo "  快速修复命令（复制粘贴）："
echo "    pkg install android-tools termux-api -y"
echo "    termux-setup-storage"
echo "    termux-wake-lock"
echo "=========================================="
