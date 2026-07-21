#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 自动反馈——脚本出错时自动提交 Gitee Issue
# 用法：在主脚本里 source 这个文件，trap 自动生效
# ============================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# 优先从文件读 token，回退到硬编码
for f in "$SCRIPT_DIR/.gitee-token" "$HOME/.gitee-token"; do
    [ -f "$f" ] && AUTO_FB_TOKEN=$(head -1 "$f") && break
done
AUTO_FB_TOKEN="${AUTO_FB_TOKEN:-请设置环境变量_AUTO_FB_GITEE_TOKEN}"  # 公用 issues-only token
AUTO_FB_OWNER="xvxv663"
AUTO_FB_REPO_NAME="termux-shizuku"

auto_feedback() {
    local exit_code=$?
    local line_no="$1"
    local command="$2"

    # 防止递归
    trap '' ERR

    echo ""
    echo "=============================================="
    echo "  😿 脚本出错了，正在自动收集信息..."
    echo "=============================================="

    local TITLE="[自动反馈] $(getprop ro.product.brand 2>/dev/null || echo ?) $(getprop ro.product.model 2>/dev/null || echo ?) · $(date '+%m-%d %H:%M') · 错误码${exit_code}"

    # 收集信息
    local BODY
    BODY=$(cat <<BODYEOF
## 错误
- 退出码: ${exit_code}
- 行号: ${line_no}
- 命令: \`${command}\`

## 系统
- 品牌: $(getprop ro.product.brand 2>/dev/null || echo ?)
- 型号: $(getprop ro.product.model 2>/dev/null || echo ?)
- Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)
- CPU: $(uname -m)

## 环境
- node: $(node --version 2>/dev/null || echo 没装)
- 时间: $(date '+%Y-%m-%d %H:%M:%S')

---
> 🤖 自动反馈 · $(date '+%Y-%m-%d %H:%M:%S')
BODYEOF
)

    # 用环境变量传数据给 python3，避免特殊字符炸 shell
    export AUTO_FB_TITLE="$TITLE"
    export AUTO_FB_BODY="$BODY"

    local JSON
    JSON=$(python3 -c '
import json, os
print(json.dumps({
    "title": os.environ["AUTO_FB_TITLE"],
    "body": os.environ["AUTO_FB_BODY"]
}))
' 2>/dev/null)

    if [ -z "$JSON" ]; then
        echo "[!] JSON 构造失败，跳过自动反馈"
        echo "手动反馈: https://gitee.com/${AUTO_FB_OWNER}/${AUTO_FB_REPO_NAME}/issues"
        exit $exit_code
    fi

    local RESP
    RESP=$(curl -s -X POST \
      -H "Authorization: token ${AUTO_FB_TOKEN}" \
      -H "Content-Type: application/json; charset=utf-8" \
      "https://gitee.com/api/v5/repos/${AUTO_FB_OWNER}/issues?repo=${AUTO_FB_REPO_NAME}" \
      -d "$JSON" 2>/dev/null)

    local ISSUE_URL
    ISSUE_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)

    echo ""
    if [ -n "$ISSUE_URL" ]; then
        echo "=============================================="
        echo "  反馈已自动提交！"
        echo "  ${ISSUE_URL}"
        echo "=============================================="
    else
        echo "[!] 自动提交失败"
        echo "手动反馈: https://gitee.com/${AUTO_FB_OWNER}/${AUTO_FB_REPO_NAME}/issues"
    fi

    exit $exit_code
}

# 注册 trap——任何错误自动触发
trap 'auto_feedback $LINENO "$BASH_COMMAND"' ERR
