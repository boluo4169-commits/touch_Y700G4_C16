#!/system/bin/sh
# ============================================================
# Extreme GT Y700G4 — skin_daemon.sh (5.2.2)
# 表面/外壳温区「跟随式伪装」守护
#
# ── 为什么要有这个守护 ──
# 旧版(<=5.0.1)把表面/外壳温区恒定写成 29.5C(emul_temp=29500)。而框架给 skin
# 注册的热限频阈值是 [48,49,50,60,61,90]C —— 恒定值永远够不到任何一档, 等于把
# 温控负反馈的输入整条掐断: 重度使用后温度无上限上升, 熄屏仍持续发热。
#
# ── 5.1.2 事故修复 ──
# 5.1 的守护从"锚点温区取最大值"推导伪装值, 但**开机初期部分 TSENS 温区
# (NSP/CPUSS 等, 可能处于掉电状态)会返回 105.0C 哨兵值**, 被误当作真实温度
# 写进了 skin 温区 -> 框架判定外壳 105C -> 立即热关机。
# 修复: ①锚点可信域过滤 ②写入硬上限 ③异常归零兜底
#
# ── 5.1.4 健壮性加固 ──
# 真机日志显示: 关机瞬间出现大量**空时间戳**的 invalid 记录, 并密集触发
# 「invalid -> 归零」循环。原因是循环的外部依赖(date/sleep)在关机时不可用:
#   · $(date) 失败 -> 时间戳为空
#   · sleep 失败   -> 循环失去节流, 全速空转并反复写 88 个温区(自己制造负载)
# 加固措施:
#   1. 时间戳优先用 date, 失败退化为 /proc/uptime(纯内建 read, 不依赖外部命令)
#   2. sleep 失败 => 立即归零退出(由 trap 兜底), 绝不让循环空转
#   3. 速率看门狗: 每 RUNCHECK 轮核对实际耗时, 明显偏快即判定异常并退出
#   4. 关机检测: sys.shutdown.requested 非空则静默退出
#   5. invalid 日志节流 + 归零后退避, 避免刷屏与无谓的批量写入
#
# ── 5.2.2 关键修复 ──
# `quiet-therm` 移出伪装列表（细节见 apply_skin 上方注释）：该温区同时供给框架 skin 与
# 12 份 vendor 策略（含电池充电限流，档位从 30℃ 起、最低压到 0.5A），伪装它会把
# "硅温 − offset" 的假板温送进充电链路 → 充电被限流（真机复现：0.5A vs 真实 3A）。
#
# ── 方案: 跟随式伪装 ──
#   skin 伪装值 = 真实硅温 - skin_offset, 再夹进 [skin_min, skin_max]
#   · 平时(真实硅温 < offset+48C): 低于 48C 首档 -> 不降频, 保留游戏性能
#   · 重度(越过 offset+48C): 跨过阈值 -> 框架/thermal-engine 恢复降温
#   · 守护退出/被杀: 所有 emul_temp 归零 -> 立即恢复真实温度(安全方向)
#
# ── 可调参数 ──
#   见同目录 config (skin_mode / skin_offset / skin_min / skin_max / hard_real)
#   skin_mode=follow 正常伪装 | log 只记录不写入(干跑) | off 完全不伪装
# ============================================================

MODDIR=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="$MODDIR/skin.log"
PID_FILE="$MODDIR/skin.pid"
CONF="$MODDIR/config"

# 版本号从 module.prop 动态读取 —— 避免日志与版本号漂移
VER=$(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1)
[ -z "$VER" ] && VER="unknown"

# ---- 默认值 (mC) ----
MODE=follow
OFFSET=20000
SKIN_MIN=30000
SKIN_MAX=61000          # 写入硬上限: 绝不写出比这更高的伪装值
HARD_REAL=95000         # 锚点可信域上限(超过=哨兵值, 弃用该温区)
ANCHOR_MIN=15000        # 锚点可信域下限
INTERVAL=10             # 轮询周期
LOG_EVERY=6             # 每 6 轮(约 60s)记一次常规日志
DEADBAND=500            # 变化小于 0.5C 不重写
MAX_INVALID=3           # 连续多少轮无有效锚点 -> 归零交还内核
RUNCHECK=30             # 每多少轮做一次速率看门狗校验
RESET_BACKOFF=3         # 归零后的退避轮数(跳过若干轮)

# ---- 读取 config (摄氏度 -> 毫摄氏度) ----
read_conf() {
  [ -f "$CONF" ] || return 0
  v=$(sed -n 's/^skin_mode=//p' "$CONF" 2>/dev/null | head -n 1 | tr -d ' \r')
  case "$v" in follow|log|off) MODE="$v" ;; esac
  _c() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -n 1 | tr -cd '0-9'; }
  n=$(_c skin_offset); [ -n "$n" ] && [ "$n" -le 60 ] && OFFSET=$((n * 1000))
  n=$(_c skin_min);    [ -n "$n" ] && [ "$n" -ge 20 ] && [ "$n" -le 90 ] && SKIN_MIN=$((n * 1000))
  n=$(_c hard_real);   [ -n "$n" ] && [ "$n" -ge 60 ] && [ "$n" -le 120 ] && HARD_REAL=$((n * 1000))
  # skin_max: 夹在 [40,70]C —— 守护的硬上限, 即使配置写错也不会突破
  n=$(_c skin_max);    [ -n "$n" ] && [ "$n" -ge 40 ] && [ "$n" -le 70 ] && SKIN_MAX=$((n * 1000))
  # 一致性: skin_min 不得高于 skin_max
  [ "$SKIN_MIN" -gt "$SKIN_MAX" ] && SKIN_MIN=$SKIN_MAX
  # hard_real 不得低于写入上限
  [ "$HARD_REAL" -lt "$SKIN_MAX" ] && HARD_REAL=$((SKIN_MAX + 10000))
}
read_conf

# ---- 时间戳: date 优先, 失败退化到 /proc/uptime(纯内建 read, 不 fork) ----
ts() {
  _t=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  if [ -n "$_t" ]; then
    echo "$_t"
    return 0
  fi
  read _up _ < /proc/uptime 2>/dev/null
  [ -n "$_up" ] && echo "uptime=${_up}s" || echo "T?"
}
log() { echo "$(ts): $1" >> "$LOG_FILE" 2>/dev/null; }
c1() { echo "$(($1 / 1000)).$(($1 % 1000 / 100))"; }   # mC -> "47.5"

# ---- 秒级时钟(纯内建 read, 不依赖 external 命令); 失败返回空 ----
now_sec() {
  read _up _ < /proc/uptime 2>/dev/null || return 1
  case "$_up" in ''|*[!0-9.]*) return 1 ;; esac
  echo "${_up%.*}"
}

# ---- 关机/重启进行中? ----
shutting_down() {
  _s=$(getprop sys.shutdown.requested 2>/dev/null)
  [ -n "$_s" ] && return 0
  # getprop 不可用(关机期常见)时不足以判定, 返回"否"
  return 1
}

# ---- 采集真实硅温基准: CPU / GPU / NSP 温区取最大值, 并做可信域过滤 ----
real_max() {
  _m=0
  for tz in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$tz/type" 2>/dev/null) || continue
    case "$t" in
      cpu-*|cpuss-*|gpuss-*|nsph*) ;;
      *) continue ;;
    esac
    v=$(cat "$tz/temp" 2>/dev/null) || continue
    case "$v" in ''|*[!0-9]*) continue ;; esac
    [ "$v" -lt "$ANCHOR_MIN" ] && continue     # 过低, 不可信
    [ "$v" -gt "$HARD_REAL" ] && continue      # 哨兵值(如 105000), 弃用
    [ "$v" -gt "$_m" ] && _m=$v
  done
  echo "$_m"
}

# ── 5.2.2 关键修复：`quiet-therm` 移出伪装列表 ──
# 与 lcm-thermal 同一类错误（"被 vendor 策略依赖的温区不能伪装"），但后果更重：
# 有用户反馈 5.2.1 充电时**一晚上充不满**，换回 5.0.1 即正常。
# 真机(thermal_zone63)实测：quiet-therm 同时是
#   ① 框架 `skin` 传感器的唯一来源（阈值 48/49/50/60/61/90℃）
#   ② 12 份 vendor 策略的输入：4 份 thermal-engine_battery_*.conf + 5 份 cpu + 3 份 gpu
# 电池那 4 份用它直接决定充电电流上限，档位从 30℃ 起每 2℃ 一档：
#   30.0℃→10A(不限流)  32/34/36/38℃→8/6/4/3A  40~44℃→3A  49℃以上→0.5A
# 把"硅温 − offset"写进它会伪造出 43~55℃ 的板温 → 充电电流被压到 3A/0.5A。
# 5.0.1 恒定 29.5℃ 恰好落在最低档(30.0℃)以下，所以从不受影响。
# 另注：emul_temp 不会自己回真实值 —— 守护若被 SIGKILL 且 trap 未执行，
#       最后一次写入的值会一直留着（曾观察到 quiet-therm 卡在 61000 → 充电被钉在 0.5A）。
# 现改为**不伪装**：框架 skin 与充电链路都基于真实板温工作（闭环保留，不再伪造）。
#
# ---- 写入表面/外壳类温区 ----
#
# ⚠️ 5.2：`lcm-thermal` 已从本列表移除，**不要加回来**。
#    lcm-thermal 是 LCM(面板)温度，被 vendor thermal-engine 的背光保护直接依赖：
#      /vendor/etc/thermal-engine_common_0.conf
#        [LCD-MONITOR] sensor=lcm-thermal thresholds=55000 actions=panel0-backlight
#        (面板到 55℃ 就把背光压到 178/255 ≈ 70%，降到 53℃ 才解除)
#    5.1.x 把它纳入"跟随硅温"后，游戏高热时 fake 顶到 skin_max=61℃ 被写进 lcm-thermal，
#    **伪造了面板过热** → 触发背光压制 → 游戏时突然降频(屏幕变暗)（真机已复现：real=88.4℃ → fake=61.0℃）。
#    原版钉死 29.5℃ 虽压制了该保护，但至少不会主动误触发。
#    现改为**不伪装**，让背光保护基于真实面板温度工作（真到 55℃ 才降频(屏幕变暗)，属正当保护）。
#
# ⚠️ 5.2.2：`quiet-therm` 同样已移除，理由见文件头「5.2.2 关键修复」。
#    两个已移除的温区：lcm-thermal（面板背光）、quiet-therm（框架 skin + 充电限流 + CPU/GPU 限频）
apply_skin() {
  _val="$1"
  # 二次保险: 任何情况下都不写出超过 SKIN_MAX 的值
  [ "$_val" -gt "$SKIN_MAX" ] && _val=$SKIN_MAX
  [ "$_val" -lt "$SKIN_MIN" ] && _val=$SKIN_MIN
  for tz in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$tz/type" 2>/dev/null) || continue
    case "$t" in
      ap-therm|front_temp|back_temp|user_temp|user_front_temp|user_back_temp|\
      flash-led-ntc|rear-cam-ntc|fcam-ntc|\
      wlan-therm|xo-therm|ufs-therm|ddr)
        echo "$_val" > "$tz/emul_temp" 2>/dev/null ;;
    esac
  done
}

# ---- 归零: 恢复到真实温度(退出/卸载/异常兜底, 安全方向) ----
reset_skin() {
  for tz in /sys/class/thermal/thermal_zone*; do
    [ -e "$tz/emul_temp" ] && echo 0 > "$tz/emul_temp" 2>/dev/null
  done
}

trap 'reset_skin; rm -f "$PID_FILE"; exit 0' TERM INT HUP EXIT
echo $$ > "$PID_FILE"

log "[$VER] skin 守护启动 mode=${MODE} offset=$(c1 $OFFSET)C range=$(c1 $SKIN_MIN)~$(c1 $SKIN_MAX)C anchorValid=$(c1 $ANCHOR_MIN)~$(c1 $HARD_REAL)C interval=${INTERVAL}s"

# ---- off 模式: 直接归零后退出, 完全恢复原厂温控反馈 ----
if [ "$MODE" = "off" ]; then
  reset_skin
  log "[$VER] mode=off, 已全部归零并退出"
  exit 0
fi

# ---- 等开机完成后再开始(避免刚开机时温区未就绪/返回哨兵值) ----
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3 2>/dev/null || { log "[exit] 等待开机期间 sleep 不可用, 归零后退出"; exit 0; }
done
sleep 10 2>/dev/null || { log "[exit] 开机收敛等待期间 sleep 不可用, 归零后退出"; exit 0; }
log "[$VER] 开机完成, 进入 ${MODE} 循环"

LAST=-1
INVALID=0
i=0
SKIP=0
t0=$(now_sec)

while true; do
  # ---- 5.1.4: sleep 失败即退出, 绝不让循环空转 ----
  if ! sleep "$INTERVAL" 2>/dev/null; then
    log "[exit] sleep 不可用(疑似关机或运行环境异常), 归零后退出"
    exit 0
  fi
  i=$((i + 1))

  # ---- 5.1.4: 关机检测 ----
  if shutting_down; then
    log "[exit] 检测到关机/重启请求, 归零后退出"
    exit 0
  fi

  # ---- 5.1.4: 速率看门狗(防止 sleep 名义成功但未真正等待) ----
  if [ $((i % RUNCHECK)) -eq 0 ]; then
    t1=$(now_sec)
    if [ -n "$t0" ] && [ -n "$t1" ]; then
      elapsed=$((t1 - t0))
      expect=$((RUNCHECK * INTERVAL))
      if [ "$elapsed" -lt $((expect / 2)) ]; then
        log "[exit] 循环速率异常(实测 ${elapsed}s < 预期 ${expect}s), 判定为空转, 归零后退出"
        exit 0
      fi
      t0=$t1
    fi
  fi

  # ---- 归零后的退避(避免异常期反复批量写温区) ----
  if [ "$SKIP" -gt 0 ]; then
    SKIP=$((SKIP - 1))
    continue
  fi

  real=$(real_max)

  # ---- 无可信锚点: 节流记录, 连续过多则归零并退避 ----
  case "$real" in ''|0)
    INVALID=$((INVALID + 1))
    [ "$INVALID" -eq 1 ] && log "[invalid] 锚点全部不可信(哨兵值已过滤), 本轮不写入"
    if [ "$INVALID" -ge "$MAX_INVALID" ]; then
      reset_skin
      LAST=-1
      INVALID=0
      SKIP=$RESET_BACKOFF
      log "[safe] 连续 ${MAX_INVALID} 轮无可信锚点 -> 已归零并退避 ${RESET_BACKOFF} 轮, 温控权限交还内核"
    fi
    continue ;;
  esac
  INVALID=0

  # ---- 计算伪装值 ----
  fake=$((real - OFFSET))
  [ "$fake" -lt "$SKIN_MIN" ] && fake=$SKIN_MIN
  [ "$fake" -gt "$SKIN_MAX" ] && fake=$SKIN_MAX

  # ---- 干跑模式: 只记录, 不写入 ----
  if [ "$MODE" = "log" ]; then
    [ "$((i % LOG_EVERY))" -eq 0 ] && log "[dry-run] real=$(c1 $real)C -> would-fake=$(c1 $fake)C"
    continue
  fi

  # ---- 变化小于 DEADBAND 不重写 ----
  if [ "$LAST" -ge 0 ]; then
    d=$((fake - LAST)); [ "$d" -lt 0 ] && d=$((0 - d))
    [ "$d" -lt "$DEADBAND" ] && { [ "$((i % LOG_EVERY))" -eq 0 ] && log "[follow] real=$(c1 $real)C fake=$(c1 $fake)C (unchanged)"; continue; }
  fi

  apply_skin "$fake"
  LAST=$fake
  log "[follow] real=$(c1 $real)C -> fake=$(c1 $fake)C"
done
