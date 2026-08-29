#!/system/bin/sh
# ============================================================
# touch_daemon.sh v4.1 — mtime 触发式低打扰守护
#
# 设计原则 (继承 v1.x~v3.3T 全部实测结论, 见仓库旧版注释):
#   1. 对 IC 的每次 I2C 读/写都是打扰, 静止期必须零 I2C 操作
#      (v3.3T 实测: 2s 轮询"读"也干扰 IC 致游戏内触控冻结 => 守护整体停用)
#   2. /proc 节点不支持 inotify, 但实测"写"节点会更新 mtime
#      (本机 HRR 节点 mtime 随系统写入变化), 而 stat() 是纯 VFS
#      操作, 不触发驱动 read/write 回调 => 用 mtime 轮询作触发信号
#   3. game_mode 永远只读不写 (v1.6: 与系统拉锯是断触元凶)
#   4. 非游戏场景完全放手 (v2.7: 插入写会打断系统退出配置序列,
#      导致触控全失效 2~3 秒)
#   5. 恢复只写实际异常的节点 (v3.2T: 最小化 I2C 写入)
#
# 工作流:
#   每 WATCH_INTERVAL 秒 stat 4 个节点的 mtime (零 I2C)
#   ├─ mtime 无变化 => 本轮结束, 零打扰
#   ├─ mtime 变化 => 先防抖 DEBOUNCE 秒 (等系统写入风暴结束,
#   │   期间零 I2C —— 音量键面板/退出游戏的配置序列都在这里被隔离)
#   ├─ 防抖到期 => 读一次 game_mode 判断场景:
#   │   ├─ gm=2 (进游戏/游戏内配置切换): 再等 ENTER_SETTLE 秒然后读
#   │   │   三节点, 只写异常的
#   │   └─ gm!=2 (退出游戏/非游戏): 完全放手, 冷却 EXIT_COOLDOWN 秒
#   └─ 游戏内 (gm=2) 期间: 每 SCAN_INTERVAL 秒兜底扫描一次 HRR
#      (覆盖"驱动内部重置不走 proc 写、mtime 不变"的情况)
# ============================================================

MODDIR=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="$MODDIR/apply.log"
PID_FILE="$MODDIR/daemon.pid"

WATCH_INTERVAL=2      # mtime 轮询周期(纯 stat, 零 I2C)
DEBOUNCE=2            # mtime 变化后的防抖: 等系统配置写入风暴结束再做 I2C 读
ENTER_SETTLE=3        # 判定进游戏后再等系统配置收敛的秒数
EXIT_COOLDOWN=10      # 退出游戏后冷却秒数 (v3.3 实测值)
SCAN_INTERVAL=30      # 游戏内兜底扫描周期(单节点 HRR 读)

echo $$ > "$PID_FILE"

HRR_OK="High Report Rate state 1!"
GE_OK="Game edge state 1!"
RT_OK="Report Threshold state 1!"

mtime_of() { stat -c %Y "$1" 2>/dev/null; }
log() { echo "$(date): $1" >> "$LOG_FILE"; }

# ---- 基线 mtime (service.sh 刚写入完毕, 取当前值) ----
M_HRR=$(mtime_of /proc/HighReportRate)
M_GM=$(mtime_of /proc/game_mode)
M_GE=$(mtime_of /proc/game_edge)
M_RT=$(mtime_of /proc/report_threshold)

GM=""              # 缓存场景值, 仅防抖到期后才读一次
PENDING=0          # 冷却期内发生过 mtime 变化, 冷却结束后补判一次场景
COOLDOWN_UNTIL=0
DEBOUNCE_AT=0      # >0 = mtime 变化后的防抖到期时间点
VERIFY_AT=0        # >0 = 挂起中的"进游戏校验"时间点
LAST_SCAN=0

log "[v4.1] mtime 守护启动 interval=${WATCH_INTERVAL}s debounce=${DEBOUNCE}s settle=${ENTER_SETTLE}s cooldown=${EXIT_COOLDOWN}s scan=${SCAN_INTERVAL}s"

while true; do
    sleep "$WATCH_INTERVAL"
    NOW=$(date +%s)

    # ---- 1. mtime 轮询 (零 I2C) ----
    CHANGED=0
    T=$(mtime_of /proc/HighReportRate);   [ "$T" != "$M_HRR" ] && { M_HRR=$T; CHANGED=1; }
    T=$(mtime_of /proc/game_mode);        [ "$T" != "$M_GM" ]  && { M_GM=$T;  CHANGED=1; }
    T=$(mtime_of /proc/game_edge);        [ "$T" != "$M_GE" ]  && { M_GE=$T;  CHANGED=1; }
    T=$(mtime_of /proc/report_threshold); [ "$T" != "$M_RT" ]  && { M_RT=$T;  CHANGED=1; }

    if [ "$CHANGED" = "1" ]; then
        if [ "$NOW" -ge "$COOLDOWN_UNTIL" ]; then
            # 防抖: 系统可能正在跑配置序列(进游戏/退游戏/音量键面板),
            # 等写入风暴结束, 期间零 I2C。风暴持续则不断顺延。
            DEBOUNCE_AT=$(( NOW + DEBOUNCE ))
            VERIFY_AT=0
        else
            # 冷却期内系统仍在写: 记下来, 冷却结束后补判
            PENDING=1
        fi
    fi

    # ---- 2. 冷却结束后的待定补判 ----
    if [ "$PENDING" = "1" ] && [ "$NOW" -ge "$COOLDOWN_UNTIL" ]; then
        PENDING=0
        DEBOUNCE_AT=$(( NOW + DEBOUNCE ))
    fi

    # ---- 3. 防抖到期: 读一次场景值 (整个序列中唯一的 I2C 读) ----
    if [ "$DEBOUNCE_AT" -gt 0 ] && [ "$NOW" -ge "$DEBOUNCE_AT" ]; then
        DEBOUNCE_AT=0
        GM=$(cat /proc/game_mode 2>/dev/null)
        if [ "$GM" = "2" ]; then
            # 进游戏/游戏内配置切换: 再等系统配置收敛, 然后校验
            VERIFY_AT=$(( NOW + ENTER_SETTLE ))
            LAST_SCAN=$VERIFY_AT
        else
            # 非游戏/退出游戏: 完全放手, 只冷却
            COOLDOWN_UNTIL=$(( NOW + EXIT_COOLDOWN ))
            VERIFY_AT=0
            log "[scene] gm=$GM 非游戏场景, 放手中 (cooldown ${EXIT_COOLDOWN}s)"
        fi
    fi

    # ---- 2. 挂起的进游戏校验 (只写异常节点, v3.2T 规则) ----
    if [ "$VERIFY_AT" -gt 0 ] && [ "$NOW" -ge "$VERIFY_AT" ]; then
        VERIFY_AT=0
        HRR=$(cat /proc/HighReportRate 2>/dev/null)
        GE=$(cat /proc/game_edge 2>/dev/null)
        RT=$(cat /proc/report_threshold 2>/dev/null)
        if [ "$HRR" != "$HRR_OK" ] || [ "$GE" != "$GE_OK" ] || [ "$RT" != "$RT_OK" ]; then
            [ "$HRR" != "$HRR_OK" ] && echo 1 > /proc/HighReportRate 2>/dev/null
            [ "$GE"  != "$GE_OK"  ] && echo 1 > /proc/game_edge 2>/dev/null
            [ "$RT"  != "$RT_OK"  ] && echo 1 > /proc/report_threshold 2>/dev/null
            # 自己写完要刷新基线 mtime, 避免下轮误判为"系统又动了"
            M_HRR=$(mtime_of /proc/HighReportRate)
            M_GE=$(mtime_of /proc/game_edge)
            M_RT=$(mtime_of /proc/report_threshold)
            log "[verify] 进游戏校验: 异常节点已恢复 HRR=$(cat /proc/HighReportRate 2>/dev/null) GE=$(cat /proc/game_edge 2>/dev/null) RT=$(cat /proc/report_threshold 2>/dev/null)"
        fi
        continue
    fi

    # ---- 3. 游戏内兜底扫描 (覆盖驱动内部重置, mtime 不变的情况) ----
    if [ "$GM" = "2" ] && [ "$NOW" -ge "$COOLDOWN_UNTIL" ]; then
        if [ $(( NOW - LAST_SCAN )) -ge "$SCAN_INTERVAL" ]; then
            LAST_SCAN=$NOW
            HRR=$(cat /proc/HighReportRate 2>/dev/null)
            if [ "$HRR" != "$HRR_OK" ]; then
                GE=$(cat /proc/game_edge 2>/dev/null)
                RT=$(cat /proc/report_threshold 2>/dev/null)
                [ "$GE" != "$GE_OK" ] && echo 1 > /proc/game_edge 2>/dev/null
                [ "$RT" != "$RT_OK" ] && echo 1 > /proc/report_threshold 2>/dev/null
                echo 1 > /proc/HighReportRate 2>/dev/null
                M_HRR=$(mtime_of /proc/HighReportRate)
                M_GE=$(mtime_of /proc/game_edge)
                M_RT=$(mtime_of /proc/report_threshold)
                log "[scan] 游戏内 HRR 掉档已恢复 HRR=$(cat /proc/HighReportRate 2>/dev/null) GE=$(cat /proc/game_edge 2>/dev/null) RT=$(cat /proc/report_threshold 2>/dev/null)"
            fi
        fi
    fi
done
