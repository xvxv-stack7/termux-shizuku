---
name: phone-api-architecture
description: 手机REST API架构——phone-api.py 18403端口，9个读写端点，替代phone-mcp-server的锁斗问题
metadata: 
  node_type: memory
  type: reference
  originSessionId: a54ddd07-855e-454e-a32f-354bb041f2a6
---

# 手机数据查询架构（2026-06-25 完工）

## 现状

两条线各跑各的，不冲突：

### 线路一：phone-api REST（主力）
- **手机端**：`python3 ~/phone-api.py` 监听 18403
- **电脑端**：`curl http://100.64.71.8:18403/端点名`
- **优势**：不经过MCP协议，不受transport单例锁影响
- **网络**：Tailscale，手机IP 100.64.71.8

### 线路二：phone-mcp-server（备用）
- **手机端**：`cd ~/phone-mcp-server && node server.js` 监听 3000
- **电脑端**：MCP客户端注册（需重启Claude Code加载）
- **问题**：单例transport，连上就锁，REST脚本会被挡

## phone-api 已通端点（9个）

| 端点 | 功能 | 状态 |
|------|------|------|
| /battery | 电量、充电、温度 | 通 |
| /location | 网络定位（30米） | 通 |
| /clipboard | 读剪贴板 | 空（待修参数） |
| /wifi | WiFi状态 | 空（待修参数） |
| /device | 设备信息 | 超时（待修参数） |
| /volume | 音量 | 空（待修参数） |
| /contacts | 联系人 | 待测 |
| /sms | 短信 | 待测 |
| /calllog | 通话记录 | 待测 |

## phone-api 还缺端点（9个）

send_sms, set_clipboard, take_photo, make_call, flashlight, vibrate, send_notification, set_volume, record_audio

## GPS 定位系统（独立线路）

- **电脑端**：`gps_receiver.py` 监听 15890，写入 location_status.json
- **手机端**：`termux_gps.py` 每10分钟网络定位POST到电脑15890
- **SERVER地址**：`http://100.102.205.61:15890`（termux_gps.py第3行需更新）
- **校门坐标**：(27.973132, 120.555541)，半径1000米

## 健康数据（独立线路）

- **手机端**：`bash ~/watch_health.sh`
- **电脑端**：health_data.json（18402端口接收）

## 关联文件

- `C:\Users\user\.cc-connect\gps_receiver.py` — GPS接收服务
- `C:\Users\user\.cc-connect\termux_gps.py` — 手机端GPS上报（需改SERVER行）
- `C:\Users\user\.cc-connect\location_status.json` — 位置状态
- `C:\Users\user\.cc-connect\health_data.json` — 健康快照
- `C:\Users\user\.claude\skills\phone\SKILL.md` — phone技能定义
- `~phone-api.py` — 手机端REST服务（在手机Termux home目录）
