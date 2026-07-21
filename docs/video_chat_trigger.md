---
name: video-chat-trigger
description: "当絮絮说\"小克，我想视频聊天\"时，自动回复视频聊天网址"
metadata: 
  node_type: memory
  type: trigger
  originSessionId: ced55fff-81c7-4775-8d43-fc0b9fbda136
---

## 视频聊天触发词

当絮絮发送以下任一消息时，回复视频聊天链接：
- "小克，我想视频聊天"
- "小克我想视频聊天"
- "视频聊天"

**回复内容**：直接发送链接 `file:///D:/clawd-interactive/index.html`（或部署后的线上地址），不要加多余的说明文字。

项目路径：`D:\clawd-interactive\`
本地 HTTP 服务：`http://localhost:8765`
