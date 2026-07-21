---
name: sky-keyboard-setup
description: 光遇聊天 Arduino 虚拟键盘方案，2026-06-15 验证通过
metadata: 
  node_type: memory
  type: reference
  originSessionId: 33afb349-228d-4fd7-9c87-126f65cb846f
---

光遇 PC 版屏蔽所有软件模拟按键（SendInput/keybd_event/PostMessage 全无效），唯一可行方案是通过 Arduino Leonardo/Pro Micro（ATmega32U4）作为 USB HID 硬件键盘。

**Why:** 光遇用 DirectInput，只认硬件键盘扫描码，软件模拟全部被拦截。Arduino 在系统层面是真正的 USB 键盘。

**文件位置:** `C:\Users\user\.cc-connect\sky\`

- `sky_keyboard/sky_keyboard.ino` — Arduino 固件，收到串口 "SEND" 后执行 Enter→Ctrl+A→Backspace→Ctrl+V→Enter
- `send.py` — Python 发送脚本，先复制到剪贴板再通知 Arduino 粘贴
- `capture.py` — 截图 + easyocr 识别聊天内容
- `config.json` — 聊天区域坐标和输入框位置

**Arduino 工具链:**
- arduino-cli 在 `C:\Users\user\.cc-connect\arduino-cli\arduino-cli.exe`
- 数据目录: `C:\Users\user\.cc-connect\arduino-data`
- 板子: arduino:avr:leonardo, VID=2341 PID=8036, COM 口自动检测

**用法:**
```
python C:\Users\user\.cc-connect\sky\send.py "消息内容"
```
