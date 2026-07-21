# termux-shizuku ✨

**让你的 AI 摸到手机。不用 Root，不用电脑。**

装上之后，你的 Claude / ChatGPT / DeepSeek 就能读你的手机状态、操控你的手机——屏幕亮了还是黑了、电量剩多少、走了几步路、当前在哪个 App，AI 全知道。还能帮你杀应用、切歌、弹通知、调音量。

> 🎯 想一步到位？直接去 [android-claude-wechat](https://gitee.com/xvxv663/android-claude-wechat) —— 一条命令装好 Claude Code + 微信机器人，自带本项目的所有能力。本仓库是底层引擎，适合想自己折腾的玩家。

[![Gitee](https://img.shields.io/badge/Gitee-国内下载-c71d23?logo=gitee)](https://gitee.com/xvxv663/termux-shizuku)
[![GitHub](https://img.shields.io/badge/GitHub-国际版-181717?logo=github)](https://github.com/xvxv-stack7/termux-shizuku)

---

## 能干嘛

**AI 感知手机：**
- 屏幕亮灭、前台 App、电量、步数、环境光 —— 你的 AI 全知道
- 心率、通知栏、WiFi 扫描 —— 更多姿势等你挖

**AI 操控手机：**
- 强杀应用、切歌、调音量、发通知
- 锁屏、截图、模拟点击 —— AI 的手指伸到屏幕上

**永久在线：**
- 关 WiFi？开飞行模式？连接不中断
- 手机重启后自动恢复，不用重新连电脑

**搭配微信机器人：**
- 装上 [android-claude-wechat](https://gitee.com/xvxv663/android-claude-wechat)，微信里的 Claude 直接摸到你的手机

---

## 准备工作

- Android 11+
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

> 这段代码是跳板的钥匙——拿到它才能让 Shizuku 永久在线。**每次点开都会变，变了就重新执行一次。**

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

## 出问题了？

```bash
bash collect-info.sh
```

输出复制发 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues)。

---

<details>
<summary><b>🔧 底层原理（好奇的看）</b></summary>

用无线调试做一次性跳板，把 adbd 切到 TCP 5555 端口，走 127.0.0.1 回环——手机自己连自己，网络全断也不影响。Shizuku 通过这个通道获得系统级权限。

**踩坑记录：**

| 方法 | 结果 |
|------|------|
| `setprop service.adb.tcp.port 5555` | SELinux 拦截 |
| 无线调试 → 关 WiFi | adbd 自杀 |
| 无线调试做跳板 → `adb tcpip 5555` → 127.0.0.1 回环 | ✅ 成功 |
| 关 WiFi / 开飞行模式 | 5555 不受影响 |
| Shizuku 被杀 | `rish -c 'setprop service.adb.tcp.port 5555 && stop adbd && start adbd'` 自愈 |

**已知限制：**

| 能力 | 原因 |
|------|------|
| 亮度调节 | vivo SELinux 锁死 |
| 通知内容 | dumpsys 加密 |
| 剪贴板读取 | vivo provider 拒绝 |
| setprop | SELinux 拦截 |

</details>

---

## 鸣谢

- [Shizuku](https://shizuku.rikka.app/) — 无 Root 系统权限
- [Termux](https://termux.dev/) — Android 上的 Linux 终端

---

MIT