#!/system/bin/sh
# ============================================================
# 触控守护 touch_daemon.sh (v3.3T)
# 每2秒哨兵检测: 游戏内(gm=2)只读 HRR 一个节点, 异常才恢复
#
# v3.2T 修复 (同步主模块 v3.0, 针对游戏内触控冻结2~3秒):
#   恢复写入从"固定三节点全量重写"改为"只写实际异常的节点"。
#   原逻辑即使只有 HRR 掉档, 也会同时重写 game_edge + report_threshold,
#   多余的 I2C 写入会扩大触控IC配置切换窗口 => 加重卡触感。
#   现在哪个节点异常就只恢复哪个, 最小化对IC的打扰。
#   (game_mode 依旧完全不碰, 由系统独占管理)
#
# v1.4 修复: 检测间隔 5秒→1秒 (实测日志: 游戏期间节点每1~10分钟被重置,
# 40分钟内重置8次, 5秒检测窗口内滑动必然断触; 1秒轮询将掉档窗口压到最短)
# v1.3 修复 (针对团战实测"左下移动键断触卡顿"):
#   - 移除 dumpsys display 屏幕检测: 每5秒binder重调用, 游戏场景下
#     与system_server竞争输入事件处理 => 周期性微卡顿/断触感
#   - 恢复写入改为单次+读回验证(重试≤2次, 无sleep):
#     原v1.2"连续2次间隔1秒"让IC停留在配置切换窗口更久, 放大断触
# v1.2 修复 (针对暗区突围实测断触):
#   - 检测间隔 30秒→5秒: 实测游戏期间节点被系统/游戏重置6次,
#     30秒窗口内触控采样率掉档 => 开镜/探头连点断触
# v1.1 修复: 原版只检查 HighReportRate 一个节点,
# 若 game_mode/game_edge/report_threshold 被重置而 HRR 未变,
# 守护不会恢复 => 现改为检查全部4个节点, 任一异常则全部恢复
# ============================================================

MODDIR=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="$MODDIR/apply.log"
PID_FILE="$MODDIR/daemon.pid"

echo $$ > "$PID_FILE"

while true; do
    sleep 2
    # v2.7: 分场景工作! 先读 game_mode 判断当前场景:
    #   游戏内(gm=2): HRR被重置则恢复 => 防游戏内断触
    #   非游戏(gm=0, 含来电/滑出游戏): 完全放手!
    #     根因(今日实测): 来电/滑出游戏时系统执行"退出游戏配置"序列
    #     (写HRR0+gm0+support_pen1+发I2C命令+切帧率), 守护在序列过程中
    #     插入写HRR=1, 打断配置 => IC停在半配置状态, 触控完全失效,
    #     直到重新进游戏(系统重新完整配置)才恢复。放手后不再打断。
    # v1.7: 检测间隔 5s→2s (来电场景: 系统会关HRR写0+频繁切帧率触发驱动重置,
    #   实测来电时段节点反复掉, 5秒窗口内屏幕完全失控; 2秒单节点轮询打扰极小)
    # v1.6: 移除game_mode写入! dmesg铁证: 系统在游戏/帧率切换时主动写
    #   game_mode=2(moto_apk_state2)并执行整套触控配置, 我们强制写回1反而与
    #   系统拉锯, 每次切换都扰动触控IC => 断触元凶。game_mode完全交给系统管理。
    # v1.5: 哨兵模式, 减少对IC的打扰(1秒轮询实测诱发更频繁重置)

    GM=$(cat /proc/game_mode 2>/dev/null)

    # v3.3: exit-game window (gm 2->other): system runs exit sequence,
    # reading HRR via I2C interrupts IC config switch => touch dead 2~3s.
    # After leaving game scene, cooldown 10s without touching any node.
    if [ "$PREV_GM" = "2" ] && [ "$GM" != "2" ]; then
        echo "$(date): [cooldown] exit game scene, cooldown 10s" >> "$LOG_FILE"
        COOLDOWN=$(( $(date +%s) + 10 ))
    fi
    PREV_GM="$GM"
    NOW_TS=$(date +%s)
    if [ -n "$COOLDOWN" ] && [ "$NOW_TS" -lt "$COOLDOWN" ]; then
        continue
    fi

    if [ "$GM" = "2" ]; then
        # ===== 游戏内: 哨兵模式防断触 =====
        # 哨兵检测: 只读 HRR 一个核心节点
        HRR=$(cat /proc/HighReportRate 2>/dev/null)

        if [ "$HRR" = "High Report Rate state 1!" ]; then
            continue  # 哨兵正常, 不打扰IC, 直接下一轮
        fi

        # 哨兵异常 -> 全量检查
        GE=$(cat /proc/game_edge 2>/dev/null)
        RT=$(cat /proc/report_threshold 2>/dev/null)

        # v1.1: 任一节点异常即触发恢复
        NEED_RECOVER=0
        [ "$HRR" != "High Report Rate state 1!" ] && NEED_RECOVER=1
        [ "$GE" != "Game edge state 1!" ] && NEED_RECOVER=1
        [ "$RT" != "Report Threshold state 1!" ] && NEED_RECOVER=1

        if [ "$NEED_RECOVER" = "1" ]; then
            # v1.3: 单次写入+读回验证(重试≤2次, 无sleep)
            # 原v1.2"连续2次间隔1秒"让IC停留在配置切换窗口更久, 放大断触窗口
            retry=0
            while [ $retry -lt 3 ]; do
                # v3.2T: 哪个节点异常就只恢复哪个, 最小化 I2C 写入
                [ "$HRR" != "High Report Rate state 1!" ] && echo 1 > /proc/HighReportRate 2>/dev/null
                [ "$GE" != "Game edge state 1!" ] && echo 1 > /proc/game_edge 2>/dev/null
                [ "$RT" != "Report Threshold state 1!" ] && echo 1 > /proc/report_threshold 2>/dev/null
                HRR=$(cat /proc/HighReportRate 2>/dev/null)
                GE=$(cat /proc/game_edge 2>/dev/null)
                RT=$(cat /proc/report_threshold 2>/dev/null)
                [ "$HRR" = "High Report Rate state 1!" ] && [ "$GE" = "Game edge state 1!" ] && [ "$RT" = "Report Threshold state 1!" ] && break
                retry=$((retry + 1))
            done
            echo "$(date): [recover] 游戏内节点被重置，已恢复 HRR=$HRR GE=$GE RT=$RT (重试${retry}次)" >> "$LOG_FILE"
        fi
    fi
    # ===== 非游戏场景(来电/滑出游戏/桌面): 完全放手 =====
    # 系统"退出游戏配置"序列完整执行, IC状态一致, 触控正常
done