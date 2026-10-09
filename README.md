# Y700 四代模块仓库（触控优化 + 温控解除）

联想拯救者 Y700 第四代（骁龙 8 至尊版 / SM8750P，ColorOS 16 移植版）专用 KernelSU / Magisk 模块集合。

> **v5.3 已发布**（extreme_gt 5.3；touch_Y700G4_C16T v5.0.2）
> - extreme_gt 5.3 修的是「**打游戏掉帧、帧率一直在跳**」：根因是模块从 5.0.1 起默认 `stop horae`（OPPO 智能温控服务），SystemUI 的 `DynamicFrameRateManagerImpl` 因此**注册不到 ThermalListener**（logcat 持续报 `HoraeHelper: horae is not open` 与 `register ThermalListener failed`，约每 5.8s 一次），系统级动态刷新率失去温度反馈，在 **144Hz ↔ 165Hz 之间反复切换**，每次切屏都要重配 DPU/面板。真机对照（暗区突围对局 40s 采样）：屏幕模式切换 爆发式→**0 次**、`targetfps` 变化 26 次→**0 次**、三项报错全部**归零**；意外收获是修复前 **cpu6/cpu7（4.32GHz 超核）全程死钉 1.02GHz**，修复后能正常按负载冲到 4.32GHz。本版 `HORAE_OFF` 默认改为 0，并**不再覆盖 `sys_thermal_config.xml`**。
> - ⚖️ 取舍：恢复 horae 会同时恢复**框架层温控策略**（日志可见 `ThermalControlState=true`）。实测待机/对局温度 50–55℃、CPU/GPU `cooling_device` 全 0，未触发降频；长时间高负载是否降频仍需观察。想回退只需把 `service.sh` 的 `HORAE_OFF` 改回 `1`。
> - extreme_gt 5.2.2 修的是「**充电被限流**」：把 `quiet-therm` 移出伪装列表。这个温区不只喂框架的 skin，它同时是 **12 份 vendor 策略**的输入，其中 4 份 `thermal-engine_battery_*.conf` 直接用它决定充电电流上限（档位从 30℃ 起，实测 30℃→10A、38℃→3A、49℃→0.5A）。跟随式伪装把「硅温 − offset」写进它，等于把 40~55℃ 的假板温塞进充电链路，有用户反馈"充一晚上充不满"，真机复现到 0.5A；移除后同一负载下回到 3A（真实板温对应档位），空闲充电 10A。旧版 5.0.1 恒定 29.5℃ 恰好落在最低档以下，所以没这个问题。
> - extreme_gt 5.2.1 只动了一处，完全版的跟随偏移量从 20 提到 28，真实硅温要到 76℃ 左右才开始降频（原来 68℃）。精简版 safe 保持 20 不变。
> - 🛡️ 兜底一处没动，这才是敢往后挪的原因。写入硬上限 `skin_max=61℃` 已经踩到框架第 5 档，照样降频；锚点读到 95℃ 以上就当哨兵值扔掉；连续 3 轮没有可信锚点就全部归零，把温控权还给内核。offset 只管多晚开始管，兜底管的是最坏情况下还管不管得住。
> - ⚠️ 旧版 5.0.1 是把外壳温区一直写成 29.5℃，而框架的降频档位是 48/49/50/60/61/90℃，29.5 一个档都够不到，温度保护等于整条关掉，这才是真有烧穿风险的做法。offset 是差值，温度涨它就跟着涨；29.5 是常量，永远不动。两件事方向是反的。
> - extreme_gt 5.2 修掉了「打游戏时突然降频（屏幕变暗）」。原因有点意外，是我们自己干的。`lcm-thermal`（面板温度）原先在伪装列表里，跟随式伪装在高热时把它写成 `skin_max` 上限 61℃，越过了 vendor 背光保护阈值 55℃，等于伪造面板过热，thermal-engine 就把背光压到约 70%。现在把它移出伪装列表，背光保护改由真实面板温度决定。
> - 再往前，extreme_gt 5.1.x 修的是另一个问题。旧版把外壳温区恒定伪装成 29.5℃，而框架 skin 限频阈值是 `[48,49,50,60,61,90]℃`，恒定值永远够不到，等于把闭环输入整条掐断，重度使用后温度只升不降、熄屏仍发热。现在是跟随式伪装，伪装值随真实硅温同步抬升，平时不降频，重度发热自动恢复降温。详见 [extgt_changelog.md](extgt_changelog.md)。
> - touch_Y700G4_C16T v5.0.2 是补漏。v5.0.1 只把 service.sh 的日志版本号改成动态读取，漏了 touch_daemon.sh，那行还写着 `[v4.1]`，于是 apply.log 里两行版本对不上。现在两处都从 module.prop 读，触控功能没动。
> - 别用 5.1。那版开机就热关机，已撤回，直接用 5.3。
> - v3.0 二合一模块（touch_Y700G4_C16）已停止维护并移除。

## 📦 模块列表

### 1️⃣ touch_Y700G4_C16T — 触控优化 `v5.0.2`

直控 Novatek 触控芯片，为游戏场景深度调优。

- 🔥 **360Hz 高采样** — 直控触控 IC（HighReportRate / game_edge / report_threshold），游戏内采样率拉满
- 🛡️ **mtime 零打扰守护** — 每 2 秒纯 stat 轮询节点 mtime（不触 I2C），系统动了触控配置才介入：进游戏校验只写异常节点 / 退出游戏放手+10s 冷却 / 游戏内 30s 兜底扫描
- ⚡ **低延迟** — 关闭系统级触控延迟优化与防误触过滤，SF 触控定时器归零
- 🎚️ **config 帧率切换** — 模块目录 config 中 `fps=120 / 144 / 165` 三档可切（非法值自动回退 144）
- 📲 在线更新（KSU Manager 一键检查更新）

📄 更新日志：[touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt](touch_Y700G4_C16T/touch_Y700G4_C16T/CHANGELOG.txt)

### 2️⃣ extreme_gt — Extreme GT 温控解除 `5.3-Y700G4_C16`

基于 SCENE 团队 Extreme GT 4.2.1 的 **Y700G4 真机深度适配版**（作者：嘟嘟ski & 骏冲冲）。单源码双变体，安装时从真机分区动态生成全部温控补丁。

| | safe 精简版 (5301) | full 完全版 (5302) |
|---|---|---|
| 外壳/存储/内存温区**跟随式**伪装 | ✅ | ✅ |
| 跟随偏移 `skin_offset` | 20（真实 **~68℃** 介入）| 28（真实 **~76℃** 介入）|
| 电池/充电/USB 温度伪装 | ❌ 真实温度 | ✅ 一并伪装 |
| 充电高温保护 / 电池温度判定 | 系统原样 | 补丁放开 |

- 🎮 **保留 horae 温控服务**（5.3）— 不再 `stop horae`。停掉它会让 SystemUI 的动态帧率管理器
  （`DynamicFrameRateManagerImpl`）注册不到 `ThermalListener`，系统级动态刷新率失去温度反馈，
  在 144Hz ↔ 165Hz 之间反复切换，游戏内表现为持续掉帧；恢复后 cpu6/cpu7 超核也能正常 boost
- 🌡️ **跟随式皮肤伪装**（5.1.x）— `伪装值 = 真实硅温 − skin_offset`，
  随真实温度同步抬升；平时低于 48℃ 首档不降频，重度发热时自动跨过 48/49/50/60/61 恢复降温
- 🖥️ **`lcm-thermal` 不再伪装**（5.2）— 这个温区是 vendor 背光保护（`panel0-backlight`，阈值 55℃）的输入，
  伪装它就会伪造面板过热，游戏时突然降频（屏幕变暗）。现在不伪装了，保护基于真实面板温度
- 🔌 **`quiet-therm` 不再伪装**（5.2.2）— 它同时是框架 skin 的传感器（见下）和 **12 份 vendor 策略的输入**
  （4 份电池充电限流 + 5 份 CPU + 3 份 GPU）。伪装它会把假板温送进充电链路，把充电电流压到 0.5A；
  现在不伪装，充电与 CPU/GPU 限频都按真实板温工作
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

> ℹ️ `HORAE_OFF` 不在 `config` 里，它在 `service.sh` 顶部（5.3 起默认 `0` = 保留 horae）。

修改后重启生效。刷入后可用 `skin.log` / `service.log` 观察实际取值。

## 📱 适用机型

| 项目 | 要求 |
| --- | --- |
| 机型 | 联想拯救者 Y700 第四代（2025 款） |
| 芯片 | 骁龙 8 至尊版（SM8750P / sun 平台） |
| 系统 | ColorOS 16 移植版 |
| Root | KernelSU（含 Zygisksu/SUSFS）或 Magisk |

> 📌 5.3 验证所用移植包：酷安 **@一只鸽子**「咕咕 C16.0.8 v17.6 正式版」；**底包为酷安 @GUF296 的底包**（仍在使用，未更换）。

⚠️ 仅限第四代，其他代次硬件方案不同，请勿刷入。

## 📲 安装

从 [Releases](https://github.com/boluo4169-commits/touch_Y700G4_C16/releases) 下载 zip：

- 触控：`touch_Y700G4_C16T_v5.0.2.zip`
- 温控：`ExtremeGT_5.3_Y700G4_C16_safe.zip`（日常推荐）/ `ExtremeGT_5.3_Y700G4_C16_full.zip`（跑分/极限场景，更晚降频）

KSU Manager → 模块 → 从本地安装 → 重启生效。两个模块互相独立、可同时使用。

> 刷入 extreme_gt 时 KSU Manager 可能提示「需要安装元模块」——**直接忽略**，模块自带 bind mount 挂载逻辑，重启后自动生效。

### 升级到 5.3 / v5.0.2

`id` 均未变，**直接覆盖刷入对应变体**后重启即可。5.0.1 / 5.1 / 5.1.2 / 5.1.3 / 5.1.4 / 5.2 / 5.2.1 / 5.2.2 存量用户都适用。
（重启会清空 `emul_temp`，`lcm-thermal` 与 `quiet-therm` 立即恢复真实值，无需额外操作）

> ⚠️ 若你曾刷过 **5.1**（开机热关机那版）：请先用 KSU 安全模式进入系统
> （开机第一屏连按音量下 3 次），卸载/禁用模块后再刷 5.3。

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
  （`persist.sys.horae.enable` 也会被清掉，horae 开机自然恢复运行）
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
- Y700G4 适配、KernelSU 兼容修复、触控守护重构、5.1.x 温控负反馈修复、5.3 horae 动态帧率修复：骏冲冲（[boluo4169-commits](https://github.com/boluo4169-commits)）

## 📌 已知问题

- **`stop horae` 会连带打断系统动态帧率**（5.3 修复）。`horae` 是 ColorOS 的智能温控服务，
  停掉它会让 SystemUI 的 `DynamicFrameRateManagerImpl` 注册不到 `ThermalListener`，
  同时 `oiface` 每秒报 `getCurrentThermal, failed to get horae service`；系统级动态刷新率失去温度反馈后
  会在 144Hz/165Hz 之间反复切换。**5.3 起默认保留 horae**，`HORAE_OFF=0`。
  另一条相关坑：`sys_thermal_config.xml` 把 `isOpen` 置 0 正是 `HoraeHelper: horae is not open` 的直接来源，
  5.3 起不再覆盖该文件
- **`quiet-therm` 已于 5.2.2 移出伪装列表**。它同时是框架 `skin` 传感器与 **12 份 vendor 策略**的输入
  （4 份 `thermal-engine_battery_*.conf` + 5 份 cpu + 3 份 gpu），电池那几份的档位是 30/32/34/36/38/40/42/44/49℃，
  实测对应充电电流上限 30℃→10A、38℃→3A、49℃→0.5A。伪装它等于把假板温塞进充电链路，会触发限流
  （有用户反馈"充一晚上充不满"，换回 5.0.1 正常）。另注意 `emul_temp` 写值**不会自愈**：
  守护若被强杀（trap 未执行），最后一次写入的值会一直留着，直到重启
- **`lcm-thermal` 已于 5.2 移出伪装列表**（见上）。这个温区被 vendor 背光保护
  （`panel0-backlight`，阈值 55℃）依赖，伪装它会伪造面板过热，游戏时突然降频（屏幕变暗）
- **仍在伪装的 13 个温区**（`ap-therm` / `front_temp` / `back_temp` / `user_temp` / `user_front_temp` /
  `user_back_temp` / `flash-led-ntc` / `rear-cam-ntc` / `fcam-ntc` / `wlan-therm` / `xo-therm` / `ufs-therm` / `ddr`）
  已用 `grep "sensor *<名>$" /vendor/etc/*.conf` 逐个反查，**没有任何 vendor 配置引用**，写与不写都不影响 thermal-engine
- **恢复 horae 后框架层温控策略重新生效**（5.3）。实测待机/对局温度 50–55℃、`cooling_device` 全 0，
  尚未观察到降频；长时间高负载场景是否触发仍是待观察项。回退方式：`service.sh` 的 `HORAE_OFF` 改回 `1`
- **GPU 调频偏低待观察**（5.3 记录的观察项，非本次修改引入）。对局中 `/sys/kernel/gpu/gpu_clock` 稳定在
  222/342MHz（上限 1100MHz），`gpu_busy` 60–77%。当前不构成瓶颈，但若需要可临时抬高 `gpu_min_clock` 验证
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
