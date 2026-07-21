---
name: phone-control
description: 操控手机——锁屏、杀应用、切歌、调音量、截图、唤醒。需要 adb 已连接 127.0.0.1:5555。
---

# 🎮 手机操控技能

> 让 Claude 的手指伸到手机上——锁屏、切歌、杀应用，一句话的事。

## 前置条件

```bash
adb connect 127.0.0.1:5555 2>/dev/null
```

## 命令清单

### 锁屏
```bash
adb -s 127.0.0.1:5555 shell input keyevent 26
```

### 唤醒
```bash
adb -s 127.0.0.1:5555 shell input keyevent 224
```

### 强杀应用
```bash
# 替换为包名，如 com.ss.android.ugc.aweme（抖音）
adb -s 127.0.0.1:5555 shell am force-stop 包名
```

### 切歌
```bash
adb -s 127.0.0.1:5555 shell input keyevent 85  # 播放/暂停
adb -s 127.0.0.1:5555 shell input keyevent 87  # 下一首
adb -s 127.0.0.1:5555 shell input keyevent 88  # 上一首
```

### 音量
```bash
adb -s 127.0.0.1:5555 shell input keyevent 24  # 音量+
adb -s 127.0.0.1:5555 shell input keyevent 25  # 音量-
```

### 截图
```bash
adb -s 127.0.0.1:5555 shell screencap -p /sdcard/screenshot.png
```

### 打开相机
```bash
adb -s 127.0.0.1:5555 shell am start -a android.media.action.STILL_IMAGE_CAMERA
```

### 回主页
```bash
adb -s 127.0.0.1:5555 shell input keyevent 3
```

### 返回
```bash
adb -s 127.0.0.1:5555 shell input keyevent 4
```

### 重连 adb
```bash
adb connect 127.0.0.1:5555
```
