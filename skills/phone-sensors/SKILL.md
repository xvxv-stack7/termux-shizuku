---
name: phone-sensors
description: 安卓设备状态感知。使用时机：需要查前台应用/屏幕状态/电量/步数/环境光/WiFi/信号强度/内存。| Android device state queries. Use when: reading foreground app, screen state, battery, steps, ambient light, WiFi, signal, memory needed.
---

# Phone Sensors & State

Device state queries via ADB dumpsys and termux-sensor.

## 🤖 AI Setup

Verify ADB is connected before running any command:
```bash
adb connect 127.0.0.1:5555 || echo "ADB not available"
```

For step counter and ambient light, termux-api is optional but recommended:
```bash
pkg list-installed | grep termux-api || pkg install termux-api -y
```

## Commands

### Foreground app
```bash
adb -s 127.0.0.1:5555 shell dumpsys activity activities | grep topResumedActivity | head -1
```

### Screen state
```bash
adb -s 127.0.0.1:5555 shell dumpsys power | grep mWakefulness
```
Returns `Awake` (screen on) or `Asleep` (screen off).

### Battery
```bash
adb -s 127.0.0.1:5555 shell dumpsys battery | grep -E "level|temperature"
```

### Charging status
```bash
adb -s 127.0.0.1:5555 shell dumpsys battery | grep "USB powered\|AC powered\|Wireless powered"
```

### Steps (termux-api)
```bash
timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'
```

### Ambient light
```bash
timeout 3 termux-sensor -s "Ambient Light" -n 1 2>/dev/null
```

### Memory
```bash
adb -s 127.0.0.1:5555 shell dumpsys meminfo | grep "Total RAM"
```

### WiFi SSID
```bash
adb -s 127.0.0.1:5555 shell dumpsys wifi | grep "mWifiInfo SSID"
```

### Signal strength
```bash
adb -s 127.0.0.1:5555 shell dumpsys telephony.registry | grep "mOperatorAlphaLong\|primary=CellSignalStrength" | head -3
```

### Full snapshot
```bash
echo "=== Screen ===" && adb -s 127.0.0.1:5555 shell dumpsys power | grep mWakefulness
echo "=== Foreground ===" && adb -s 127.0.0.1:5555 shell dumpsys activity activities | grep topResumedActivity | head -1
echo "=== Battery ===" && adb -s 127.0.0.1:5555 shell dumpsys battery | grep -E "level|temperature"
echo "=== Steps ===" && timeout 3 termux-sensor -s "pedometer" -n 1 2>/dev/null | grep -o '"values": \[[0-9]*' | grep -o '[0-9]*'
echo "=== Memory ===" && adb -s 127.0.0.1:5555 shell dumpsys meminfo | grep "Total RAM"
```
