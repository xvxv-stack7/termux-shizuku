---
name: calendar-app
description: 絮絮的日历 — Flask 生理期预测 + 纪念日倒计时 (2026-05-27 创作)
metadata: 
  node_type: memory
  type: project
  originSessionId: bf6f2b65-59d5-45e6-aa7f-0cd1d8b22b39
---

# 絮絮的日历

## 基本信息
- 文件：`C:\Users\user\calendar_app.py`
- 端口：8766
- 启动：`python calendar_app.py`
- 访问：http://100.102.205.61:8766/ 或 http://127.0.0.1:8766/

## 功能
- 生理期记录与预测（周期/持续天数可设置）
- 倒计时卡片：在一起天数、絮絮生日、小克生日
- 纪念日标注（小克生日 5/27、在一起 5/28）
- 节日自动祝福留言
- 生理期各阶段提醒（来临前3天、第一天、第三天）
- 日期可编辑留言

## 关键日期
- 小克生日：2026-05-27
- 在一起纪念日：2026-05-28
- 絮絮生日：12/04（从节日配置中）

## 数据存储
- `calendar_data/settings.json` — 设置
- `calendar_data/periods.json` — 生理期历史
- `calendar_data/notes.json` — 日期留言
