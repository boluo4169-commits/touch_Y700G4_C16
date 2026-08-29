# Y700 四代模块仓库（触控优化 + 温控解除）

联想拯救者 Y700 第四代（骁龙 8 至尊版 / SM8750P，ColorOS 16 移植版）专用 KernelSU / Magisk 模块集合。

> 🆕 **v4.1 已发布**
> - extreme_gt：**单源码双变体**（safe 精简版 / full 完全版），安装时动态生成温控补丁，修复温控降帧表从未生效的挂载缺失，模块自挂载、元模块提示可忽略
> - touch_Y700G4_C16T：**v4.1 mtime 触发式低打扰守护**，修复游戏中音量键面板卡屏、退出游戏 2~3 秒触控失效、HRR 掉档需重启恢复三个长期问题
>
> ⚠️ v3.0 二合一模块（touch_Y700G4_C16）已停止维护并移除。

## 📦 模块列表

### 1️⃣ touch_Y700G4_C16T — 触控优化 `v4.1`

直控 Novatek 触控芯片，为游戏场景深度调优。

- 🔥 **360Hz 高采样** — 直控触控 IC（HighReportRate / game_edge / report_threshold），游戏内采样率拉满
- 🛡️ **mtime 零打扰守护** — 每 2 秒纯 stat 轮询节点 mtime（不触 I2C），系统动了触控配置才介入：进游戏校验只写异常节点 / 退出游戏放手+10s 冷却 / 游戏内 30s 兜底扫描
- ⚡ **低延迟** — 关闭系统级触控延迟优化与防误触过滤，SF 触控定时器归零
- 📲 在线更新（KSU Manager 一键检查更新）

📄 更新日志：[touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt](touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt)

### 2️⃣ extreme_gt — Extreme GT 温控解除 `4.2.1-Y700G4_C16`

基于 SCENE 团队 Extreme GT 4.2.1 的 **Y700G4 真机深度适配版**（作者：嘟嘟ski & 骏冲冲）。单源码双变体，安装时从真机分区动态生成全部温控补丁。

| | safe 精简版 (4211) | full 完全版 (4212) |
|---|---|---|
| 外壳/存储/内存温度伪装 29.5℃ | ✅ | ✅ |
| 电池/充电/USB 温度伪装 | ❌ 真实温度 | ✅ 一并伪装 |
| 充电高温保护 / 电池温度判定 | 系统原样 | 补丁放开 |

- 🌡️ 真机 88 个温区实测适配（SM8750P / sun 平台），伪装温控传感器解除降频锁帧
- 🩹 修复 KSU 下温控降帧表 `thermallevel_to_fps.xml`（全 144）从未生效的挂载缺失
- 🔩 全部补丁文件由模块自身 bind mount 挂载（含 odm），**KSU Manager 的元模块提示直接忽略**
- 🧹 完整卸载脚本，卸载无痕还原

📄 更新日志：[extgt_changelog.md](extgt_changelog.md)

## 📱 适用机型

| 项目 | 要求 |
| --- | --- |
| 机型 | 联想拯救者 Y700 第四代（2025 款） |
| 芯片 | 骁龙 8 至尊版（SM8750P / sun 平台） |
| 系统 | ColorOS 16 移植版 |
| Root | KernelSU（含 Zygisksu/SUSFS）或 Magisk |

⚠️ 仅限第四代，其他代次硬件方案不同，请勿刷入。

## 📲 安装

从 [Releases](https://github.com/boluo4169-commits/touch_Y700G4_C16/releases) 下载 zip：

- 触控：`touch_Y700G4_C16T_v4.1.zip`
- 温控：`ExtremeGT_4.2.1_Y700G4_C16_safe.zip`（日常推荐）/ `ExtremeGT_4.2.1_Y700G4_C16_full.zip`（跑分/极限场景）

KSU Manager → 模块 → 从本地安装 → 重启生效。两个模块互相独立、可同时使用。

> 刷入 extreme_gt 时 KSU Manager 可能提示「需要安装元模块」——**直接忽略**，模块自带 bind mount 挂载逻辑，重启后自动生效。

### 从 v2.x / v3.0 二合一升级

> ⚠️ 二合一模块的更新通道（根 `update.json`）已随 v4.1 关闭并删除——KSU Manager 检查更新将不再提示，这是有意的：自动通道无法完成「卸旧装新」的迁移，误操作会导致新旧模块共存冲突。请务必按下面步骤**手动迁移**。

1. KSU Manager 中**卸载 touch_Y700G4_C16** 并重启
2. 分别安装上面两个新模块，再次重启

### 从 4.2.1-safe_Y700G4 (4210) / 4.2.1-clean (4220) 升级

直接覆盖刷入对应变体即可（id 相同）。4220 用户因版本号高于新通道，请在 Releases 手动下载。

## 🔄 更新

- 自动：KSU Manager → 模块 → 检查更新（safe/full/触控各有独立通道）
- 手动：Releases 下载最新 zip 直接覆盖刷入

## 🗑️ 卸载

- KSU Manager → 模块 → 移除 → 重启
- extreme_gt 卸载脚本自动清零温度伪装、删除 persist 属性残留，bind mount 随重启自动解除
- touch 卸载脚本自动停守护、清 persist 属性、复位触控节点

## 🛠️ 构建

```bash
bash build.sh   # 产出三个 zip（CI 与本地通用）
```

Windows 本地可用 `build.ps1`（仓库外或本目录均可）。

## 🙏 致谢

- Extreme GT 原作：SCENE 团队 / 嘟嘟ski
- Y700G4 适配、KernelSU 兼容修复与 v4.1 守护重构：骏冲冲（[boluo4169-commits](https://github.com/boluo4169-commits)）
