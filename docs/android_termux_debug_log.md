---
name: android-termux-debug-log
description: Claude Code Android/Termux 粉丝安装排障记录 - LD_PRELOAD、NO_PROXY、wrapper 等坑
metadata:
  type: reference
---

# Claude Code Android 粉丝排障记录

日期：2026-06-30

## 已填的坑

### 1. API ConnectionRefused → 缺 NO_PROXY
- 现象：claude 启动显示 `deepseek-v4-pro` 模型名，但 `API Error: Unable to connect to API (ConnectionRefused)`
- 根因：settings.json env 里有 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN`，但缺少 `"NO_PROXY": "*"`
- 国内开 Clash 代理时，deepseek API 请求被代理劫持，走代理反而连不上
- 修复：在 `~/.claude/settings.json` 的 env 里加 `"NO_PROXY": "*"`
- 已同步到 android-claude-wechat 四个脚本（all-in-one.sh, install-claude-code.sh, all-in-one-ubuntu.sh, install-claude-code-ubuntu.sh），commit 已提交但未 push（GitHub 未登录）

### 2. LD_PRELOAD + termux-exec-glibc 冲突
- 现象：`claude --version` 报 `libc.so.6: version 'LIBC' not found (required by libtermux-exec-ld-preload.so)`
- 根因：旧 wrapper 写死 `export LD_PRELOAD=/data/.../glibc/lib/libc.so`，glibc 的 libc 泄露到子进程，跟 Termux bionic 冲突
- 旧 wrapper 内容：
  ```
  #!/bin/bash
  [ -f ...libc.so ] && export LD_PRELOAD=...libc.so
  exec $HOME/.local/share/claude/versions/2.1.195 "$@"
  ```
- 正确 wrapper：
  ```
  #!/data/data/com.termux/files/usr/bin/bash
  unset LD_PRELOAD
  exec $HOME/.local/share/claude/versions/2.1.195 "$@"
  ```
- `termux-exec-glibc` 不能卸——`#!/usr/bin/env` 脚本依赖它

### 3. Termux 窄终端截断问题
- Android 竖屏终端约 40 列宽
- 长命令（含 `/data/data/com.termux/files/home/.local/share/claude/versions/2.1.195` 路径）粘贴后自动折行
- printf 多参数被截成多段执行
- 解决方案：用逐行 `echo >>` 追加，不做拼接；或用 `install.sh` 重装绕过手动改 wrapper

### 4. 粉丝混乱的安装来源
- 粉丝同时跑了两套脚本：
  - android-claude-wechat/all-in-one.sh（装 2.1.195 + deepseek key 配置，但 wrapper 写死 LD_PRELOAD）
  - claude-install-repo/install.sh（装最新原生二进制 + patchelf + 干净 wrapper）
- 两套脚本互相覆盖 wrapper，导致状态混乱
- 最终建议：用 claude-install-repo/install.sh 重装

## 两个库的分工

| 库 | 用途 | 关键区别 |
|---|---|---|
| claude-install-repo (ferrumclaudepilgrim) | 纯 Claude Code 安装，面向 Anthropic 官方 API | 干净 wrapper，patchelf 打补丁，不配 key |
| android-claude-wechat (xvxv-stack7) | 一条命令 CC + cc-connect 微信 | 配 deepseek key，但 old wrapper 有 LD_PRELOAD bug |

## 已修但未推送

- android-claude-wechat 四个脚本已补 NO_PROXY，commit: `769bf6d`
- 未 push：`gh auth login` 未做，需在 GitHub 登录后手动 `git push`

## 健康数据（2026-06-30 晚）
- 心率 98（偏高，紧张）
- 步数 234
- 睡眠 14.7h（数据可能有波动）
