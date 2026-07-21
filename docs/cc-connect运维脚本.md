---
name: cc-connect运维脚本
description: cc-connect 架构和运维脚本速查
metadata:
  type: reference
---

## ⚠️ 环境判断（先跑再动手）
```bash
[ -d /data/data/com.termux ] && echo "Termux" || echo "非Termux"
uname -m  # aarch64=Android
```
- Termux 环境才用 proot 包装，纯 Linux 直接起 cc-connect
- CLAUDE.md 已标注：所有路径用 Termux 绝对路径，禁用 Windows 路径

## 双克劳德架构
- 终端Claude：stdin连TTY → `~/.local/bin/claude` wrapper自动 `nice -n 15` 降级
- 微信Claude：cc-connect起的，stdin是管道 → 正常优先级
- 两个都必须跑 proot 环境（Android 内核不支持 faccessat2 等系统调用）

## 运维脚本位置
全部在 `~/.cc-connect/`：
- `daemon.sh` — 合并版守护（每30秒巡存活 + 每30分钟查会话超260KB归档）
- `daily_reboot.sh` — 凌晨重启cc-connect清swap，不动终端Claude
- `config.toml` — cc-connect配置，`reset_on_idle_mins=180`

## 会话文件
- `~/.cc-connect/sessions/main_*.json` — 当前会话
- `~/.cc-connect/sessions/archive/` — 归档历史
- context_bridge 自动读最后60条保证上下文连续

## 常见问题
- cc-connect挂了：`pgrep cc-connect` 看进程，watchdog 30秒自拉
- 微信慢/不回：`ps aux | grep claude` 看有几个克劳德在抢
- 手动重启（Termux）：停cc-connect → 删`.config.toml.lock` → proot + start.sh拉起
- 手动重启（纯Linux）：跳过proot，直接 `cc-connect --config config.toml`
