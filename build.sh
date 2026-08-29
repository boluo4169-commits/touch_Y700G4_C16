#!/usr/bin/env bash
# ============================================================
# 模块打包脚本 — Extreme GT Y700G4 双变体 + touch v4.1
# 产出 (KSU 模块格式: module.prop 在 zip 根, 条目无 ./ 前缀):
#   ExtremeGT_4.2.1_Y700G4_C16_safe.zip
#   ExtremeGT_4.2.1_Y700G4_C16_full.zip
#   touch_Y700G4_C16T_v4.1.zip
# 用法: bash build.sh   (CI 与本地通用; 有 zip 用 zip, 否则回退 bsdtar)
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

EG=extreme_gt
TC=touch_Y700G4_C16T/touch_Y700G4_C16T
BASE=https://raw.githubusercontent.com/boluo4169-commits/touch_Y700G4_C16/main

zip_module() { # $1=stage_dir $2=output.zip 其余=打包条目
  local stage="$1" out="$2"; shift 2
  rm -f "$out"
  if command -v zip >/dev/null 2>&1; then
    (cd "$stage" && zip -r -q "$OLDPWD/$out" "$@")
  else
    tar -a -c -f "$out" -C "$stage" "$@"
  fi
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ---------- extreme_gt: safe / full 双变体 ----------
for v in safe full; do
  s="$STAGE/extreme_gt_$v"
  mkdir -p "$s"
  cp -r "$EG/META-INF" "$s"
  for f in customize.sh service.sh post-fs-data.sh uninstall.sh system.prop module.prop; do
    cp "$EG/$f" "$s"
  done

  if [ "$v" = safe ]; then
    batt=0; code=4211; namecn="精简版"; upd="$BASE/extgt_update_safe.json"
    desc="Y700四代 ColorOS16 温控解除·精简版: 伪装外壳/存储/内存温度解锁满帧, 电池与充电链路零改动, 真实电池温度+充电保护原样保留。"
  else
    batt=1; code=4212; namecn="完全版"; upd="$BASE/extgt_update_full.json"
    desc="Y700四代 ColorOS16 温控解除·完全版: 外壳/存储/内存/电池温度全部伪装29.5C, 彻底解除降频锁帧, 充电高温兜底仍由内核保留。"
  fi

  sed -i "s|__BATT_EMUL__|$batt|; s|__VARIANT__|$v|; s|__VERSIONCODE__|$code|; s|__NAME_CN__|$namecn|; s|__DESC__|$desc|; s|__UPDJSON__|$upd|" \
    "$s/service.sh" "$s/customize.sh" "$s/module.prop"

  zip_module "$s" "ExtremeGT_4.2.1_Y700G4_C16_$v.zip" \
    module.prop customize.sh service.sh post-fs-data.sh uninstall.sh system.prop META-INF
  echo "OK  ExtremeGT_4.2.1_Y700G4_C16_$v.zip"
done

# ---------- touch v4.1 ----------
t="$STAGE/touch"
mkdir -p "$t"
for f in module.prop service.sh post-fs-data.sh touch_daemon.sh config system.prop uninstall.sh CHANGELOG.txt; do
  cp "$TC/$f" "$t"
done
cp -r "$TC/META-INF" "$t"

zip_module "$t" "touch_Y700G4_C16T_v4.1.zip" \
  module.prop service.sh post-fs-data.sh touch_daemon.sh config system.prop uninstall.sh CHANGELOG.txt META-INF
echo "OK  touch_Y700G4_C16T_v4.1.zip"
