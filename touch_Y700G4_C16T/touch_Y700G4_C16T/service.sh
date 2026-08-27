#!/system/bin/sh
# ============================================================
# 触控优化模块 - service.sh (v2.7)
# 通过 /proc 节点直控 Novatek 触控硬件
# 包含亮屏自动恢复守护，防止熄屏后状态丢失
# 读取 config 动态适配帧率：fps=120 / 144 / 165
# ============================================================

MODDIR=${0%/*}
LOG_FILE="$MODDIR/apply.log"
PID_FILE="$MODDIR/daemon.pid"

# 读取配置文件
CONFIG_FILE="$MODDIR/config"
TARGET_FPS=144
if [ -f "$CONFIG_FILE" ]; then
    TARGET_FPS=$(grep -oP "(?<=fps=)[0-9]+" "$CONFIG_FILE" 2>/dev/null || echo 144)
    [ -z "$TARGET_FPS" ] && TARGET_FPS=144
fi

RESETPROP="/data/adb/ksu/bin/resetprop"
[ ! -x "$RESETPROP" ] && RESETPROP="resetprop"

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done
sleep 10

echo "$(date): ========== touch_Y700G4_C16T v3.2T start (fps=${TARGET_FPS}) ==========" > "$LOG_FILE"

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
# 后台守护：每2秒检测，发现被重置则立刻恢复
# 独立脚本 touch_daemon.sh, 用setsid完全脱离本会话常驻
# 防止熄屏唤醒后 & 系统事件导致的节点复位
# ============================================================
TOUCH_DAEMON="$MODDIR/touch_daemon.sh"
chmod 755 "$TOUCH_DAEMON" 2>/dev/null
# v3.3T: 守护已停用(实测轮询读取干扰IC致游戏内触控冻结)
echo "$(date): 守护已停用(write-once模式) 跳过启动" >> "$LOG_FILE"
