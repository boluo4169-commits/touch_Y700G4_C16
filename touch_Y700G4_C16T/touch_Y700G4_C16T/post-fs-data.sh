#!/system/bin/sh
# ============================================================
# 触控优化模块 - post-fs-data 阶段
# 读取 config 动态适配帧率：fps=120 / 144 / 165
# ============================================================

MODDIR=${0%/*}

# 读取配置文件
CONFIG_FILE="$MODDIR/config"
TARGET_FPS=144
if [ -f "$CONFIG_FILE" ]; then
    TARGET_FPS=$(grep -oP "(?<=fps=)[0-9]+" "$CONFIG_FILE" 2>/dev/null || echo 144)
    [ -z "$TARGET_FPS" ] && TARGET_FPS=144
fi

RESETPROP="/data/adb/ksu/bin/resetprop"
[ ! -x "$RESETPROP" ] && RESETPROP="resetprop"

LOG_FILE="$MODDIR/apply.log"
echo "$(date): touch_Y700G4_C16T v4.1 post-fs-data start (fps=${TARGET_FPS})" > "$LOG_FILE"

# === ro 属性（帧率覆写） ===
$RESETPROP ro.surface_flinger.game_default_frame_rate_override "$TARGET_FPS"

# === 游戏触控优化（框架层，ColorOS/系统会读取） ===
$RESETPROP persist.sys.game_touch_optimization 1
$RESETPROP persist.sys.oplus_game_touch_adjust 1
$RESETPROP persist.vendor.game_touch_optimization 1

# === 关闭误触防护 ===
$RESETPROP persist.sys.op_mistouch_prevention_gaming 0
$RESETPROP persist.vendor.mistouch_prevention_gaming 0

# === 关闭边缘抑制 ===
$RESETPROP persist.sys.edge_filter_gaming 0
$RESETPROP persist.sys.grip_suppression_gaming 0
$RESETPROP persist.vendor.edge_suppression 0

# === 输入延迟 ===
$RESETPROP persist.sys.input_latency_reduction 1
$RESETPROP persist.vendor.input_latency_mode 1

# === ColorOS 增强 ===
$RESETPROP persist.sys.game_mode_touch_boost 1
$RESETPROP persist.sys.oplus_game_touch_response 1

# === 优先级 ===
$RESETPROP persist.sys.touch_priority 1
$RESETPROP persist.vendor.touch_priority 1

# === 关闭SF触控定时器（减少延迟） ===
$RESETPROP ro.surface_flinger.set_touch_timer_ms 0

echo "$(date): post-fs-data done" >> "$LOG_FILE"