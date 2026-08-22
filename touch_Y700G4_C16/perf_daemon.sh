#!/system/bin/sh
# ============================================================
# 性能自适应守护 perf_daemon.sh (v3.0)
# v2.9 修复 (针对游戏内触控冻结2~3秒):
#   移除 perf_mode()/thermal_protect() 中所有 game_mode 写入!
#   根因: 游戏内系统主动写 game_mode=2 并执行整套触控配置序列;
#   本守护切 PERF 档时强制写回 game_mode=1 => 与系统拉锯 =>
#   触控IC停在配置切换窗口 => 游戏中周期性触控完全失灵2~3秒。
#   (与 touch_daemon v1.6 结论一致, 此前漏改了本脚本)
#
# v1.1 历史:
#   分母改用 cpuinfo_max_freq 防自激振荡 / 滞回 / 温度防抖 /
#   轮询3秒 / 相对核数判据 / conf 变量生效
# ============================================================

MODDIR=$(cd "$(dirname "$0")" && pwd)
CONF="$MODDIR/perf.conf"
LOG="$MODDIR/perf.log"
PIDFILE="$MODDIR/perf.pid"

# ---- 默认参数(可被perf.conf覆盖) ----
HI_LOAD=1.0
HI_C6=2.5
LO_C6=1.5
TEMP_MAX=92000
TEMP_RESTORE=80000
TEMP_TRIGGER_STREAK=3
TEMP_RESTORE_STREAK=3
INTERVAL=3
PERF_C6=4320000
PERF_C4=3532800
ECO_C6=1300000
ECO_C4=2400000
PROTECT_C4=2400000
PROTECT_C6=2000000

[ -f "$CONF" ] && . "$CONF"

read_temp() {
    local t
    t=$(cat /sys/class/thermal/thermal_zone25/temp 2>/dev/null)
    [ -z "$t" ] && t=$(cat /sys/class/thermal/thermal_zone26/temp 2>/dev/null)
    [ -z "$t" ] && t=40000
    echo "$t"
}

read_load() {
    awk '{print $1}' /proc/loadavg 2>/dev/null
}

read_ncpu() {
    grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 8
}

read_c6_load() {
    local cur hwmax
    cur=$(cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_cur_freq 2>/dev/null)
    hwmax=$(cat /sys/devices/system/cpu/cpu6/cpufreq/cpuinfo_max_freq 2>/dev/null)
    [ -z "$cur" ] && cur=0
    [ -z "$hwmax" ] || [ "$hwmax" = "0" ] && hwmax=4320000
    awk -v c="$cur" -v m="$hwmax" 'BEGIN{printf "%.2f", c/m*4}'
}

set_freq_cluster() {
    local c hwmax
    for c in $(seq $1 $2); do
        [ -f "/sys/devices/system/cpu/cpu$c/cpufreq/scaling_max_freq" ] || continue
        hwmax=$(cat "/sys/devices/system/cpu/cpu$c/cpufreq/cpuinfo_max_freq" 2>/dev/null)
        [ -z "$hwmax" ] || [ "$hwmax" = "0" ] && hwmax=4320000
        if [ "$3" -le "$hwmax" ]; then
            echo "$3" > "/sys/devices/system/cpu/cpu$c/cpufreq/scaling_max_freq" 2>/dev/null
        fi
    done
}

perf_mode() {
    # v2.9: 不再写 game_mode! 完全交给系统管理, 防止触控配置拉锯
    set_freq_cluster 0 3 "$PERF_C4"
    set_freq_cluster 4 5 "$PERF_C4"
    set_freq_cluster 6 7 "$PERF_C6"
    echo "$(date): [PERF] 满血性能档已应用 (C6=${PERF_C6})" >> "$LOG"
}

eco_mode() {
    set_freq_cluster 0 3 "$ECO_C4"
    set_freq_cluster 4 5 "$ECO_C4"
    set_freq_cluster 6 7 "$ECO_C6"
    echo "$(date): [ECO] 省电档已应用 (C6=${ECO_C6})" >> "$LOG"
}

thermal_protect() {
    # v2.9: 同样移除 game_mode 写入
    set_freq_cluster 0 3 "$PROTECT_C4"
    set_freq_cluster 4 5 "$PROTECT_C4"
    set_freq_cluster 6 7 "$PROTECT_C6"
    echo "$(date): [THERMAL] 高温保护,已降频 (C4=${PROTECT_C4} C6=${PROTECT_C6})" >> "$LOG"
}

guard_loop() {
    echo $$ > "$PIDFILE"
    echo "$(date): perf_daemon v3.0 启动 (刷新间隔${INTERVAL}s)" > "$LOG"

    local last_mode=""
    local protected=0
    local perf_state=0
    local temp_high_streak=0
    local temp_low_streak=0

    while true; do
        local t
        t=$(read_temp)
        if [ -n "$t" ] && [ "$t" -ge 0 ] && [ "$t" -le 130000 ]; then
            if [ "$t" -ge "$TEMP_MAX" ]; then
                temp_high_streak=$((temp_high_streak + 1))
                temp_low_streak=0
                if [ "$protected" = "0" ] && [ "$temp_high_streak" -ge "$TEMP_TRIGGER_STREAK" ]; then
                    thermal_protect
                    protected=1
                    last_mode="THERMAL"
                    temp_high_streak=0
                fi
            elif [ "$t" -le "$TEMP_RESTORE" ]; then
                temp_low_streak=$((temp_low_streak + 1))
                temp_high_streak=0
                if [ "$protected" = "1" ] && [ "$temp_low_streak" -ge "$TEMP_RESTORE_STREAK" ]; then
                    protected=0
                    echo "$(date): 温度已降至 $t, 解除保护" >> "$LOG"
                    temp_low_streak=0
                    last_mode=""
                fi
            else
                temp_high_streak=0
                temp_low_streak=0
            fi
        fi

        if [ "$protected" = "0" ]; then
            local load c6load ncpu
            load=$(read_load)
            c6load=$(read_c6_load)
            ncpu=$(read_ncpu)

            local mode="ECO"
            local c6_threshold="$HI_C6"
            [ "$perf_state" = "1" ] && c6_threshold="$LO_C6"

            awk -v l="$load" -v n="$ncpu" -v hl="$HI_LOAD" 'BEGIN{exit !(l/n>hl)}' && mode="PERF"
            awk -v c="$c6load" -v hc="$c6_threshold" 'BEGIN{exit !(c>hc)}' && mode="PERF"

            if [ "$mode" != "$last_mode" ]; then
                if [ "$mode" = "PERF" ]; then
                    perf_mode
                    perf_state=1
                else
                    eco_mode
                    perf_state=0
                fi
                last_mode="$mode"
            fi
        fi

        sleep "$INTERVAL"
    done
}

case "$1" in
    start)
        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" 2>/dev/null
            sleep 1
        fi
        SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
        setsid nohup "$SELF" @guard >/dev/null 2>&1 &
        echo "perf_daemon 已启动"
        ;;
    @guard)
        guard_loop
        ;;
    stop)
        [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
        rm -f "$PIDFILE" 2>/dev/null
        eco_mode
        echo "perf_daemon 已停止"
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "运行中 PID=$(cat "$PIDFILE")"
        else
            echo "未运行"
        fi
        ;;
    *)
        echo "用法: perf_daemon.sh start|stop|status"
        ;;
esac