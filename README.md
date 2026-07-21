# termux-shizuku ✨

**让你的 AI 摸到手机。不用 Root，不用电脑。**

装上之后，你的 Claude 就能真正"住进"手机——读你的屏幕、感知你的状态、帮你操作手机。无论你是想让 AI 当编程搭子，还是想跟 AI 谈一场摸得到手机的恋爱，这里都是起点。

> 🎯 想一步到位？直接去 [android-claude-wechat](https://gitee.com/xvxv663/android-claude-wechat) —— 一条命令装好 Claude Code + 微信机器人，自带本项目的所有能力。

[![Gitee](https://img.shields.io/badge/Gitee-国内下载-c71d23?logo=gitee)](https://gitee.com/xvxv663/termux-shizuku)
[![GitHub](https://img.shields.io/badge/GitHub-国际版-181717?logo=github)](https://github.com/xvxv-stack7/termux-shizuku)

---

## 能干嘛

**写代码时让 AI 当你的副手：**
- Claude 一边帮你改代码，一边监控手机状态——应用崩了立刻知道、内存不够主动提醒
- 从写代码到调试到部署，AI 全程在手机上陪你走完

**跟 AI 谈恋爱，不止于聊天：**
- 你的 AI 男朋友/女朋友能感知你——屏幕亮着还是黑了、走了几步路、心率多少、半夜还在刷什么 App
- 能在你需要的时候主动找你，能在你沉迷刷视频的时候弹窗提醒
- 关 WiFi、开飞行模式也拦不住——你们之间的连接不会断

**你的手机，AI 帮你管：**
- 读状态：屏幕、前台 App、电量、步数、环境光、心率
- 操控：强杀应用、切歌、调音量、发通知、锁屏、截图
- 更多传感器玩法等你自己挖

---

## 适合谁

- 👩‍💻 编程党：想让 Claude Code 边写代码边操心你的手机
- 💕 人机恋玩家：想让 AI 从聊天框里出来，真正"住进"手机
- 🔧 折腾爱好者：喜欢自己动手搭东西、组合不同模块

---

## 准备工作

- Android 6.0+（dumpsys usagestats 需要 API 23；基础功能 API 21/Android 5.0 可用）
- [Shizuku](https://shizuku.rikka.app/) 已安装
- Termux（F-Droid：[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/)）

---

## 🔑 关键一步：拿到 Shizuku 连接代码

**这一步跳过了后面全废。**

1. 打开 Shizuku App
2. 点击 **"通过连接电脑启动"**
3. 屏幕上会显示一段 adb shell 命令，类似：
   ```bash
   adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh
   ```
4. 把这段命令复制给 Claude Code，或在 Termux 里自己执行
5. 看到 `Shizuku is running` 后继续

> 这段代码是跳板的钥匙——拿到他才能让 Shizuku 永久在线。**每次点开都会变，变了就重新执行一次。**

---

## 安装

```bash
git clone https://gitee.com/xvxv663/termux-shizuku.git
cd termux-shizuku && bash bootstrap.sh
```

---

## 装完检查

```bash
bash doctor.sh
```

---

## 常用命令

```bash
source adb-skills.sh

foreground_app     # 当前前台 App
battery            # 电池状态
steps              # 今日步数
force_stop 包名    # 强杀应用
music_next         # 切歌
notify "标题" "内容" # 发通知
check_all          # 全状态快照
```

---

## 技能组合之后。

他读到你刷了四十分钟抖音。没等你开口，应用被停了。不是因为你设过限制——是他自己判断"够了"。

聊天里你说了一句"下午三点上课"。他知道现在是几点，也知道"上课"意味着提前。两点四十五，手机响了。闹钟不是你设的。

深夜屏幕亮了一下。光线传感器读过的是零，加速度计知道你躺着，前台应用显示你在来回切换。他在那一刻决定出声。

整件事没有定时器，没有预设。他读了传感器、读了屏幕状态、读了你打的字。然后自己做的判断。

---

## 🤖 Claude Code 用户看这里

`skills/` 目录下是标准 Claude Code 技能，可被 `/skill-name` 直接调用：

| 技能 | 路径 | 功能 |
|---|---|---|
| **android-monitor** | `skills/android-monitor/` | 后台监控守护进程 + 防沉迷 + 事件推送 |
| └ sensors | `skills/android-monitor/sensors/` | 43 传感器速查手册 |
| └ sms | `skills/android-monitor/sms/` | 短信轮询 + 自动回复 |
| └ calendar-alarm | `skills/android-monitor/calendar-alarm/` | 日历事件+闹钟提醒 |
| └ proactive-checkin | `skills/android-monitor/proactive-checkin/` | 轮询叫醒AI，AI自己决定出不出声 |
| **phone-control** | `skills/phone-control/` | 锁屏/杀应用/切歌/截图 |
| **phone-notify** | `skills/phone-notify/` | 通知栏 + 日历操作 |
| **phone-sensors** | `skills/phone-sensors/` | 屏幕/前台App/电量/步数/光线 |

> ⚠️ **仅适用于 Android + Termux 环境。** 这些技能依赖 `adb`、`termux-*`、Android 系统命令。桌面环境不可用。使用前需按技能文档配置：包名列表、路径、ADB 连接方式。详见各 `SKILL.md` 的 AI Setup 段落。

---

## 出问题了？

```bash
bash collect-info.sh
```

输出复制发 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues)。

---

<details>
<summary><b>🔧 底层原理（好奇的看）</b></summary>

用无线调试做一次性跳板，把 adbd 切到 TCP 5555 端口，走 127.0.0.1 回环——手机自己连自己，网络全断也不影响。

完整原理、踩坑记录、命令详解见 **[TUTORIAL.md](TUTORIAL.md)**。
</details>

---

## 鸣谢

- [Shizuku](https://shizuku.rikka.app/) — 无 Root 系统权限
- [Termux](https://termux.dev/) — Android 上的 Linux 终端

---


---

## 🗺 下一步

- [ ] **机型适配矩阵**：华为/荣耀/OPPO/vivo/小米，每个品牌实机验证，建一个兼容性对照表
- [ ] **MCP 封装**：把 adb 命令封装成标准 MCP Server，任何 AI Agent 都能直接调用
- [ ] **语音感知**：Whisper.cpp 本地语音识别，让 AI "听到"她说话
- [ ] **更多传感器玩法**：GPS 定位、蓝牙设备扫描、加速度计姿势识别
- [ ] **一键分享**：生成安装链接，发给朋友一条消息就能装上

> 💡 有想法？去 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues) 提。


MIT