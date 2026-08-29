SKIPUNZIP=0

# __VARIANT__ 占位由 build.ps1 按变体注入: safe(精简版) / full(完全版)
#   safe: 完全不碰电量链路 —— 跳过 devices_config.json 电池温度区间放宽、
#         sys_high_temp_protect 充电高温保护补丁, 电池类温区不伪装(service.sh)
#   full: 全部补丁 + 电池类温区伪装
VARIANT=__VARIANT__

# ============================================================
# Extreme GT 4.2.1 — 联想拯救者 Y700 四代 完全适配版
# 目标机型: Y700G4 (SM8750P / sun 平台) 刷 ColorOS 16 移植版
#
# 与原版(适配 OPPO/一加 机型)的差异:
#   1. 删除 MTK d1x00 平台死代码与载荷 (本机为高通 sun)
#   2. 温区伪装列表改为 Y700G4 真机 88 温区实测结果 (见 service.sh)
#   3. 删除原版 updateJson 云端通道 (指向通用 OPPO 包,
#      会误导 KSU Manager 提示刷入非适配件)
#   4. thermallevel_to_fps.xml 生成的文件在 KSU 下
#      /system/vendor(符号链接)自动 overlay 不生效,
#      由 post-fs-data.sh 显式 bind mount (已加入 vendor 目录)
#   5. 原版安装期 setprop 的两个 persist 属性移入 system.prop,
#      避免只写一次、未纳入模块管理
# ============================================================

SRC=$MODPATH
module=$MODPATH

dirs="/odm /my_product /my_stock /vendor /product /system"

xml_override() {
  mkdir -p $(dirname $module$1)
  overrides="$2"

  for file in $(find $dirs -name "$1")
  do
    mkdir -p $(dirname $module$file)
    rows=$(cat $file)
    for override in $overrides; do
      key=$(echo $override | cut -f1 -d '=')
      value=$(echo $override | cut -f2 -d '=')
      rows=$(echo "$rows" | sed "s/<$key>.*</<$key>$value</")
    done
    echo "$rows" > $module$file
  done
}

# sys_thermal_control_config*.xml — 温控总开关: 关特征开关, 等级项置 -1
boolValues="feature_enable_item feature_safety_test_enable_item aging_thermal_control_enable_item"
intValues="aging_cpu_level_item high_temp_safety_level_item game_high_perf_mode_item normal_mode_item ota_mode_item racing_mode_item"
for file in $(find $dirs -name "sys_thermal_control_config*.xml")
do
  mkdir -p $(dirname $module$file)
  rows=$(cat $file | grep -v -E '(<gear_config|cpu=|fps=|<scene_|</scene_|<category_|</category_|<subitem|<level|\.)')

  for key in $boolValues; do
    rows=$(echo "$rows" | sed "s/<$key.*\/>/<$key booleanVal=\"false\" \/>/")
  done

  for key in $intValues; do
    rows=$(echo "$rows" | sed "s/<$key.*\/>/<$key intVal=\"-1\" \/>/")
  done

  echo "$rows" | tr -s '\n' > $module$file
done

# sys_thermal_config.xml — 关闭热服务特征
xml_override 'sys_thermal_config.xml' "isOpen=0
more_heat_threshold=550
heat_threshold=530
less_heat_threshold=500
preheat_threshold=480
preheat_dex_oat_threshold=460
thermal_battery_temp=0
is_feature_on=0
is_upload_log=0
is_upload_errlog=0"

# sys_high_temp_protect*.xml — 关闭高温保护 (电量链路, 仅 full 变体)
if [ "$VARIANT" = "full" ]; then
xml_override 'sys_high_temp_protect*xml' "isOpen=0
HighTemperatureProtectSwitch=false
HighTemperatureShutdownSwitch=false
HighTemperatureFirstStepSwitch=false
HighTemperatureProtectFirstStepIn=550
HighTemperatureProtectFirstStepOut=530
HighTemperatureProtectThresholdIn=570
HighTemperatureProtectThresholdOut=550
HighTemperatureProtectShutDown=750
MediumTemperatureProtectThreshold=10000
HighTemperatureDisableFlashSwitch=false
HighTemperatureDisableFlashLimit=480
HighTemperatureEnableFlashLimit=470
HighTemperatureDisableFlashChargeSwitch=false
HighTemperatureDisableFlashChargeLimit=480
HighTemperatureEnableFlashChargeLimit=470
camera_temperature_limit=520
HighTemperatureControlVideoRecordSwitch=false
HighTemperatureDisableVideoRecordLimit=550
HighTemperatureEnableVideoRecordLimit=520
ToleranceThreshold=50
ToleranceStart=480
ToleranceStop=460"
fi

patch_rr_config(){
  rr_config=$1
  sed -i 's/<!--.*-->//' "$rr_config"
  sed -i '/<item.*2-2-2-2.*\/>/d' $rr_config
  sed -i 's/2-2-2-2/0-0-0-0/' $rr_config
  sed -i '/<record/d' $rr_config
}

# refresh_rate_config.xml — 解除温控锁帧档位
for file in $(find $dirs -name "refresh_rate_config.xml"); do
  mkdir -p $(dirname $module$file)
  cp -fp "$file" "$module$file"
  patch_rr_config "$module$file"
done
rr_config=/data/system/refresh_rate_config.xml
if [[ -f $rr_config ]]; then
  cp -f $rr_config $rr_config.bak
  patch_rr_config $rr_config
fi

# thermallevel_to_fps.xml — 温控降帧表全部拉满 144
for file in $(find $dirs -name "thermallevel_to_fps.xml")
do
  mkdir -p $(dirname $module$file)
  cp -fp "$file" "$module$file"
  sed -i "s/fps=\"[0-9]*\"/fps=\"144\"/" $module$file
done

# sys_resolution_switch_config.xml — 清空按应用的分辨率切换配置
for file in $(find $dirs -name "sys_resolution_switch_config.xml")
do
  mkdir -p $(dirname $module$file)
  echo -n '' > $module$file
  skip=0
  while read line; do
    case "$line" in
     *"<item package="*|*"<switchop package="*)
       echo "$line" > /dev/null
     ;;
     *)
       echo "$line" >> $module$file
     ;;
    esac
  done < $file
done

# devices_config.json — 放宽电池温度判定区间 (电量链路, 仅 full 变体)
if [ "$VARIANT" = "full" ]; then
for file in $(find $dirs -name "devices_config.json")
do
  mkdir -p $(dirname $module$file)
  echo -n '' > $module$file
  while read line; do
    case "$line" in
     *'"high.capacity.threshold": 100'*)
       echo "$line" >> $module$file
     ;;
     *'"battery.temperate.range":'*)
       echo '"battery.temperate.range": "[100,500]",' >> $module$file
     ;;
     *'"high.capacity.battery.temperate.range":'*)
       echo '"high.capacity.battery.temperate.range": "[100,500]",' >> $module$file
     ;;
     *'"high.capacity.threshold":'*)
       echo '"high.capacity.threshold": 85' >> $module$file
     ;;
     *)
       echo "$line" >> $module$file
     ;;
    esac
  done < $file
done
fi

# /system/vendor 是符号链接时, 把模块内 system/vendor 移出并回链,
# 否则 KSU/Magisk overlay 会失效
handle_partition() {
  if [ -L "/system/$1" ] && [ "$(readlink -f /system/$1)" = "/$1" ]; then
    if [ -e $module/system/$1 ]; then
      mv -f $module/system/$1 $module/$1
    fi
    if [ -e ../$1 ]; then
      ln -sf ../$1 $module/system/$1
    fi
  fi
}

cd $module
mkdir -p $module/system
handle_partition 'vendor'
handle_partition 'system_ext'
handle_partition 'product'

set_perm_recursive $MODPATH 0 0 0755 0644

echo 'OK ^_* 极限GT Y700G4 完全适配版安装完成' 1>&2
