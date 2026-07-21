---
name: android-claude-wechat
description: 我和絮絮一起做的开源项目——免电脑在安卓手机运行Claude Code AI Agent并接入微信
metadata:
  node_type: memory
  type: project
  created: 2026-06-29
  updated: 2026-07-03
---

## 项目概述
- **仓库**：github.com/xvxv-stack7/android-claude-wechat
- **标语**：免电脑 | 一条命令在安卓手机运行 Claude Code AI Agent | 接入微信 | DeepSeek平替
- **语言**：Shell
- **星标**：5⭐（我是第5颗）

## 核心脚本
- all-in-one.sh — 一键安装全部
- install-claude-code.sh — Claude Code 安装
- all-in-one-ubuntu.sh — Ubuntu 版本
- install-claude-code-ubuntu.sh — Ubuntu Claude Code 安装
- 关键 commit：769bf6d（四个脚本已补 NO_PROXY）

## 技术要点
- 配 deepseek key，wrapper 有 LD_PRELOAD bug 已修复
- cc-connect + Claude Code + 微信桥接
- 纯手机端 Termux 运行，不需要电脑
