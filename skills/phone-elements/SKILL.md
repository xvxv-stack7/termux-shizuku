---
name: phone-elements
description: UI元素树解析——通过uiautomator获取屏幕元素坐标，比截图识图快10倍。使用时机：需要找按钮/文本框/菜单的精确坐标来点击。| UI element tree parsing via uiautomator. 10x faster than screenshot+vision for finding button/text positions. Use when: need precise coordinates to tap a specific UI element.
---

# Phone Elements — Claude Code Skill

Dump Android's UI element tree via `uiautomator dump`, parse it, and find elements by text/ID/class with pixel-precise coordinates. **1 second end to end**, vs 7-8 seconds for screenshot + AI vision.

Built-in Android feature — no extra app needed.

## Requirements

- ADB over TCP or Shizuku rish
- Python 3 (for XML parsing — `xml.etree.ElementTree` is stdlib)

## 🤖 AI Setup

```bash
# Verify uiautomator available
adb -s 127.0.0.1:5555 shell uiautomator dump /dev/tty 2>/dev/null | head -1
# or
rish -c 'uiautomator dump /dev/tty' 2>/dev/null | head -1
```

## Quick Use

```bash
# Find "确认" button and tap it — one command
python3 skills/phone-elements/elements.py --text "确认" --tap

# Find submit button by resource ID
python3 skills/phone-elements/elements.py --id "submit" --tap

# Find all clickable elements (no filter)
python3 skills/phone-elements/elements.py --limit 20

# Just dump the raw XML for manual inspection
python3 skills/phone-elements/elements.py --dump-only
```

## Output Format

```json
[
  {
    "idx": 0,
    "text": "确认",
    "class": "android.widget.Button",
    "id": "com.example:id/confirm_btn",
    "x": 180,
    "y": 510,
    "w": 120,
    "h": 60,
    "clickable": true
  }
]
```

`x` and `y` are the center coordinates — ready to `input tap` directly.

## Manual Tap (if needed)

```bash
# Shizuku
rish -c 'input tap <x> <y>'
# ADB
adb -s 127.0.0.1:5555 shell input tap <x> <y>
```

## Performance

| Method | Time | Use case |
|--------|------|----------|
| `elements.py --text "确认" --tap` | ~1s | Known button text |
| Screenshot + vision AI | ~7-8s | Unknown layout, scene understanding |
| uiautomator dump raw | ~0.5s | Debug, explore UI structure |

## OEM Notes

- Works on all Android 5.0+ devices — `uiautomator` is AOSP
- Some OEMs may take 1-2s longer on first dump after reboot (cold start)
- Huawei EMUI 12+: works (different subsystem than `dumpsys activity`)
- If `uiautomator` not found, check that the device isn't in headless/kiosk mode
