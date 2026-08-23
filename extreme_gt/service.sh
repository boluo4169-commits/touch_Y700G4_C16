#!/system/bin/sh
# ============================================================
# Extreme GT 4.2.1 本机适配版 (联想Y700 G4 / SM8750P sun平台)
# 基于真机实测: 2026-08-23 遍历88个thermal zone确认类型命名
# 与原版差异:
#   1. zone匹配改为本机实际类型名(battery/usb/ap-therm等)
#   2. 新增 stop horae (实测 init.svc.horae=running, 原版只写属性停不掉)
#   3. 删除本机不存在的 /proc/shell-temp 和 oplus-votable 段
# ============================================================

MODDIR=${0%/*}
T=29500        # 伪装温度 29.5C
BATT_EMUL=0   # 0=保留电池真实温度(安全兜底)

for tz in /sys/class/thermal/thermal_zone*; do
  t=$(cat $tz/type 2>/dev/null) || continue
  case "$t" in
    # ---- 表面/外壳类 NTC (实机: ap-therm/front_temp/back_temp/user_temp系列) ----
    ap-therm|front_temp|back_temp|user_temp|user_front_temp|user_back_temp|quiet-therm|lcm-thermal|flash-led-ntc|rear-cam-ntc|fcam-ntc)
      echo $T > $tz/emul_temp 2>/dev/null ;;
    # ---- 无线/存储/内存/XO ----
    wlan-therm|xo-therm|ufs-therm|ddr)
      echo $T > $tz/emul_temp 2>/dev/null ;;
    # ---- 电池/充电/USB 类 (实机: battery/batt-pack-therm/usb/fast-chg-therm等) ----
    battery|batt-pack-therm|batt2-pack-therm|usb|usb1-conn-therm|usb2-conn-therm|fast-chg-therm|top-chg-therm)
      [ "$BATT_EMUL" = "1" ] && echo $T > $tz/emul_temp 2>/dev/null ;;
  esac
done

# 关闭 OPPO 智能温控服务 horae (实测本机 running)
stop horae 2>/dev/null
setprop persist.sys.horae.enable 0
