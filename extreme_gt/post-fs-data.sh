MODDIR=${0%/*}

# ============================================================
# 温控 XML 显式 bind mount (模块自给自足, 无需元模块)
#   - my_product/my_stock: 温控/帧率配置所在只读分区
#   - vendor: thermallevel_to_fps.xml (温控降帧表)。
#     KSU 下 /system/vendor 为符号链接, 模块自动 overlay 不生效,
#     必须显式 bind (旧适配版漏挂, 温控降帧表全 144 一直没生效)。
#   - odm: 温控总开关/高温保护/devices_config 所在分区。
#     实测 (2026-08-29, ksud 4.1.0/sun 内核): /odm 上 bind mount
#     可用, 无条件纳入清单, 不依赖 KSU 原生 overlay/元模块。
# ============================================================

replace_files() {
  local folder="$1"
  find "$MODDIR/$folder" -type f 2>/dev/null | while read -r src; do
    local dst="${src#$MODDIR}"
    [[ -f "$dst" ]] && mount --bind "$src" "$dst"
  done
}

mount_folders='my_product my_heytap my_stock vendor odm'

for folder in $mount_folders; do
  if [[ -d $MODDIR/$folder ]]; then
    replace_files "$folder"
  fi
done
