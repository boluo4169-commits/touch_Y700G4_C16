# Y700 四代模块仓库（触控优化 + 温控解除）

联想拯救者 Y700 第四代（骁龙 8 至尊版 / SM8750P，ColorOS 16 移植版）专用 KernelSU / Magisk 模块集合。

> 🆕 **v4.0-clean 仓库整理版已发布（2026-08-27）**
> 本次只整理源码、清理 MTK 平台死代码、补全 build/CI 基础设施 —— **不改变任何模块行为**。
> - extreme_gt：4.2.1-safe → 4.2.1-clean（行为 100% 一致）
> - touch_Y700G4_C16T：源码首次入库，KSU Manager 云端更新通道启用
> - KSU Manager 应自动提示更新；如未提示，可在模块页手动 "检查更新"

> ⚠️ **v3.0 二合一模块（touch_Y700G4_C16）已停止维护并移除**，由下面两个独立模块替代。详见 [changelog.md](changelog.md)。

## 📦 模块列表

### 1️⃣ touch_Y700G4_C16T — 触控优化单模块 `v3.2T`

直控 Novatek 触控芯片，为游戏场景深度调优。

- 🔥 **360Hz 高采样** — 直控触控 IC，游戏内采样率拉满，跟手度显著提升
- 🛡️ **游戏防断触** — 游戏内断触 2 秒自动兜底；非游戏场景完全放手
- ⚡ **低延迟** — 关闭系统级触控延迟优化与防误触过滤
- 📲 在线更新（KSU Manager 一键检查更新）

📄 更新日志：[touch_Y700G4_C16T/changelog.md](touch_Y700G4_C16T/changelog.md)

### 2️⃣ extreme_gt — Extreme GT 温控适配版 `4.2.1-safe_Y700G4`

基于 SCENE 团队 Extreme GT 4.2.1 的 **Y700G4 真机深度适配版**（作者：嘟嘟ski & 骏冲冲）。

**safe 版特性（推荐）：**
- 🌡️ 伪装外壳/存储类温度传感器（29.5℃），解除系统降频锁帧
- 🔋 保留电池真实温度兜底，充电保护正常
- ✅ KernelSU 兼容修复：odm 分区 bind mount 正常挂载（原版在 KSU 下不生效）
- 🧹 完整卸载脚本，卸载无痕还原
- 基于 Y700G4 真机 88 个温区逐一实测适配

📄 更新日志：[extgt_changelog.md](extgt_changelog.md)

## 📱 适用机型

| 项目 | 要求 |
| --- | --- |
| 机型 | 联想拯救者 Y700 第四代（2025 款） |
| 芯片 | 骁龙 8 至尊版（SM8750P / sun 平台） |
| 系统 | ColorOS 16 移植版 |
| Root | KernelSU（含 Zygisksu/SUSFS）或 Magisk |

⚠️ 仅限第四代，其他代次硬件方案不同，请勿刷入。Extreme GT 适配件基于真机温控表定制，其他设备刷了无效。

## 📲 安装

1. 从 [Releases](https://github.com/boluo4169-commits/touch_Y700G4_C16/releases) 下载 zip：
   - 触控：`touch_Y700G4_C16T_v3.2T.zip`
   - 温控：`extreme_gt_safe_y700g4.zip`（安全版）/ `extreme_gt_full_y700g4.zip`（完整版，伪装电池温度）
2. KSU Manager → 模块 → 从本地安装 → 选择 zip
3. 重启生效

两个模块互相独立、可单独使用、可同时使用（推荐搭配）。

### 从 v2.x / v3.0 二合一升级

旧模块已停止维护，请按以下步骤迁移：

1. KSU Manager 中**卸载 touch_Y700G4_C16** 并重启
2. 分别安装上面两个新模块，再次重启

KSU 内检测更新会直接提示本版本（versionCode 4210）。

## ⚠️ KernelSU 用户须知

刷入 extreme_gt 后，KSU Manager 可能弹出「模块包含系统文件，需要安装元模块」提示——**直接忽略即可，无需安装元模块**。

本模块自带 bind mount 挂载逻辑（已修复 KSU 兼容性），重启后自动生效，可用以下命令自行验证：

```bash
# 读到 feature_enable=false 即为挂载成功
grep feature_enable /odm/etc/temperature_profile/sys_thermal_control_config.xml
```

## 🔄 更新

- 自动：KSU Manager → 模块 → 检查更新
- 手动：Releases 下载最新 zip 直接覆盖刷入

## 🗑️ 卸载

- KSU Manager → 模块 → 移除 → 重启
- extreme_gt 自带完整卸载脚本：自动清零温度伪装、删除 persist 属性残留，bind mount 随重启自动解除，原版温控 XML 无损还原

## 🙏 致谢

- Extreme GT 原作：SCENE 团队 / 嘟嘟ski
- Y700G4 适配与 KernelSU 兼容修复：骏冲冲（[boluo4169-commits](https://github.com/boluo4169-commits)）