# Extreme GT 4.2.1-safe_Y700G4 更新日志

> ℹ️ 本模块（id=extreme_gt）与触控模块（id=touch_Y700G4_C16T）互相独立。
> 若你之前装过旧的二合一模块 touch_Y700G4_C16 或其他温控类模块（如原版 Extreme GT），**请先卸载并重启后再刷入本模块**，避免同类功能冲突。

## 4.2.1-safe_Y700G4（versionCode 4210）

基于 SCENE Extreme GT 4.2.1 的联想拯救者 Y700 四代真机深度适配版。
作者：嘟嘟ski & 骏冲冲

### Y700G4 适配内容
- 🌡️ 温区适配：基于真机 88 个温区逐一实测，伪装外壳类（ap-therm / front_temp / back_temp）与存储类（ddr / wlan / xo / ufs / quiet / lcm）温度为 29500（29.5℃）
- 🔋 安全版：保留电池真实温度（battery / batt-pack / usb），充电保护、电池安全逻辑完全不受影响
- ⛔ 自动停止 OPPO 智能温控服务 horae，并写入 persist 属性防止复活
- ✅ KernelSU 兼容修复：原版脚本在 KSU 下排除 odm 分区挂载导致核心温控 XML 不生效，本版已修复
- 🧹 完整卸载脚本：卸载时自动清零所有温度伪装、删除 persist 属性残留，重启后 bind mount 自动解除，原版温控 XML 无损还原

### 与 full 版区别
| | safe 版 | full 版 |
|---|---|---|
| 外壳/存储类温度伪装 | ✅ | ✅ |
| 电池真实温度保留 | ✅ | ❌ 一并伪装 |
| 充电保护 | 正常 | 可能受影响 |

日常使用推荐 safe 版。

### 适用范围
仅限：联想拯救者 Y700 四代 / SM8750P（sun 平台）/ ColorOS 16 移植版。其他设备请勿刷入。