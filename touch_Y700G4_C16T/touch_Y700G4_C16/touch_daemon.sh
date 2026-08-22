#!/system/bin/sh
# ============================================================
# 触控守护 touch_daemon.sh (v3.0)
# 每2秒哨兵检测: 游戏内(gm=2)只读 HRR 一个节点, 异常才恢复
#
# v2.9 修复 (针对游戏内触控冻结2~3秒):
#   恢复写入从"固定三节点全量重写"改为"只写实际异常的节点"。
#   原逻辑即使只有 HRR 掉档, 也会同时重写 game_edge + report_threshold,
#   多余的 I2C 写入会扩大触控IC配置切换窗口 => 加重卡触感。
#   现在哪个节点异常就只恢复哪个, 最小化对IC的打扰。
#   (game_mode 依旧完全不碰, 由系统独占管理)
# ============================================================

MODDIR=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="$MODDIR/apply.log"
PID_FILE="$MODDIR/daemon.pid"

echo $$ > "$PID_FILE"

HRR_OK="High Report Rate state 1!"
GE_OK="Game edge state 1!"
RT_OK="Report Threshold state 1!"

while true; do
    sleep 2

    GM=$(cat /proc/game_mode 2>/dev/null)

    if [ "$GM" = "2" ]; then
        # ===== 游戏内: 哨兵模式 =====
        HRR=$(cat /proc/HighReportRate 2>/dev/null)

        if [ "$HRR" = "$HRR_OK" ]; then
            continue
        fi

        # 哨兵异常 -> 全量读取, 只恢复实际异常的节点
        GE=$(cat /proc/game_edge 2>/dev/null)
        RT=$(cat /proc/report_threshold 2>/dev/null)

        retry=0
        while [ $retry -lt 3 ]; do
            [ "$HRR" != "$HRR_OK" ] && echo 1 > /proc/HighReportRate 2>/dev/null
            [ "$GE" != "$GE_OK" ] && echo 1 > /proc/game_edge 2>/dev/null
            [ "$RT" != "$RT_OK" ] && echo 1 > /proc/report_threshold 2>/dev/null

            # 读回验证
            HRR=$(cat /proc/HighReportRate 2>/dev/null)
            GE=$(cat /proc/game_edge 2>/dev/null)
            RT=$(cat /proc/report_threshold 2>/dev/null)

            [ "$HRR" = "$HRR_OK" ] && [ "$GE" = "$GE_OK" ] && [ "$RT" = "$RT_OK" ] && break
            retry=$((retry + 1))
        done
        echo "$(date): [recover] 游戏内节点被重置，已按需恢复 HRR=$HRR GE=$GE RT=$RT (重试${retry}次)" >> "$LOG_FILE"
    fi
    # 非游戏场景: 完全放手, 系统"退出游戏配置"序列完整执行
done