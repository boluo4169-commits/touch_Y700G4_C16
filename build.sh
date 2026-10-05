#!/usr/bin/env bash
# ============================================================
# 模块打包脚本 — Extreme GT Y700G4 双变体 + touch
# 产出 (KSU 模块格式: module.prop 在 zip 根, 条目无 ./ 前缀):
#   ExtremeGT_5.2.1_Y700G4_C16_safe.zip
#   ExtremeGT_5.2.1_Y700G4_C16_full.zip
#   touch_Y700G4_C16T_v5.0.2.zip
# 用法: bash build.sh   (CI 与本地通用; 有 zip 用 zip, 否则回退 python)
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

VER=5.2.2               # 模块版本号(唯一改动点, module.prop/zip 名/描述都取这里)
EG=extreme_gt
TC=touch_Y700G4_C16T/touch_Y700G4_C16T
BASE=https://raw.githubusercontent.com/boluo4169-commits/touch_Y700G4_C16/main

zip_module() { # $1=stage_dir $2=output.zip 其余=打包条目
  local stage="$1" out="$2"; shift 2
  rm -f "$out"

  # 优先 zip（Linux/CI）
  if command -v zip >/dev/null 2>&1; then
    (cd "$stage" && zip -r -q "$OLDPWD/$out" "$@")
    return 0
  fi

  # 回退 python（Windows/Git Bash 通用，产出的仍是标准 zip）
  # 注意：不要用 `tar -a -f out.zip` —— GNU tar 不支持 zip 输出，
  # 只会生成「名字叫 .zip 的 tar」，KSU Manager 无法安装。
  local py=""
  command -v python3 >/dev/null 2>&1 && py=python3
  [ -z "$py" ] && command -v python >/dev/null 2>&1 && py=python
  if [ -n "$py" ]; then
    cat > "$STAGE/_mkzip.py" <<'PYEOF'
import os, sys, zipfile
out = sys.argv[1]
z = zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED)
for root in sys.argv[2:]:
    if os.path.isdir(root):
        for dp, _dn, fn in os.walk(root):
            for f in sorted(fn):
                p = os.path.join(dp, f)
                z.write(p, os.path.relpath(p, "."))
    elif os.path.exists(root):
        z.write(root, root)
z.close()
PYEOF
    (cd "$stage" && "$py" "$STAGE/_mkzip.py" "$OLDPWD/$out" "$@")
    return 0
  fi

  echo "ERROR: 未找到 zip 或 python，无法生成合法 zip" >&2
  return 1
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ---------- 静态检查 ----------
# 检查 shell 关键字是否被"粘"在上一行末尾（如 `echo x >> f`else ）。
# 这类错误 bash -n 查不出来 —— 它语法合法，但会把 else 当成重定向目标名，
# 导致整个分支被并入 if，属于静默逻辑损坏。5.1.1/5.1.2 曾因此踩坑。
lint_glued_keywords() { # $1 = 待检查目录
  local bad=0 f hits
  for f in "$1"/*.sh; do
    [ -f "$f" ] || continue
    hits=$(grep -nE '[^[:space:]#;|&](else|then|fi|do|done|esac)[[:space:]]*$' "$f" 2>/dev/null \
           | grep -vE '^[0-9]+:[[:space:]]*#' || true)
    if [ -n "$hits" ]; then
      echo "❌ LINT FAIL: $f 存在被粘连的 shell 关键字（缺少换行）:" >&2
      echo "$hits" >&2
      bad=1
    fi
  done
  return $bad
}

# ---------- extreme_gt: safe / full 双变体 ----------
for v in safe full; do
  s="$STAGE/extreme_gt_$v"
  mkdir -p "$s"
  cp -r "$EG/META-INF" "$s"
  for f in customize.sh service.sh post-fs-data.sh uninstall.sh system.prop module.prop skin_daemon.sh config; do
    cp "$EG/$f" "$s"
  done

  if [ "$v" = safe ]; then
    batt=0; code=5221; namecn="精简版"; upd="$BASE/extgt_update_safe.json"; offset=20
    desc="Y700四代 ColorOS16 温控解除·精简版 $VER: 修复充电被限流(quiet-therm 移出伪装列表); 外壳温区跟随式伪装; 修复游戏时突然降频(屏幕变暗)。CPU限频阈值+7C, 电池链路零改动。"
  else
    batt=1; code=5222; namecn="完全版"; upd="$BASE/extgt_update_full.json"; offset=28
    desc="Y700四代 ColorOS16 温控解除·完全版 $VER: 修复充电被限流(quiet-therm 移出伪装列表); 外壳温区跟随式伪装(offset 28, 更晚降频) + 电池温度伪装29.5C + CPU限频阈值+7C。"
  fi
  sed -i "s|__BATT_EMUL__|$batt|; s|__VARIANT__|$v|; s|__VERSION__|$VER|; s|__VERSIONCODE__|$code|; s|__NAME_CN__|$namecn|; s|__DESC__|$desc|; s|__UPDJSON__|$upd|; s|__SKIN_OFFSET__|$offset|" \
    "$s/service.sh" "$s/customize.sh" "$s/module.prop" "$s/config"

  # 先做静态检查，通过才打包
  lint_glued_keywords "$s" || exit 1

  zip_module "$s" "ExtremeGT_${VER}_Y700G4_C16_$v.zip" \
    module.prop customize.sh service.sh post-fs-data.sh uninstall.sh system.prop skin_daemon.sh config META-INF
  echo "OK  ExtremeGT_${VER}_Y700G4_C16_$v.zip"
done
# ---------- touch v5.0.2 (守护日志版本号也动态化) ----------
TVER=5.0.2
TCODE=5002
t="$STAGE/touch"
mkdir -p "$t"
for f in module.prop service.sh post-fs-data.sh touch_daemon.sh config system.prop uninstall.sh CHANGELOG.txt; do
  cp "$TC/$f" "$t"
done
cp -r "$TC/META-INF" "$t"
sed -i "s|__VERSION__|v$TVER|; s|__VERSIONCODE__|$TCODE|" "$t/module.prop"
lint_glued_keywords "$t" || exit 1
zip_module "$t" "touch_Y700G4_C16T_v$TVER.zip" \
  module.prop service.sh post-fs-data.sh touch_daemon.sh config system.prop uninstall.sh CHANGELOG.txt META-INF
echo "OK  touch_Y700G4_C16T_v$TVER.zip"
