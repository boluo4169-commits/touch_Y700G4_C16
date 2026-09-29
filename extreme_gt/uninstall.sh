#!/system/bin/sh
# ============================================================
# Extreme GT Y700G4 卸载脚本 (5.1)
# 1. 停止跟随式伪装守护, 并把所有 emul_temp 归零(恢复真实温度)
# 2. 删除 system.prop 写入的 persist 属性 (KSU 删模块不会清 persist 分区)
# 3. horae 无需处理: 卸载后无人干预, 开机自然恢复运行
# 4. bind mount 随重启自动解除, 温控 XML 原版无损还原
# ============================================================

MODDIR=${0%/*}

# ---- 1. 停守护 (先停, 避免它在我们归零后又写回) ----
[ -f "$MODDIR/skin.pid" ] && kill "$(cat "$MODDIR/skin.pid")" 2>/dev/null
for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
  case "$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')" in
    *skin_daemon.sh*) kill -9 "$pid" 2>/dev/null ;;
  esac
done
rm -f "$MODDIR/skin.pid" 2>/dev/null

# ---- 2. 全部温区 emul_temp 归零 (写 0 内核自动归一为真实温度) ----
for tz in /sys/class/thermal/thermal_zone*; do
  [ -e "$tz/emul_temp" ] && echo 0 > "$tz/emul_temp" 2>/dev/null
done

# ---- 3. 清理 persist 属性 ----
resetprop --delete persist.sys.horae.enable 2>/dev/null
resetprop --delete persist.sys.environment.temp 2>/dev/null
resetprop --delete persist.sys.oplus.wifi.sla.game_high_temperature 2>/dev/null
