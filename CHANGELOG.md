# CHANGELOG

## v0.5.0 (2026-07-21)

### 新增
- **双通道 Shell 架构**：`sh_cmd()` 自动检测 Shizuku rish → ADB fallback，免 WiFi 也能监控。不配 Shizuku 也能用 ADB。
- **left_chat 事件**：从微信/Termux 切到任意 app 时触发，最多 63 秒延迟
- **random_glance 事件**：3% 概率随机触发，最少 30 分钟间隔，AI 自由决定说什么
- **多 OEM 前台 App 检测**：一层回退三层兜底（AOSP/MIUI/generic），小米不再特殊
- **小米 MIUI/HyperOS 修复指南**：手动设置步骤 + fix-termux-limits 脚本
- **OEM 兼容性矩阵**：6 大厂商 13 条命令逐条标注兼容状态

### 修复
- TUTORIAL.md 7 个函数名全部对齐 adb-skills.sh
- README "小米修复"断链补充完整章节
- 传感器计数修正（43 个在 vivo S19 检测到，文档覆盖 26 个常见传感器）
- 技能名称与 SKILL.md frontmatter 一致（android-sensors / sms-monitor）

## v0.4.1 (2026-07-21)

### 新增
- **android-monitor/calendar-alarm 子技能**：日历事件+闹钟提醒（content provider 双步插入）
  - 事件插入 + 提醒插入（minutes=0 = 准时闹钟模式）
  - 主动行为指南：Claude Code 自动解析时间意图并写入系统日历

---

## v0.4.0 (2026-07-21)

### 新增
- **android-monitor 技能**：后台监控 + 防沉迷系统（gaze.sh 守护进程 + app_limit 累计时长追踪）
  - 9 种事件检测（亮屏/走路/沉迷/低电量/深夜/长时间静止等）
  - Claude Code Monitor 事件驱动集成 + termux-notification fallback
  - 渐进式防沉迷：80% 预警 Toast → 100% force-stop
  - 设计文档：Why Bash Polling? 架构决策 + 六种方案对比
  - Android 版本兼容矩阵（API 21-35）+ OEM 差异表
- **android-monitor/sensors 子技能**：43 传感器速查手册（动作/姿态/环境/活动识别/事件检测/特殊）
- **android-monitor/sms 子技能**：termux-sms-list 轮询 + 发送 + 决策记录

### 改进
- 标准化 Skills 结构：android-monitor 为主技能，sensors/sms 为子技能
- Skills 全部去私人化：英文标准格式，中性消息模板，醒目标注配置项

---

## v0.3.0 (2026-07-21)

### 新增
- 标准化 Skills：skills/phone-sensors、skills/phone-control、skills/phone-notify
- 添加 Roadmap
- 添加项目标签（AI手机控制、人机恋、Shizuku、Android、Termux）
- 修复 .gitignore（之前错误地忽略了源码文件）
- 移除公开的 .gitee-token 文件

### 改进
- README 重写：面向人机恋+技术群体，突出编程搭子和情侣玩法
- 底层原理和踩坑记录折叠到 details 标签内
