---
name: phone-sensors
description: 读取手机传感器和系统状态——屏幕、前台App、电量、步数、光线等。需要 adb 已连接 127.0.0.1:5555。
---

# 📱 手机感知技能

> 让 Claude 看到你的手机状态——屏幕亮没亮、在哪个App、剩多少电。

## 前置条件

```bash
adb connect 127.0.0.1:5555 2>/dev/null
```

## 命令清单

### 前台应用
```bash
adb -s 127.0.0.1:5555 shell dumpsys activity activities | grep topResumedActivity | head -1
```

### 屏幕状态
```bash
adb -s 127.0.0.1:5555 shell dumpsys power | grep mWakefulness
```
返回 `Awake` = 亮屏，`Asleep` = 息屏。

### 电池
```bash
adb -s 127.0.0.1:5555 shell dumpsys battery | grep -E "level|temperature"
```

### 步数（termux-api）
```bash
timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'
```

### 环境光
```bash
timeout 3 termux-sensor -s "Ambient Light" -n 1 2>/dev/null
```

### 内存
```bash
adb -s 127.0.0.1:5555 shell dumpsys meminfo | grep "Total RAM"
```

### WiFi
```bash
adb -s 127.0.0.1:5555 shell dumpsys wifi | grep "mWifiInfo SSID"
```

### 信号
```bash
adb -s 127.0.0.1:5555 shell dumpsys telephony.registry | grep "mOperatorAlphaLong\|primary=CellSignalStrength" | head -3
```

### 是否在充电
```bash
adb -s 127.0.0.1:5555 shell dumpsys battery | grep "USB powered\|AC powered\|Wireless powered"
```

### 一次性快照
```bash
echo "=== 屏幕 ===" && adb -s 127.0.0.1:5555 shell dumpsys power | grep mWakefulness
echo "=== 前台 ===" && adb -s 127.0.0.1:5555 shell dumpsys activity activities | grep topResumedActivity | head -1
echo "=== 电池 ===" && adb -s 127.0.0.1:5555 shell dumpsys battery | grep -E "level|temperature"
echo "=== 步数 ===" && timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'
echo "=== 内存 ===" && adb -s 127.0.0.1:5555 shell dumpsys meminfo | grep "Total RAM"
```
