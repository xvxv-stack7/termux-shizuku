# termux-shizuku

**AI Agent 免 Root 免电脑，永久控制你的 Android 手机。**

电脑上 AI Agent 控制手机需要各种插件，还不稳定——手机上传统方案要么 root，要么插着电脑开 ADB，没人会随身带根线。这个方案：一台手机、不用 root、不插电脑、不依赖 WiFi，AI Agent 随时随地控制你手机的一切。

无线调试做一次性跳板，adb tcpip 5555 伪装成 USB 模式，127.0.0.1 回环自连。Shizuku 做引擎。

## 原理

关键洞察：**用无线调试的 TCP 连接当一次性跳板，把 adbd 踹到 5555 回环模式，之后网络全断连接也不死。**

```
① 开无线调试 → adbd 获得随机端口（比如 38435）
    ↓ 此时还依赖 WiFi 局域网 IP
② adb connect 127.0.0.1:38435 → adbd 可达
    ↓ 通过这个跳板发一条命令
③ adb tcpip 5555 → adbd 切到固定 5555 TCP 模式
    ↓ 从这一刻起，不再需要无线调试
④ adb connect 127.0.0.1:5555 → 回环自连
    ↓ 127.0.0.1 不走任何网络栈，WiFi/数据全关也不断
⑤ Shizuku 通过 ADB 5555 启动 → rish 永久 shell 权限
    ↓
⑥ AI Agent（Claude/GPT/任何 Termux 里的 Agent）直接控制手机
```

## 为什么之前的方案都失败了

所有 Android 手机的无线调试在关 WiFi 后 adbd 自动自杀——社区讨论了好几年（Shizuku issue #864, #311, #544），方案都是"借 WiFi 做个跳板"，但 WiFi 断了还是死。

**`adb tcpip` 是 Android 为 USB 调试设计的命令**（正常用法：手机插着电脑 USB → `adb tcpip 5555` → 拔线后用 TCP 连）。无线调试虽然在设置里看起来跟 USB 调试是两个开关，但 adbd 本身不区分"你是怎么连上来的"——只要能连上 adbd，执行 `adb tcpip 5555` 就能把它切到固定 TCP 模式。

切完之后连的是 127.0.0.1——手机自己连自己，物理上不出设备。WiFi 断了、蜂窝数据关了、开飞行模式，都不影响。adbd 以为自己还在服务 USB，实际上走的是回环。

## 安装

```bash
# 前提：Shizuku APK 已安装
# https://shizuku.rikka.app/

# 克隆
git clone https://github.com/xvxv-stack7/termux-shizuku.git
cd termux-shizuku

# 安装依赖
pkg install android-tools

# 一键启动
bash bootstrap.sh
```

## 开机自启

```bash
# 需要 Termux:Boot
bash boot/setup-boot.sh
```

## 技能库

```bash
source adb-skills.sh

# 感知
foreground_app     # 当前前台 app
battery            # 电池
screen_state       # 屏幕亮灭
steps              # 步数

# 控制
force_stop com.ss.android.ugc.aweme   # 杀应用
music_next                             # 切歌
notify "提醒" "该喝水了"               # 系统通知

# 日历
cal_add "提醒" 1783650600000 1783654200000

# 一键
check_all          # 全状态快照
```

## 鸣谢

- **[Shizuku](https://shizuku.rikka.app/)** — 让普通应用获得 ADB 级系统权限，无需 root。没有 Shizuku 就没有这条路。
- **[Termux](https://termux.dev/)** — Android 上的 Linux 终端，AI Agent 的栖身之地。

## 适用

- Android 11+
- 非 root
- 所有品牌
- 单手机，零外设

## 踩过的坑

| 方法 | 结果 |
|------|------|
| `setprop service.adb.tcp.port 5555` | SELinux 拦截 |
| 无线调试 → 关 WiFi | adbd 自杀 |
| 无线调试做一次性跳板 → `adb tcpip 5555` → 127.0.0.1 回环 | ✅ 唯一能活的方案 |
| 关 WiFi / 开飞行模式 | 5555 回环不受影响，一切照常 |
| Shizuku 后台被系统杀 | `rish -c 'setprop service.adb.tcp.port 5555 && stop adbd && start adbd'` 自愈 |

## 许可

MIT

## 已验证能力清单（2026-07-09）

### 🔓 感知层
| 能力 | 方法 |
|------|------|
| 屏幕亮灭 | dumpsys power → mWakefulness |
| 前台 app | dumpsys activity → topResumedActivity |
| 加速度（是否在手里） | termux-sensor Accelerometer |
| 环境光（暗处=被窝） | termux-sensor Ambient Light |
| 步数 | termux-sensor pedometer |
| 电池/温度 | dumpsys battery |
| 手机信号 | dumpsys telephony.registry |
| WiFi SSID | dumpsys wifi → mWifiInfo |
| 蓝牙设备列表 | dumpsys bluetooth_manager → 所有配对设备+连接状态 |
| 手表在线检测 | 查 Amazfit GTS 3 的 BLE 连接 |
| 应用使用时间线 | dumpsys usagestats |
| 使用记录 | 每个 app 的 `used=+XdXh` 时间戳 |

### 🎮 控制层
| 能力 | 方法 |
|------|------|
| 锁屏 | adb shell input keyevent 26（不杀 Shizuku） |
| 唤醒 | adb shell input keyevent 224 |
| 强杀 app | am force-stop 包名 |
| 音乐播放/暂停/切歌 | input keyevent 85/87/88 |
| 音量控制 | input keyevent 24/25 |
| 开关蓝牙 | svc bluetooth enable/disable |
| 发系统通知 | termux-notification --priority max --vibrate |
| 日历增删改查 | content query/insert/update/delete calendar |
| 打开相机 | am start IMAGE_CAPTURE |
| 打开任意设置页 | am start -a android.settings.* |

### 📁 数据层
| 能力 | 方法 |
|------|------|
| 联系人列表 | content query contacts/data/phones |
| 下载文件列表 | ls /sdcard/Download |
| 最近照片 | ls /sdcard/DCIM/Camera |
| 内存/存储 | dumpsys meminfo + df |
| 运行时间 | cat /proc/uptime |
| 通讯录含钉钉号 | ☑️ 大量钉钉 DING 消息联系人 |

### ❌ 受限
| 能力 | 原因 |
|------|------|
| 亮度调节 | vivo_lcm_brightness_service SELinux 锁死 |
| 通知文字内容 | dumpsys 加密，需通知监听器 |
| 剪贴板读取 | vivo 剪贴板 provider 权限拒绝 |
| 无声静默拍照 | 需要 HAL3 API，shell 只能唤起相机 app |
| setprop | SELinux 拦截 |
