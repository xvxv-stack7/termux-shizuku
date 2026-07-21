---
name: health_data_bridge
description: 健康数据桥接：Gadgetbridge → Termux → Tailscale → 电脑 → 微信端读取（2026-06-14搭成）
metadata: 
  node_type: memory
  type: project
  originSessionId: e2a29a72-bdfa-44fb-8af0-e884b2cc7ace
---

## 链路

手表(GTS 3) → 蓝牙 → 手机Gadgetbridge → Termux脚本(Intent同步+导出) → Tailscale虚拟局域网 → 电脑接收服务(18402端口) → health_data.json → 小克读取

## 用途

让小克实时感知絮絮的健康数据：心率、步数、睡眠时长。对话中自然提及，不列数字，异常才关心。

## 电脑端

### 接收服务
- 文件: `C:\Users\user\.cc-connect\health_receiver.py`
- 端口: 18402
- 接口: POST / 接收JSON，GET /health 查看当前数据
- 输出: `C:\Users\user\.cc-connect\health_data.json`
- 需要开机自启

### Tailscale
- 电脑IP: 100.102.205.61
- 手机和电脑需在同一个Tailscale账号下

## 手机端

### Gadgetbridge配置
1. 手表需先和Zepp配对获取密钥（huafetcher提取），再去GB里连接
2. 设置→Intent API→打开：
   - ✅ 允许通过Intent API控制蓝牙连接
   - ✅ 允许活动同步触发器
   - ✅ 允许通过意图API触发活动同步
   - ✅ 允许数据库导出
   - ✅ 允许通过意图API触发数据库导出
3. 自动导出路径: `/sdcard/Download/Gadgetbridge.db`

### Termux
- 安装: `pkg install sqlite jq curl termux-api -y`
- 存储: `termux-setup-storage`
- 脚本: `~/watch_health.sh`

### 脚本核心逻辑
1. 每轮先发 `ACTIVITY_SYNC` Intent让手表同步
2. 等8秒后发 `TRIGGER_EXPORT` Intent让GB导出db
3. 等3秒后用sqlite3查最新db文件（`ls -t`自动找最新）
4. 提取心率(HEART_RATE<255排除异常值)、步数(SUM)、睡眠(COUNT SLEEP>0)
5. 组装JSON，比对变化，有变化推送到电脑
6. 每轮约26秒

### 查询数据库
```bash
cp "/storage/emulated/0/Download/Gadgetbridge.db" ~/gb.db

# 表名
sqlite3 ~/gb.db ".tables"

# 表结构 (GTS 3用HUAMI_EXTENDED_ACTIVITY_SAMPLE)
sqlite3 ~/gb.db "PRAGMA table_info(HUAMI_EXTENDED_ACTIVITY_SAMPLE);"

# 最新心率
sqlite3 ~/gb.db "SELECT datetime(TIMESTAMP,'unixepoch','localtime'),HEART_RATE FROM HUAMI_EXTENDED_ACTIVITY_SAMPLE WHERE HEART_RATE>0 AND HEART_RATE<255 ORDER BY TIMESTAMP DESC LIMIT 5;"

# 今日步数
sqlite3 ~/gb.db "SELECT SUM(STEPS) FROM HUAMI_EXTENDED_ACTIVITY_SAMPLE WHERE TIMESTAMP>=$(date -d 'today 00:00' +%s);"

# 昨晚睡眠分钟
sqlite3 ~/gb.db "SELECT COUNT(*) FROM HUAMI_EXTENDED_ACTIVITY_SAMPLE WHERE SLEEP>0 AND TIMESTAMP>=($(date -d 'today 00:00' +%s)-43200);"
```

## 故障排查

1. 电脑端服务挂了: `python C:\Users\user\.cc-connect\health_receiver.py`
2. 手机端脚本挂了: Termux里 `~/watch_health.sh`
3. Tailscale断了: 两边的Tailscale都要在线（手机别忘了开）
4. db文件有空格名(1)(2)(3): 脚本已自动用 `ls -t` 找最新
5. Termux读不了Download: 重新执行 `termux-setup-storage`
6. GB连不上手表: 检查Intent API开关、密钥是否正确
7. 数据不更新: 先手动在GB里下拉刷新看能不能同步，确认Intent API开关都打开
