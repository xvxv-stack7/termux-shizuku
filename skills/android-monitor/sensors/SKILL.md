---
name: android-sensors
description: 43个安卓传感器速查手册——动作/姿态/环境/活动识别/事件检测 | Android sensor catalog: 43 sensors via ADB dumpsys with inference patterns
---

# Android Sensors — Claude Code Skill

Complete reference for accessing Android's 43 onboard sensors via ADB/Termux. Sensors expose raw hardware data that can be combined to infer device state, user activity, and environment — without app-level APIs.

## Quick Commands

```bash
# Full sensor list (43 sensors on vivo S19, varies by device)
adb shell dumpsys sensorservice

# Active sensors only (currently being read by some process)
adb shell dumpsys sensorservice | grep -E "0x[0-9a-f]{8}\)" | head -20

# Specific sensor details
adb shell dumpsys sensorservice | grep -A 5 "Accelerometer"
adb shell dumpsys sensorservice | grep -A 5 "Ambient Light"
adb shell dumpsys sensorservice | grep -A 5 "Proximity"
adb shell dumpsys sensorservice | grep -A 1 "step_counter"
```

## Sensor Catalog

### Motion Sensors

| Sensor | Raw Data | Use Case |
|---|---|---|
| **Accelerometer** | 3-axis (x/y/z) m/s² | Device orientation: z≈9.8 = flat/lying down. Rhythmic spikes = walking. Dense fast spikes = running. Combined with gyro to distinguish gaming vs scrolling. |
| **Gyroscope** | Rotation rate (rad/s) | Screen rotation speed. Rapid spins = gaming. Stable axis + accelerometer = watching video lying down. |
| **Gravity** | Gravity vector (x/y/z) | Cleaner orientation than accelerometer. z-axis downward = lying flat. z-axis sideways = sitting upright. |
| **Linear Acceleration** | Acceleration minus gravity | Pure body movement. Gait frequency can estimate walking vs running. |

### Orientation Sensors

| Sensor | Raw Data | Use Case |
|---|---|---|
| **Rotation Vector** | 3D orientation quaternion | Screen facing up = lying down scrolling. Screen facing down = phone flipped over (possibly ignoring notifications). |
| **Orientation** | Angular deflection | Portrait = messaging. Landscape (90°) = watching video or gaming. |
| **Window Orientation** | System-level rotation | 0=portrait, 90=landscape. Device-specific (vivo), more reliable than raw orientation sensor. |

### Environmental Sensors

| Sensor | Raw Data | Use Case |
|---|---|---|
| **Ambient Light** | Lux | **Key sensor.** lux < 5 = lights off in room. Sudden increase = lights turned on or daybreak. Combine with time to detect late-night screen use in the dark. |
| **Proximity** | Distance (cm) | 0 = against ear (on a call). 5cm+ = nothing close. Combine with accelerometer: lying+prox=N = scrolling; lying+prox=0 = phone call. |
| **Sensor Temperature** | Chip temperature (°C) | >40°C = heavy GPU load (gaming or charging). Can estimate session intensity. |

### Activity Recognition (vivo-specific)

| Sensor | Raw Data | Use Case |
|---|---|---|
| **Step Counter** | Total steps since boot | Daily activity baseline. >15000 = very active. <500 = sedentary. Read from health data file for persistence. |
| **Step Detector** | Trigger per step | Real-time walking detection — fires on each step, not a cumulative counter. |
| **vivo_activity** | Activity class enum | **Most useful sensor.** Outputs: walking/running/cycling/in_vehicle/stationary. Direct activity classification — no manual inference needed. |
| **Elevator Detect** | Boolean trigger | In an elevator → transitioning between floors. Combine with time of day to infer going to class or returning. |
| **Car Navi Detect** | Boolean trigger | In a moving vehicle. Combined with regular accelerometer patterns = traveling. |

### Event Detection

| Sensor | Trigger Pattern | Use Case |
|---|---|---|
| **Raise-up (Wakeup)** | Pick up → screen on | **Key timing signal.** Device picked up and screen turned on — user is about to look at the phone. Optimal moment for notifications. |
| **Put-down** | Device set down | User put the phone down — may have switched to another task. Don't expect immediate response. |
| **Stationary Detect** | No movement timeout | Device has not moved. Long duration = phone left untouched — user may be sleeping, in class, or occupied. |
| **Motion Detect** | Movement starts | Device began moving again after being stationary. User returned to phone. |
| **Significant Motion** | Large movement event | Major repositioning — picked up from table, got out of bed. Not micro-adjustments from scrolling. |

### Specialty Sensors

| Sensor | Raw Data | Use Case |
|---|---|---|
| **Drop Depth** | Free-fall detection | Phone dropped. May auto-trigger screen-off protection. |
| **Motion Sickness** | Motion comfort index | User experiencing motion sickness in vehicle — minimize notification onslaught. |
| **Game Gesture** | Gaming mode trigger | Active gaming session detected. Notifications may be intrusive — defer non-urgent messages. |
| **Angle Judge** | Screen tilt angle | Flat vs upright vs 45°. Combine with light: flat+dark = side-lying phone use. |
| **Raise-up Wakeup** | Pick-up auto-wake | Device setting: pick up to wake screen. Triggers without unlock — user glances at lock screen notifications. |
| **Smart Prox** | Enhanced proximity | Device-specific (vivo). Distinguishes ear/pocket/table vs generic near/far. |

## Composite Inference Patterns

Combine sensors for higher-confidence state detection:

### Is the user actually working/studying?
```
vivo_activity = stationary + screen occasionally on + no gaming gestures + not walking/running
↓
Probably sitting and working, not gaming or commuting.
```

### Late-night screen time
```
time ∈ [00:00, 06:00] + ambient_light < 5 lux + screen = Awake
↓
Dark room + awake = late-night phone use. Fire notification or log for wellness tracking.
```

### On a phone call
```
proximity = 0 + accelerometer = relatively_stable + no gaming gestures
↓
Phone against ear, not moving much = on a call. Avoid interruptions.
```

### Left the phone behind
```
stationary_detect > 30min + step_counter incrementing (from health_data)
↓
Phone hasn't moved but steps are accumulating elsewhere = user walked away without phone.
```

### Gaming session
```
game_gesture = active + gyroscope = rapid_rotation + sensor_temp > 38°C
↓
Active gaming with gyro controls, device heating up. Defer non-urgent notifications.
```

## Technical Limitations

- **Real-time raw values**: Android does not expose sensor buffer reads via command line. `dumpsys sensorservice` shows registration status and metadata, not live data streams.
- **Activity recognition** (`vivo_activity`, `Elevator Detect`, etc.): Vendor-specific. Availability varies by manufacturer (vivo, Xiaomi, Samsung, etc.). Test on target device.
- **Step counter**: Prefer health data aggregators (Gadgetbridge, Google Fit) over raw sensor — they handle dedup and persistence.
- **Phone API extension**: For near-real-time sensor access, implement a Shizuku-based sensor polling endpoint in your phone-api layer.

## Tested Device

vivo S19 (2026-07-13): 43 sensors detected, all responsive via `dumpsys sensorservice`.
Sensor availability and naming varies by manufacturer and Android version. Always verify with `dumpsys sensorservice` on the target device.
