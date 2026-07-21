---
name: voice-service-status
description: 微信语音闭环服务开发进度 (2026-05-30)
metadata: 
  node_type: memory
  type: project
  originSessionId: 67c9d1e3-6e8f-4205-946f-d61f6773700c
---

# 语音服务 V2 开发状态

## 当前状态：已对齐 cc-connect SendAudio，待测试验证

voice_service_v2.py 已实现完整闭环：
ASR (SiliconFlow SenseVoiceSmall) → AI (DeepSeek) → TTS (CosyVoice2-0.5B + 零样本声音克隆) → AMR 编码 → CDN 上传 → 语音发送

### 2026-05-30 修改：语音发送对齐 cc-connect SendAudio

对比 cc-connect platform/weixin/media_outbound.go 的 SendAudio，修复三个差异：

1. **音频格式**: OGG/Opus → **AMR-NB**（ffmpeg `-c:a amr_nb -ar 8000 -b:a 12.2k`）
2. **CDN media_type**: 4 (VOICE) → **3 (FILE)**，对齐 uploadMediaFile
3. **encode_type**: 8 (OGG_SPEEX) → **0 (AMR)**，去掉 playtime/sample_rate 多余字段

AES key 格式保持不变：base64(hex_string) = formatAesKeyForAPI

### 已完成
- [x] SiliconFlow ASR 调用正常
- [x] DeepSeek AI 调用正常
- [x] CosyVoice2-0.5B TTS + 零样本声音克隆正常
- [x] CDN 上传流程正常
- [x] sendmessage 返回 200 + ret=0
- [x] 语音发送链路对齐 cc-connect SendAudio（AMR + media_type=3 + encode_type=0）

### 待验证
- [ ] 微信端是否正常收到并播放语音消息

### 关键文件
- C:\Users\user\voice_service_v2.py — 主服务（已修改）
- C:\Users\user\voice_send_ilink.py — 独立语音发送测试
- C:\Users\user\mp3_to_silk.mjs — SILK 编码器
- cc-connect 源码: C:\Users\user\cc-connect-source\platform\weixin\media_outbound.go — 参考实现
