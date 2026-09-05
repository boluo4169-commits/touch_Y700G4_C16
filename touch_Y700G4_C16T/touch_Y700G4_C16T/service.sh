#!/system/bin/sh
# ============================================================
# 触控优化模块 - service.sh (v4.2)
# 通过 /proc 节点直控 Novatek 触控硬件
# v4.1: 重新启用守护 —— mtime 触发式低打扰方案 (touch_daemon.sh)
#   v3.3T 曾因"2s 轮询读取经 I2C 干扰 IC"停用守护;
#   v4.1 改为 stat(mtime) 轮询, 静止期零 I2C 操作,
#   仅在系统实际触碰过触控配置后才进行 I2C 读/写。
# v4.2: 修复 config 帧率解析 (toybox grep 无 -P, 原 grep -oP 恒失败)
# 读取 config 动态适配帧率：fps=120 / 144 / 165
# ============================================================

MODDIR=${0%/*}
LOG_FILE="$MODDIR/apply.log"
PID_FILE="$MODDIR/daemon.pid"

# 读取配置文件
# v4.2: toybox grep 不支持 -P, 原 grep -oP 在 Android 上恒失败 =>
# config 帧率切换功能从未生效(永远落到 144)。改用 sed 解析 + 白名单校验
CONFIG_FILE="$MODDIR/config"
TARGET_FPS=144
if [ -f "$CONFIG_FILE" ]; then
    TARGET_FPS=$(sed -n "s/^fps=//p" "$CONFIG_FILE" 2>/dev/null | head -n 1)
    case "$TARGET_FPS" in
        120|144|165) ;;
        *) TARGET_FPS=144 ;;
    esac
fi

RESETPROP="/data/adb/ksu/bin/resetprop"
[ ! -x "$RESETPROP" ] && RESETPROP="resetprop"

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done
sleep 10

echo "$(date): ========== touch_Y700G4_C16T v4.2 start (fps=${TARGET_FPS}) ==========" > "$LOG_FILE"

# ============================================================
# 统一写入函数
# ============================================================
apply_touch_tuning() {
    local tag="$1"  # "boot" 或 "recover"
    local changed=0

    if [ -f /proc/HighReportRate ]; then
        local cur=$(cat /proc/HighReportRate 2>/dev/null)
        if [ "$cur" != "High Report Rate state 1!" ]; then
            echo 1 > /proc/HighReportRate 2>/dev/null
            changed=1
        fi
    fi
    if [ -f /proc/game_mode ]; then
        # v3.2T: 开机只读不写, game_mode 完全交给系统管理
        echo "$(date): [$tag] game_mode=$(cat /proc/game_mode 2>/dev/null) (系统管理, 不干预)" >> "$LOG_FILE"
    fi
    if [ -f /proc/game_edge ]; then
        local cur=$(cat /proc/game_edge 2>/dev/null)
        if [ "$cur" != "Game edge state 1!" ]; then
            echo 1 > /proc/game_edge 2>/dev/null
            changed=1
        fi
    fi
    if [ -f /proc/report_threshold ]; then
        local cur=$(cat /proc/report_threshold 2>/dev/null)
        if [ "$cur" != "Report Threshold state 1!" ]; then
            echo 1 > /proc/report_threshold 2>/dev/null
            changed=1
        fi
    fi
    if [ "$changed" = "1" ]; then
        echo "$(date): [$tag] 恢复: HRR=$(cat /proc/HighReportRate 2>/dev/null) GM=$(cat /proc/game_mode 2>/dev/null) GE=$(cat /proc/game_edge 2>/dev/null) RT=$(cat /proc/report_threshold 2>/dev/null)" >> "$LOG_FILE"
    fi
}

# ============================================================
# 首次写入
# ============================================================
apply_touch_tuning "boot"

echo "$(date): 初始写入完成 HighReportRate=$(cat /proc/HighReportRate 2>/dev/null) game_mode=$(cat /proc/game_mode 2>/dev/null)" >> "$LOG_FILE"

# ============================================================
# 框架层 resetprop
# ============================================================
$RESETPROP ro.surface_flinger.game_default_frame_rate_override "$TARGET_FPS"
$RESETPROP ro.surface_flinger.set_touch_timer_ms 0
$RESETPROP persist.sys.game_touch_optimization 1
$RESETPROP persist.sys.oplus_game_touch_adjust 1
$RESETPROP persist.vendor.game_touch_optimization 1
$RESETPROP persist.sys.op_mistouch_prevention_gaming 0
$RESETPROP persist.vendor.mistouch_prevention_gaming 0
$RESETPROP persist.sys.edge_filter_gaming 0
$RESETPROP persist.sys.grip_suppression_gaming 0
$RESETPROP persist.vendor.edge_suppression 0
$RESETPROP persist.sys.input_latency_reduction 1
$RESETPROP persist.vendor.input_latency_mode 1
$RESETPROP persist.sys.game_mode_touch_boost 1
$RESETPROP persist.sys.oplus_game_touch_response 1
$RESETPROP persist.sys.touch_priority 1
$RESETPROP persist.vendor.touch_priority 1

# ============================================================
# mtime 触发式低打扰守护 (v4.1)
# 每 2 秒纯 stat 轮询 4 个节点 mtime (零 I2C); 系统动了配置先防抖
# 2s (隔离进游戏/退游戏/音量键面板的写入风暴, 期间零 I2C), 风暴停后:
#   读 game_mode => 进游戏等 3s 校验只写异常节点 / 非游戏放手+10s 冷却
#   游戏内 => 每 30s 兜底扫描 HRR (覆盖驱动内部重置)
# ============================================================
TOUCH_DAEMON="$MODDIR/touch_daemon.sh"
if [ -f /proc/HighReportRate ] && [ -f "$TOUCH_DAEMON" ]; then
    chmod 755 "$TOUCH_DAEMON" 2>/dev/null
    # 防重复启动 (模块更新后未重启又重跑 service 的情况)
    pkill -f touch_daemon.sh 2>/dev/null
    setsid "$TOUCH_DAEMON" >/dev/null 2>&1 &
    echo "$(date): v4.1 mtime 守护已启动 (pid=$!)" >> "$LOG_FILE"
else
    echo "$(date): 触控节点/守护脚本缺失, 守护不启动" >> "$LOG_FILE"
fi
