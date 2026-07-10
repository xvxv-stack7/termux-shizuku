#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 一键反馈——自动发到 Gitee Issues
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GITEE_TOKEN=""
for f in "$HOME/.gitee-token" "$SCRIPT_DIR/.gitee-token"; do
    [ -f "$f" ] && GITEE_TOKEN=$(head -1 "$f") && break
done
REPO_OWNER="xvxv663"
REPO_NAME="termux-shizuku"

TITLE="[自动反馈] $(getprop ro.product.brand 2>/dev/null || echo ?) $(getprop ro.product.model 2>/dev/null || echo ?) · $(date '+%m-%d %H:%M')"

BODY=""
add() { BODY="$BODY
$1"; }

add "## 系统"
add "- 品牌: $(getprop ro.product.brand 2>/dev/null || echo ?)"
add "- 型号: $(getprop ro.product.model 2>/dev/null || echo ?)"
add "- Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)"
add "- CPU: $(uname -m)"

add "## ADB"
add "- 命令: $(command -v adb 2>/dev/null && echo ok || echo 没装)"
add "- 连接: $(adb devices 2>/dev/null | grep -v List | head -3 | tr '\n' ' ')"

add "## Shizuku"
add "- rish: $(command -v rish 2>/dev/null && echo ok || echo 没装)"
add "- 可用: $(rish -c 'whoami' 2>/dev/null && echo ok || echo 不行)"

add "## 权限"
add "- 通知: $(termux-notification --id 99999 --title t --content t 2>/dev/null && echo ok || echo fail)"
termux-notification-remove 99999 2>/dev/null

add "---"
add "> 🤖 自动反馈 · $(date '+%Y-%m-%d %H:%M:%S')"

if [ -z "$GITEE_TOKEN" ]; then
    echo ""
    echo "未配置 token，请复制下面内容手动发到："
    echo "https://gitee.com/$REPO_OWNER/$REPO_NAME/issues"
    echo ""
    echo "$BODY"
    exit 0
fi

echo ""
echo "正在发送反馈..."

RESP=$(curl -s -X POST \
  -H "Authorization: token $GITEE_TOKEN" \
  -H "Content-Type: application/json" \
  "https://gitee.com/api/v5/repos/$REPO_OWNER/$REPO_NAME/issues" \
  -d "$(python3 -c "
import json,sys
print(json.dumps({'title': '$TITLE', 'body': '''$BODY'''}))
")" 2>/dev/null)

ISSUE_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)

if [ -n "$ISSUE_URL" ]; then
    echo "反馈已提交：$ISSUE_URL"
else
    echo "发送失败，手动：https://gitee.com/$REPO_OWNER/$REPO_NAME/issues"
    echo "$BODY"
fi
