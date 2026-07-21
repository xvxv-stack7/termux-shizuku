---
name: phone-open
description: 打开链接/文件/应用。使用时机：需要打开网页URL、本地文件、应用商店链接、深度链接。| Open URLs, local files, app store links, deep links on device. Use when: need to open a webpage, local file, or app link on the phone.
---

# Phone Open — Claude Code Skill

Open URLs, files, and deep links on the Android device via ADB/Shizuku. Uses Android's native intent system — no extra app needed.

## Requirements

- ADB over TCP (127.0.0.1:5555) or Shizuku rish
- At least one channel must be active

## 🤖 AI Setup

```bash
# Verify connectivity (at least one should work)
rish -c 'echo ok' 2>/dev/null || adb -s 127.0.0.1:5555 shell echo ok || echo "No shell channel available"
```

## Commands

All commands shown in dual-channel format. Shizuku is primary (no WiFi needed), ADB is fallback.

### Open URL in browser
```bash
# Shizuku
timeout 10 rish -c 'am start -a android.intent.action.VIEW -d "https://example.com"'

# ADB fallback
timeout 10 adb -s 127.0.0.1:5555 shell am start -a android.intent.action.VIEW -d "https://example.com"
```

### Open local file
```bash
# Shizuku — image
timeout 10 rish -c 'am start -a android.intent.action.VIEW -d "file:///sdcard/photo.jpg" -t "image/*"'
# ADB — image
timeout 10 adb -s 127.0.0.1:5555 shell am start -a android.intent.action.VIEW -d "file:///sdcard/photo.jpg" -t "image/*"

# Shizuku — PDF
timeout 10 rish -c 'am start -a android.intent.action.VIEW -d "file:///sdcard/document.pdf" -t "application/pdf"'
# ADB — PDF
timeout 10 adb -s 127.0.0.1:5555 shell am start -a android.intent.action.VIEW -d "file:///sdcard/document.pdf" -t "application/pdf"
```

### Open app store page
```bash
# Shizuku
timeout 10 rish -c 'am start -a android.intent.action.VIEW -d "market://details?id=<package.name>"'
# ADB
timeout 10 adb -s 127.0.0.1:5555 shell am start -a android.intent.action.VIEW -d "market://details?id=<package.name>"
```

### Open app directly (by package name)
```bash
# Shizuku
timeout 10 rish -c 'monkey -p <package.name> 1'
# ADB
timeout 10 adb -s 127.0.0.1:5555 shell monkey -p <package.name> 1
```

## Performance Note

`am start` with intent resolution can take 3-10 seconds on some devices (Android resolves the best matching app, cold-starts it if needed). Always use `timeout 10` to prevent hanging. For non-critical opens (e.g., "show me a link"), fire and forget.

## OEM Notes

- Works on all Android devices — intent system is universal AOSP
- vivo, Oppo: may show "choose app" dialog on first use for each file type
- Huawei EMUI 12+: `am start` works even though `dumpsys activity` is blocked (different subsystem)
