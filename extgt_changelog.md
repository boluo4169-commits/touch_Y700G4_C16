# Extreme GT 4.2.1-Y700G4_C16 更新日志

> ℹ️ 本模块（id=extreme_gt）与触控模块（id=touch_Y700G4_C16T）互相独立。
> 若你之前装过旧的二合一模块 touch_Y700G4_C16 或其他温控类模块（如原版 Extreme GT），**请先卸载并重启后再刷入本模块**，避免同类功能冲突。

## 4.2.1-Y700G4_C16（versionCode safe=4211 / full=4212，tag v4.1）

仓库重构版：单源码双变体（safe 精简版 / full 完全版），安装时从真机分区动态生成全部温控补丁，不再内置静态 XML。

### 本版变更
- 🧩 **双变体单源码**：`BATT_EMUL` / 补丁范围由构建注入，safe（4211）与 full（4212）出自同一份源码，`id=extreme_gt` 相同可互相覆盖刷入
- ⚡ **安装时动态适配**：customize.sh 在安装期扫描 `/odm /my_product /my_stock /vendor /product /system` 的温控 XML 并打补丁，ROM 更新后重装即可重新适配；删除 MTK d1x00 死代码
- 🩹 **修复 thermallevel_to_fps 挂载缺失**：KSU 下 `/system/vendor` 为符号链接导致模块自动 overlay 不生效，旧版该文件（温控降帧表全 144）从未真正挂上；现改为 post-fs-data 显式 bind mount
- 🔩 **odm 纳入自带挂载清单**：实测 ksud 4.1.0/sun 内核下 `/odm` bind mount 可用，全部补丁文件由模块自挂，**元模块提示可忽略**，不依赖 KSU 原生 overlay
- 🏷️ 删除指向通用 OPPO 包的 updateJson 旧通道；新增 safe/full 独立更新通道
- 📝 电池/充电/USB 类温区伪装（`BATT_EMUL=1`）与 `devices_config.json` 电池温度区间放宽、`sys_high_temp_protect` 充电高温保护补丁仅 full 变体执行；safe 变体完全不碰电量链路

### 与 full 版区别
| | safe 精简版 (4211) | full 完全版 (4212) |
|---|---|---|
| 外壳/存储/内存温度伪装 29.5℃ | ✅ | ✅ |
| 电池/充电/USB 温度伪装 | ❌ 真实温度 | ✅ 一并伪装 |
| devices_config 电池温度区间放宽 | ❌ | ✅ |
| sys_high_temp_protect 充电高温保护补丁 | ❌ | ✅ |
| 日常推荐 | ✅ | 跑分/极限场景 |

### 适用范围
仅限：联想拯救者 Y700 四代 / SM8750P（sun 平台）/ ColorOS 16 移植版。其他设备请勿刷入。

---

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