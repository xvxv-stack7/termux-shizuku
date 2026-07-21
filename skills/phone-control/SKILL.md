---
name: phone-control
description: 安卓设备控制。使用时机：需要锁屏/唤醒/强杀应用/切歌/调音量/截图/打开相机。| Android device control. Use when: lock screen, wake, force-stop apps, media keys, volume, screenshot, camera needed.
---

# Phone Control

Device control commands via ADB shell. No root required.

## 🤖 AI Setup

Verify ADB is connected before running any command:
```bash
adb connect 127.0.0.1:5555 || echo "ADB not available"
```

If ADB is offline, guide the user to enable USB Debugging or run the bootstrap script.

## Commands

### Lock / Wake
```bash
adb -s 127.0.0.1:5555 shell input keyevent 26   # lock
adb -s 127.0.0.1:5555 shell input keyevent 224  # wake
```

### Force-stop app
```bash
adb -s 127.0.0.1:5555 shell am force-stop <package.name>
```

### Media keys
```bash
adb -s 127.0.0.1:5555 shell input keyevent 85  # play/pause
adb -s 127.0.0.1:5555 shell input keyevent 87  # next track
adb -s 127.0.0.1:5555 shell input keyevent 88  # prev track
```

### Volume
```bash
adb -s 127.0.0.1:5555 shell input keyevent 24  # vol up
adb -s 127.0.0.1:5555 shell input keyevent 25  # vol down
```

### Screenshot
```bash
adb -s 127.0.0.1:5555 shell screencap -p /sdcard/screenshot.png
```

### Open camera
```bash
adb -s 127.0.0.1:5555 shell am start -a android.media.action.STILL_IMAGE_CAMERA
```

### Navigation
```bash
adb -s 127.0.0.1:5555 shell input keyevent 3   # home
adb -s 127.0.0.1:5555 shell input keyevent 4   # back
```

### Reconnect ADB
```bash
adb connect 127.0.0.1:5555
```
