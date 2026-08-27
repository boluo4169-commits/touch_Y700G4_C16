#!/system/bin/sh
# ============================================================
# 触控优化模块 uninstall.sh
# KSU Manager 卸载时自动执行: 清理模块残留, 恢复原版
# 实测结论:
#   - ro.* 属性/CPU频率/触控节点/守护进程 => 重启自动恢复, 无需处理
#   - persist.* 属性 => resetprop覆写会持久化污染, 必须显式删除
#   因此本脚本核心是"删除被覆写的persist属性" + "卸载当下立即复位"
# ============================================================

MODDIR=${0%/*}
RP=/data/adb/ksu/bin/resetprop
[ ! -x "$RP" ] && RP=resetprop

echo "$(date): ===== 触控优化模块 卸载清理 ====="

# ============================================================
# 1. 停止后台守护进程 (卸载当下立即停, 避免卸载后仍在运行)
# ============================================================
[ -f "$MODDIR/daemon.pid" ] && kill "$(cat "$MODDIR/daemon.pid")" 2>/dev/null
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
    case "$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')" in
        *touch_daemon.sh*) kill -9 "$pid" 2>/dev/null ;;
    esac
done
echo "已停止后台守护"

# ============================================================
# 2. 删除被模块覆写的 persist.* 属性 (真残留, 需显式清理)
#    仅处理持久属性; ro.* 重启由boot重新加载, 无需清理
# ============================================================
for p in \
    persist.sys.game_touch_optimization \
    persist.sys.oplus_game_touch_adjust \
    persist.vendor.game_touch_optimization \
    persist.sys.op_mistouch_prevention_gaming \
    persist.vendor.mistouch_prevention_gaming \
    persist.sys.edge_filter_gaming \
    persist.sys.grip_suppression_gaming \
    persist.vendor.edge_suppression \
    persist.sys.input_latency_reduction \
    persist.vendor.input_latency_mode \
    persist.sys.game_mode_touch_boost \
    persist.sys.oplus_game_touch_response \
    persist.sys.touch_priority \
    persist.vendor.touch_priority ; do
    $RP -d -p "$p" 2>/dev/null
done
echo "已删除被覆写的 persist 属性"

# ============================================================
# 3. 卸载当下复位触控节点 (不等重启)
# ============================================================
[ -f /proc/HighReportRate ] && echo 0 > /proc/HighReportRate 2>/dev/null
[ -f /proc/game_mode ] && echo 0 > /proc/game_mode 2>/dev/null
[ -f /proc/game_edge ] && echo 0 > /proc/game_edge 2>/dev/null
[ -f /proc/report_threshold ] && echo 0 > /proc/report_threshold 2>/dev/null
[ -f /proc/gesture_control ] && echo 0 > /proc/gesture_control 2>/dev/null
echo "触控节点已复位"

# ============================================================
# 4. 清除运行时文件 (log/pid)  [模块文件本身由KSU删除]
# ============================================================
rm -f "$MODDIR/apply.log" 2>/dev/null
rm -f "$MODDIR/daemon.pid" 2>/dev/null
echo "运行时文件已清除"

echo "$(date): ===== 卸载清理完成, 已恢复原版 ====="