# Extreme GT 5.0.1-Y700G4_C16 更新日志
> ℹ️ 本模块（id=extreme_gt）与触控模块（id=touch_Y700G4_C16T）互相独立。
> 若你之前装过旧的二合一模块 touch_Y700G4_C16 或其他温控类模块（如原版 Extreme GT），**请先卸载并重启后再刷入本模块**，避免同类功能冲突。
## 5.0.1-Y700G4_C16（versionCode safe=5003 / full=5004，tag v5.0.1）⚠️ 紧急修复
### 本版变更
- 🚨 **修复 5.0 的 CPU conf 补丁在安装期未生效**：customize.sh 中 sed 使用「反向引用 \\1 + 数字」写法（如 `\\150000`），GNU sed 与 toybox 下均正常，但 **KSU 安装器实际使用 busybox sed，多 `-e` 表达式链下该写法静默失效**——结果 zip 正常安装、bind mount 正常挂载，但模块树里的 conf 是未打补丁的原版（43000 旧阈值），游戏内限频依旧
- 🔧 修复方式：改为整行字面替换（不依赖反向引用），并用本机 KSU 自带 busybox 实测 10 表达式链全部生效、限频频率值零改动
- 📌 **受影响版本**：仅 5.0（5001/5002）；4.2.2 及更早版本不受影响（无此补丁）。装了 5.0 的用户请务必更新到 5.0.1
- 📦 触控模块 v5.0（5000）不受影响，无需重刷
## 5.0-Y700G4_C16（versionCode safe=5001 / full=5002，tag v5.0）
### 本版变更
- 🔥 **新增 CPU 限频档位阈值 +7°C**（`thermal-engine_cpu_0.conf` 补丁，safe/full 均带）：thermal-engine-v2 直读 TSENS 传感器、**不受温区伪装层影响**，实测（2026-09-08）游戏内 quiet-therm 43-48°C 时 43°C 档常驻触发、大核 4320→2841MHz 精确吻合 `THERM_CLUSTER-1_0`，开镜瞬间掉帧抖屏。现将大/小核六档触发温度 43/45/47/49/51→50/52/54/56/58°C（解除温度同步 +7），**限频梯度值与 60/62°C 深度兜底（cpu_4.conf）完整保留**——重度发热时仍有梯度限频，只是正常游戏温度不再误触发
- 🎯 **效果**：正常游戏温度区间（<50°C）CPU 不再被压频；对照实测：无限频时段游戏全程 0 clamp、0 抖感，触控断流为 18-40ms 背景噪声级（与限频无关）
- 📦 **与触控模块 v5.0 同页发布**：单触控版本版仅版本号对齐 + 署名修正（author），触控功能零改动
## 4.2.2-Y700G4_C16（versionCode safe=4221 / full=4222，tag v4.2）

### 本版变更
- 🧹 **移除 refresh_rate_config.xml 补丁**（`patch_rr_config` 与 `/data/system` 分支）：Y700G4 实机刷新率档位为 `x-x-x-7` 系列，原 sed 目标 `2-2-2-2` 从未命中，`<record` 删除亦零命中，属无效死代码；温控锁帧已由「温控总开关关闭 + 降帧表锁定」双重覆盖，删除后运行时行为不变
- ⚡ **温控降帧表锁帧 144 → 165**：Y700G4 面板支持 30–165Hz，永不降帧更彻底（不影响手动选择的刷新率档位）
- 🛠️ **修复自动更新通道缺失**：module.prop 补上 `updateJson`（此前构建脚本已有注入逻辑但模板缺失该行，注入无目标，导致 4.2.1 全部存量包实际收不到 KSU Manager 更新提示）
- ⚠️ **存量 4.2.1（4211/4212）用户升级方式**：旧包内无 updateJson，无法收到自动提示，请从 Releases 下载 4.2.2 对应变体**手动覆盖刷入**（id 相同直接覆盖）；自本版起自动更新通道恢复正常

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