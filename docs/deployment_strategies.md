---
name: deployment-strategies
description: 微信桥接24小时不掉线部署方案备忘
metadata:
  node_type: memory
  type: reference
  originSessionId: 4bc36164-122f-4cc8-95ba-c04f561f727c
---

## 24小时不掉线方案

当前方案：Windows 电脑永不休眠，cc-connect 开机自启。缺点：电脑偶尔还是会死机/重启。

进阶方案：

1. **软路由部署** — 家里常通电的路由器本质是 Linux，装 cc-connect 后永不关机
2. **旧手机 root + Debian** — 旧安卓刷 root 后装 Debian，手机当小服务器

两者本质：用一个永远不关机的 Linux 设备替代电脑。更稳定，无合盖休眠问题。

当前电脑方案够用，暂时不折腾。等以后有空再部署到软路由/手机。

**How to apply:** 用户问起部署稳定性时，可提及此方案。不要主动推动部署。
