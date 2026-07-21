---
name: smart-dispatch
description: 智能调度层——接到用户自然语言指令后，自动拆解步骤、从技能库中选择最快工具组合执行。使用时机：用户说"帮我XX"时。| Smart dispatch — decomposes natural language commands into steps, picks the fastest tool for each step from the skill library. Use when: user says "help me do X".
---

# Smart Dispatch — Claude Code Skill

This is a **meta-skill**. It doesn't add new commands — it teaches the AI how to compose existing skills in the fastest way.

## Principle

Every user command is decomposed into **tool-independent steps**. For each step, pick the fastest available tool from this priority ladder:

| Priority | Method | Speed | Use when |
|----------|--------|-------|----------|
| 1 | `content query/insert` | 0.5s | DB access (contacts, SMS, calendar) |
| 2 | `am start` / `am force-stop` | 1-2s | Open app, kill app, open URL |
| 3 | `uiautomator dump` (`elements.py`) | 1s | Find UI element coordinates |
| 4 | `input tap/keyevent/text` | 0.3s | Execute click/type after coordinates found |
| 5 | `cmd clipboard` + paste | 0.5s | Long Chinese text input |
| 6 | `dumpsys` (battery/power/wifi) | 0.5s | Read system state |
| 7 | `screencap` + vision AI | 7-8s | Last resort: unknown layout, scene understanding |

**Golden rule**: never use vision AI when uiautomator can find the element. 1s vs 8s.

## Available Tool Catalog

### Communication
| Task | Command | Speed |
|------|---------|-------|
| Find contact number | `content query --uri content://contacts/phones` | 0.5s |
| Send SMS | `content insert --uri content://sms ...` then `am start` broadcast | 2s |
| Read SMS inbox | `content query --uri content://sms` | 0.5s |
| Open WeChat to chat | `am start com.tencent.mm` → `elements.py --text "搜索" --tap` | 3s |

### System
| Task | Command | Speed |
|------|---------|-------|
| Battery | `dumpsys battery` | 0.5s |
| WiFi on/off | `svc wifi enable/disable` | 0.5s |
| Flashlight | `cmd flashlight on/off` | 0.3s |
| Storage | `df -h /sdcard` | 0.3s |
| Uptime | `cat /proc/uptime` | 0.2s |

### Media
| Task | Command | Speed |
|------|---------|-------|
| Screenshot | `screencap -p /sdcard/screenshot.png` | 1s |
| Play/pause | `input keyevent 85` | 0.3s |
| Next track | `input keyevent 87` | 0.3s |
| Open camera | `am start -a android.media.action.STILL_IMAGE_CAMERA` | 1s |

### UI Interaction
| Task | Command | Speed |
|------|---------|-------|
| Find button by text | `python3 elements.py --text "确认"` | 1s |
| Find + tap in one step | `python3 elements.py --text "确认" --tap` | 1s |
| Type Chinese text | `cmd clipboard set-text "内容"` → `input keyevent 279` | 0.5s |
| Tap coordinates | `input tap X Y` | 0.3s |
| Scroll | `input swipe X1 Y1 X2 Y2 300` | 0.5s |
| Back | `input keyevent 4` | 0.3s |
| Home | `input keyevent 3` | 0.3s |

### App Management
| Task | Command | Speed |
|------|---------|-------|
| Open app | `am start <package>` or `monkey -p <package> 1` | 1s |
| Force stop | `am force-stop <package>` | 0.5s |
| List installed | `pm list packages` | 1s |
| Uninstall | `pm uninstall <package>` | 2s |

### File System
| Task | Command | Speed |
|------|---------|-------|
| Recent photos | `ls -lt /sdcard/DCIM/Camera/ | head -10` | 0.3s |
| Downloads | `ls -lt /sdcard/Download/ | head -10` | 0.3s |
| Open file | `am start -d "file:///path" -t "mime/type"` | 2s |

## Composite Workflow Templates

### "Send WeChat to X saying Y"
```
1. am start com.tencent.mm                                   (launch WeChat)
2. python3 elements.py --text "搜索" --tap                    (tap search bar)
3. cmd clipboard set-text "X"; input keyevent 279              (paste contact name)
4. python3 elements.py --text "X" --tap                       (tap contact)
5. python3 elements.py --id "input" --tap                     (tap input field)
6. cmd clipboard set-text "Y"; input keyevent 279              (paste message)
7. python3 elements.py --text "发送" --tap                    (send)
Total: ~5s
```

### "Send SMS to X saying Y"
```
1. content query --uri content://contacts/phones (find X's number)
2. am start -a android.intent.action.SENDTO -d sms:NUMBER
3. input text "Y"; input keyevent 66 (send)
Total: ~3s
```

### "Take a screenshot and tell me what's on screen"
```
1. screencap -p /sdcard/screenshot.png
2. python3 vision.py /sdcard/screenshot.png "what's on screen?"
Total: ~8s (vision is the bottleneck)
```

### "Open file /sdcard/Download/report.pdf"
```
1. am start -d "file:///sdcard/Download/report.pdf" -t "application/pdf"
Total: ~2s
```

## Decision Logic

When the user says "do X", follow this decision tree:

1. **Is X a single system command?** → Run it directly (battery check, WiFi toggle, etc.)
2. **Does X involve finding a UI element?** → Use `elements.py`, not vision
3. **Does X involve typing Chinese?** → Use clipboard paste, not `input text`
4. **Does X span multiple apps?** → Chain the fastest method for each step
5. **Is the screen layout unknown/novel?** → Fall back to screenshot + vision

Always report: what you did, which tools you used, and how long it took. The user should see the speed difference between uiautomator (1s) and vision (8s).
