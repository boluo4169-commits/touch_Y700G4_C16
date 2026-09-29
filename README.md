# Y700 四代模块仓库（触控优化 + 温控解除）

联想拯救者 Y700 第四代（骁龙 8 至尊版 / SM8750P，ColorOS 16 移植版）专用 KernelSU / Magisk 模块集合。

> **v5.2 已发布**（extreme_gt 5.2；touch_Y700G4_C16T v5.0.1）
> - extreme_gt 5.2 修掉了「打游戏时突然降频（屏幕变暗）」。原因有点意外，是我们自己干的：`lcm-thermal`（面板温度）原先在伪装列表里，跟随式伪装在高热时把它写成 `skin_max` 上限 61℃，越过了 vendor 背光保护阈值 55℃，等于伪造面板过热，thermal-engine 就把背光压到约 70%。现在把它移出伪装列表，背光保护改由真实面板温度决定。
> - 再往前，extreme_gt 5.1.x 修的是另一个问题：旧版把外壳温区恒定伪装成 29.5℃，而框架 skin 限频阈值是 `[48,49,50,60,61,90]℃`，恒定值永远够不到，等于把闭环输入整条掐断，重度使用后温度只升不降、熄屏仍发热。现在是跟随式伪装：伪装值随真实硅温同步抬升，平时不降频，重度发热自动恢复降温。详见 [extgt_changelog.md](extgt_changelog.md)。
> - touch_Y700G4_C16T v5.0.1 只是把日志里的版本号改成动态读取（此前写死 v4.2），触控功能没动。
> - 别用 5.1。那版开机就热关机，已撤回，直接用 5.2。
> - v3.0 二合一模块（touch_Y700G4_C16）已停止维护并移除。

## 📦 模块列表

### 1️⃣ touch_Y700G4_C16T — 触控优化 `v5.0.1`

直控 Novatek 触控芯片，为游戏场景深度调优。

- 🔥 **360Hz 高采样** — 直控触控 IC（HighReportRate / game_edge / report_threshold），游戏内采样率拉满
- 🛡️ **mtime 零打扰守护** — 每 2 秒纯 stat 轮询节点 mtime（不触 I2C），系统动了触控配置才介入：进游戏校验只写异常节点 / 退出游戏放手+10s 冷却 / 游戏内 30s 兜底扫描
- ⚡ **低延迟** — 关闭系统级触控延迟优化与防误触过滤，SF 触控定时器归零
- 🎚️ **config 帧率切换** — 模块目录 config 中 `fps=120 / 144 / 165` 三档可切（非法值自动回退 144）
- 📲 在线更新（KSU Manager 一键检查更新）

📄 更新日志：[touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt](touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt)

### 2️⃣ extreme_gt — Extreme GT 温控解除 `5.2-Y700G4_C16`

基于 SCENE 团队 Extreme GT 4.2.1 的 **Y700G4 真机深度适配版**（作者：嘟嘟ski & 骏冲冲）。单源码双变体，安装时从真机分区动态生成全部温控补丁。

| | safe 精简版 (5201) | full 完全版 (5202) |
|---|---|---|
| 外壳/存储/内存温区**跟随式**伪装 | ✅ | ✅ |
| 电池/充电/USB 温度伪装 | ❌ 真实温度 | ✅ 一并伪装 |
| 充电高温保护 / 电池温度判定 | 系统原样 | 补丁放开 |

- 🌡️ **跟随式皮肤伪装**（5.1.x）— `伪装值 = 真实硅温 − skin_offset`（默认 20℃），
  随真实温度同步抬升；平时低于 48℃ 首档不降频，重度发热时自动跨过 48/49/50/60/61 恢复降温
- 🖥️ **`lcm-thermal` 不再伪装**（5.2）— 这个温区是 vendor 背光保护（`panel0-backlight`，阈值 55℃）的输入，
  伪装它就会伪造面板过热，游戏时突然降频（屏幕变暗）。现在不伪装了，保护基于真实面板温度
- 🔒 **写入硬上限** — 伪装值绝不高于 `skin_max`（默认 61℃），设计上不可能写出接近 90℃ 的值
- 🔍 **锚点可信域过滤** — 只接受 15~95℃ 的读数；开机初期部分 TSENS 温区会返回 `105.0℃` 哨兵值（NSP/CPUSS 等掉电状态），超出即弃用该温区
- 🐕 **守护健壮性**（5.1.4）— `sleep` 失效即退出、速率看门狗检测空转、关机检测、归零退避；
  时间戳支持 `date` → `/proc/uptime` 双通道（不依赖外部命令）
- 🩹 修复 KSU 下温控降帧表 `thermallevel_to_fps.xml`（全 165）从未生效的挂载缺失
- 🌡️ CPU 限频档位阈值 +7℃（`thermal-engine_cpu_0.conf`）
- 🔩 全部补丁文件由模块自身 bind mount 挂载（含 odm），**KSU Manager 的元模块提示直接忽略**
- 🧹 完整卸载脚本，卸载无痕还原

📄 更新日志：[extgt_changelog.md](extgt_changelog.md)

### ⚙️ 温控模块参数调整（`/data/adb/modules/extreme_gt/config`）

| 参数 | 默认 | 含义 |
|---|---|---|
| `skin_mode` | `follow` | `follow` 正常伪装 / `log` 干跑（只记录不写节点）/ `off` 完全不伪装（最保守）|
| `skin_offset` | `20` | 伪装值 = 真实硅温 − offset（℃）。**调小＝更早介入降温** |
| `skin_max` | `61` | 伪装值硬上限（℃），允许范围 40~70 |
| `skin_min` | `30` | 伪装值下限（℃）|
| `hard_real` | `95` | 锚点可信域上限（℃），超出视为哨兵值 |

修改后重启生效。刷入后可用 `skin.log` / `service.log` 观察实际取值。

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

- 触控：`touch_Y700G4_C16T_v5.0.1.zip`
- 温控：`ExtremeGT_5.2_Y700G4_C16_safe.zip`（日常推荐）/ `ExtremeGT_5.2_Y700G4_C16_full.zip`（跑分/极限场景）

KSU Manager → 模块 → 从本地安装 → 重启生效。两个模块互相独立、可同时使用。

> 刷入 extreme_gt 时 KSU Manager 可能提示「需要安装元模块」——**直接忽略**，模块自带 bind mount 挂载逻辑，重启后自动生效。

### 升级到 5.2 / v5.0.1

`id` 均未变，**直接覆盖刷入对应变体**后重启即可。5.0.1 / 5.1 / 5.1.2 / 5.1.3 / 5.1.4 存量用户都适用。
（重启会清空 `emul_temp`，`lcm-thermal` 立即恢复真实值，无需额外操作）

> ⚠️ 若你曾刷过 **5.1**（开机热关机那版）：请先用 KSU 安全模式进入系统
> （开机第一屏连按音量下 3 次），卸载/禁用模块后再刷 5.2。

### 从 v2.x / v3.0 二合一升级

> ⚠️ 二合一模块的更新通道（根 `update.json`）已随 v4.1 关闭并删除——KSU Manager 检查更新将不再提示，这是有意的：自动通道无法完成「卸旧装新」的迁移，误操作会导致新旧模块共存冲突。请务必按下面步骤**手动迁移**。

1. KSU Manager 中**卸载 touch_Y700G4_C16** 并重启
2. 分别安装上面两个新模块，再次重启

## 🔄 更新

- 自动：KSU Manager → 模块 → 检查更新（safe / full / 触控各有独立通道）
- 手动：Releases 下载最新 zip 直接覆盖刷入

## 🗑️ 卸载

- KSU Manager → 模块 → 移除 → 重启
- extreme_gt 卸载脚本自动停守护、清零全部温度伪装、删除 persist 属性残留，bind mount 随重启自动解除
- touch 卸载脚本自动停守护、清 persist 属性、复位触控节点

## 🛠️ 构建

```bash
bash build.sh   # 产出三个 zip（CI 与本地通用）
```

- 优先使用系统 `zip`；Windows / 无 zip 环境自动回退到 `python` 的 `zipfile`
  （**不要**用 `tar -a -f out.zip`，GNU tar 不支持 zip 输出，只会生成「名字叫 .zip 的 tar」，KSU 无法安装）
- 打包前会执行 `lint_glued_keywords()` 静态检查：扫描 shell 脚本中「关键字被粘在上一行末尾」
  （如 `echo x >> f`else）这类 `bash -n` 查不出的静默逻辑损坏，命中即中止打包

## 🙏 致谢

- Extreme GT 原作：SCENE 团队 / 嘟嘟ski
- Y700G4 适配、KernelSU 兼容修复、触控守护重构、5.1.x 温控负反馈修复：骏冲冲（[boluo4169-commits](https://github.com/boluo4169-commits)）

## 📌 已知问题

- **`quiet-therm` 还在伪装列表里，会影响 vendor 的电池充电限制**。`thermal-engine_battery_*.conf`
  把 `quiet-therm` 当输入（阈值 33~52℃，`actions battery` 共 10 档），跟随模式下高热时会自动触发
  高温限充，边充边玩会变慢。这属于正当保护，如需放开需另行评估。原版钉死 29.5℃ 时不会触发
- **`lcm-thermal` 已于 5.2 移出伪装列表**（见上）。这个温区被 vendor 背光保护
  （`panel0-backlight`，阈值 55℃）依赖，伪装它会伪造面板过热，游戏时突然降频（屏幕变暗）
- 根目录 `extgt_update_v4.json` 是历史遗留死文件，可删除
- 触控模块目录下的外层 `touch_Y700G4_C16T/update.json` 无人引用
  （`module.prop` 实际引用的是 `touch_Y700G4_C16T/touch_Y700G4_C16T/touch_update.json`）。
  两份内容已于 v5.0.1 一并校正，保留外层文件仅为兼容历史引用
- 温区统计注释（`service.sh` 历史注释）称「131 个温区 / 88 个支持 emul_temp」，
  实测是 88 个温区、全部支持
- `dumpsys thermalservice` 的 `Cached temperatures` 在本移植 ROM 上数值陈旧、异常
  （比如 CPU6 显示 91.5℃ 而 HAL 直读 37.8℃），属 ROM 既有问题，与模块无关。
  所以这个 ROM 上框架层 `Thermal Status` 阈值不可靠
- **框架层热亮度节流在本 ROM 上没启用**。`dumpsys display` 里
  `mThermalBrightnessThrottlingDataMapByThrottlingId={}` 是空的。屏幕降频（变暗）只可能来自
  vendor 的 `panel0-backlight`（见上）
- `emul_temp` 权限是 `--w-------`（只写），root 也无法读回，验证写入得改看 `temp`
