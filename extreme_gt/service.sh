#!/system/bin/sh
# ============================================================
# Extreme GT Y700G4 (SM8750P/sun) ColorOS16 移植版 — service.sh (5.1.3)
#
# ── 5.1 关键变更：废弃「skin 恒定 29.5C」静态伪装 ──
# 旧版把表面/外壳类温区统一写成 emul_temp=29500。经真机复测确认这切断了温控
# 负反馈：框架 skin 阈值 [48,49,50,60,61,90]C 永远够不到 -> Thermal Status 恒 0
# -> 无限频动作 -> 重度使用后温度无上限上升（实测超大核 85.7C 仍不降频），
# 且熄屏后仍持续发热。
# 现改为由 skin_daemon.sh 执行「跟随式伪装」：伪装值随真实硅温同步抬升，
# 平时不降频、重度发热时自动跨过阈值恢复降温。详见 skin_daemon.sh 头注释。
#
# ── 5.1.2 事故修复 ──
# 5.1 的守护把「开机初期 TSENS 返回的 105.0C 哨兵值」误当作真实温度，写进了
# skin 温区，导致框架判定外壳 105C 而立即热关机（真机现象：开机亮屏后约 7s
# 关机，skin.log 留有 "real=105.0C -> fake=105.0C"）。
# 修复见 skin_daemon.sh：锚点可信域过滤 + 写入硬上限 + 异常归零兜底。
# 另：5.1 曾同时把 horae 默认值改成"保留运行"；虽事后证明其并非本次关机主因，
# 但仍属不该动的默认值，5.1.1 起已恢复 5.0.1 行为（继续 stop horae）并保持至今。
# 教训：① 传感器原始读数未经校验绝不能写回系统；② 一次版本只改一件事。
#
# ── 保留项 ──
# · full 变体的电池/充电/USB 类温区伪装（电量链路，语义不变）
# ============================================================

MODDIR=${0%/*}
LOG_FILE="$MODDIR/service.log"

# 版本号从 module.prop 动态读取 —— 避免日志与版本号漂移(曾出现日志写死旧版本)
VER=$(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1)
[ -z "$VER" ] && VER="unknown"

T=29500                        # 电池类伪装温度 29.5C
# __BATT_EMUL__ 由 build.sh 按变体注入: safe=0 / full=1
BATT_EMUL=__BATT_EMUL__

# 是否关闭 OPPO 智能温控服务 horae
#   1 = 关闭 horae（5.0.1 ~ 5.2.2 的默认行为）
#   0 = 保留 horae（2026-10-09 起改为默认；仍需自行确认无热降频副作用）
#
# 变更理由（2026-10-09，Y700G4 + ColorOS16 新底包 实机定位）：
#   stop horae 之后，SystemUI 的 DynamicFrameRateManagerImpl 无法注册
#   ThermalListener —— logcat 持续报（约每 5.8s 一次）：
#     E HoraeHelper: horae is not open
#     D DynamicFramerate [DynamicFrameRateManagerImpl]: register ThermalListener failed
#   同时 oiface 每秒报 getCurrentThermal, failed to get horae service。
#   后果：系统级「动态刷新率」失去温度反馈输入，刷新率在 144Hz <-> 165Hz
#   之间反复切换（日志 COSA->DynamicRefreshRate / ScreenModeControl
#   "current refresh rate 144 setvalue 165" 等），每次切屏都要重配 DPU/面板，
#   游戏内表现为持续掉帧、帧率跳动。
#   * 待重启验证：确认无副作用后转为正式默认；若引入热降频则回退为 1。
HORAE_OFF=0

echo "$(date): ===== Extreme GT ${VER} service start (variant BATT_EMUL=${BATT_EMUL}) =====" > "$LOG_FILE"

# ============================================================
# 1. 电池/充电/USB 类温区伪装（仅 full 变体，语义同旧版）
# ============================================================
if [ "$BATT_EMUL" = "1" ]; then
  for tz in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$tz/type" 2>/dev/null) || continue
    case "$t" in
      battery|batt-pack-therm|batt2-pack-therm|usb|usb1-conn-therm|usb2-conn-therm|fast-chg-therm|top-chg-therm)
        echo $T > "$tz/emul_temp" 2>/dev/null ;;
    esac
  done
  echo "$(date): 电池/充电类温区已伪装 ${T}mC (full 变体)" >> "$LOG_FILE"
else
  echo "$(date): 电池/充电类温区保持真实温度 (safe 变体)" >> "$LOG_FILE"
fi

# ============================================================
# 2. 表面/外壳类温区 —— 启动「跟随式伪装」守护
# ============================================================
DAEMON="$MODDIR/skin_daemon.sh"
if [ -f "$DAEMON" ]; then
  chmod 755 "$DAEMON" 2>/dev/null
  # 防重复启动（模块更新后未重启又重跑 service 的情况）
  pkill -f skin_daemon.sh 2>/dev/null
  sleep 1
  setsid "$DAEMON" >/dev/null 2>&1 &
  echo "$(date): skin_daemon 已启动 (pid=$!)" >> "$LOG_FILE"
else
  echo "$(date): skin_daemon.sh 缺失 —— 表面温区不做伪装（等价 mode=off, 最安全）" >> "$LOG_FILE"
fi

# ============================================================
# 3. OPPO 智能温控服务 horae（2026-10-09: 改为默认保留运行，理由见 HORAE_OFF 注释）
# ============================================================
if [ "$HORAE_OFF" = "1" ]; then
  stop horae 2>/dev/null
  setprop persist.sys.horae.enable 0
  echo "$(date): horae 已关闭（默认，与 5.0.1 一致）" >> "$LOG_FILE"
else
  setprop persist.sys.horae.enable 1
  echo "$(date): horae 保留运行（需自行确认无副作用）" >> "$LOG_FILE"
fi

echo "$(date): ===== service done =====" >> "$LOG_FILE"
