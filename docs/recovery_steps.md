---
name: recovery-steps
description: Claude Code + DeepSeek + cc-connect 最快恢复步骤，换电脑/重装后使用
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5292c4e7-e550-4817-9a4e-38a6780c8892
---

# 最快重建方法（换电脑/重装后）

## 1. 设置 Machine 级环境变量（需管理员权限）
```powershell
[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'http://localhost:8099', 'Machine')
[Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', 'sk-5dd7dbadb864446493da70de1ae33ed8', 'Machine')
```

## 2. 启动代理
```bash
node C:\Users\user\.cc-connect\proxy\server.mjs
```

## 3. 扫码连接微信
```bash
cc-connect weixin setup --project wechat-bot
```

## 4. 安装守护进程
```bash
cc-connect daemon install --work-dir $env:USERPROFILE\.cc-connect
```

## 关键点
- 环境变量必须设 **Machine 级别**（不是 User），否则计划任务继承不到
- 代理必须拦截 `HEAD /` 返回 200，否则 Claude Code 拒绝工作（报 Not logged in）
- Claude Code 新版本可能不支持 DeepSeek 接入，报错时可回退版本：`npm install -g @anthropic-ai/claude-code@<稳定版本号>`
- PowerShell 执行策略需 RemoteSigned 或 Bypass，否则 npm/cc-connect 无法执行

## 相关
- [[api_config]] — DeepSeek API 后端配置
- [[inspect]] — 巡检脚本，一键检测和自动修复所有检查项
