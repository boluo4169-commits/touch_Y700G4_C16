#!/system/bin/sh
# Extreme GT 4.2.1 Y700G4 适配版 卸载脚本
# KSU/Magisk 删除模块目录后由管理器调用，负责恢复现场：
#   1. 清除所有 emul_temp 伪温度写入（写0内核自动归一）
#   2. 删除 system.prop 写入的 persist 属性（KSU删模块不会清persist分区）

for tz in /sys/class/thermal/thermal_zone*; do
  [ -e "$tz/emul_temp" ] && echo 0 > "$tz/emul_temp" 2>/dev/null
done

resetprop --delete persist.sys.horae.enable 2>/dev/null

# horae 服务无需处理：模块卸载后无人 stop，开机自然恢复运行