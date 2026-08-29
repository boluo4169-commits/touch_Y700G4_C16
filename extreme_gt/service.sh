#!/system/bin/sh
# ============================================================
# Extreme GT 4.2.1 — Y700G4 (SM8750P/sun) ColorOS16 移植版 温区伪装
# 基于真机实测 (2026-08-29): 131 个 thermal_zone 中 88 个支持 emul_temp,
# 温区类型名已逐一枚举确认, 与一加原版(pm8550_gpio03_usr/batt-therm/
# board_temp/shell* 等)完全不同, 原版在本机一个都匹配不上。
#
# 原版本机失效节点已删除:
#   - /proc/shell-temp        (本机不存在)
#   - /proc/oplus-votable/*   (本机不存在)
#   - shell* 温区             (本机不存在)
# ============================================================

MODDIR=${0%/*}
T=29500          # 伪装温度 29.5C
# __BATT_EMUL__ 占位由 build.ps1 按变体注入:
#   safe(精简版)=0  电池/充电/USB 类温区保持真实温度, 充电保护完整保留
#   full(完全版)=1  连电池类温区一起伪装 29.5C
BATT_EMUL=__BATT_EMUL__

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

# 关闭 OPPO 智能温控服务 horae
# (本机实测 init.svc.horae=running 时仅写属性停不掉, 必须 stop)
stop horae 2>/dev/null
setprop persist.sys.horae.enable 0
