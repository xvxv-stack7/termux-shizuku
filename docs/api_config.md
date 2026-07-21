---
name: api-config
description: 使用 DeepSeek API 后端，非 Anthropic 原生 API
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4bc36164-122f-4cc8-95ba-c04f561f727c
---

Claude Code 通过 DeepSeek API 后端运行，配置在 .claude/settings.json 中。

- Base URL: https://api.deepseek.com/anthropic
- 主模型: deepseek-v4-pro[1m]
- Flash 模型: deepseek-v4-flash
- 超时: 3000s

**How to apply:** 遇到 API 相关问题时，注意这是 DeepSeek 兼容层，非原生 Anthropic API。部分 Claude 特性可能不可用。
