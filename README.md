# termux-shizuku

**让 AI 免 Root、免电脑、永久控制 Android 手机。**

[![Gitee](https://img.shields.io/badge/Gitee-国内下载-c71d23?logo=gitee)](https://gitee.com/xvxv663/termux-shizuku)
[![GitHub](https://img.shields.io/badge/GitHub-国际版-181717?logo=github)](https://github.com/xvxv-stack7/termux-shizuku)

---

## 装完能干嘛

- AI 读取手机状态（屏幕亮灭、前台 App、电量、步数、环境光）
- AI 操作手机（杀应用、切歌、发通知、调音量）
- 关 WiFi、开飞行模式，连接不中断
- 搭配 [android-claude-wechat](https://gitee.com/xvxv663/android-claude-wechat) 后，微信里的 Claude 就能摸到你的手机

---

## 怎么做到的

用无线调试做一次性跳板，把 adbd 切到 TCP 5555 端口，走 127.0.0.1 回环——手机自己连自己，网络全断也不影响。Shizuku 通过这个通道获得系统级权限。

---

## 准备工作

- Android 11+
- 已装 [Shizuku](https://shizuku.rikka.app/)
- 已装 Termux（F-Droid：[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/)）

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

## 出问题了？

```bash
bash collect-info.sh
```

输出复制发 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues)。

---

## 日常使用

```bash
source adb-skills.sh

foreground_app     # 当前前台 App
battery            # 电池
steps              # 步数
force_stop 包名    # 强杀应用
music_next         # 切歌
notify "标题" "内容" # 发通知
check_all          # 全状态快照
```

---

## 踩过的坑

| 方法 | 结果 |
|------|------|
| `setprop service.adb.tcp.port 5555` | SELinux 拦截 |
| 无线调试 → 关 WiFi | adbd 自杀 |
| 无线调试做跳板 → `adb tcpip 5555` → 127.0.0.1 回环 | ✅ |
| 关 WiFi / 开飞行模式 | 5555 不受影响 |
| Shizuku 被杀 | `rish -c 'setprop service.adb.tcp.port 5555 && stop adbd && start adbd'` 自愈 |

---

## 已知限制

| 能力 | 原因 |
|------|------|
| 亮度调节 | vivo SELinux 锁死 |
| 通知内容 | dumpsys 加密 |
| 剪贴板读取 | vivo provider 拒绝 |
| setprop | SELinux 拦截 |

---

## 鸣谢

- [Shizuku](https://shizuku.rikka.app/) — 无 Root 系统权限
- [Termux](https://termux.dev/) — Android 上的 Linux 终端

---

MIT
