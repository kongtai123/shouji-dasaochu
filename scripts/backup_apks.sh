#!/usr/bin/env bash
# backup_apks.sh — 卸载前把手机上的应用打包成 APK 备份到电脑
#
# 为什么需要它：
#   `pm uninstall --user 0` 对「预装系统应用」只是隐藏（可随时恢复），
#   但对「用户自己装的第三方应用」是连 APK 一起删掉、无法用
#   `cmd package install-existing` 恢复的。所以卸载任何第三方应用前，
#   必须先把原始安装包拉到电脑上备份。
#
# 用法:
#   bash backup_apks.sh backup user              # 备份全部第三方应用（最常用）
#   bash backup_apks.sh backup all               # 备份全部应用（含预装，体积大）
#   bash backup_apks.sh backup 包名 [包名...]     # 只备份指定应用
#   bash backup_apks.sh restore <备份目录>        # 从备份目录还原到手机
#   bash backup_apks.sh list <备份目录>           # 查看备份内容
#
# 产出结构:
#   apks_backup/2026-10-22_1830/
#     ├── manifest.tsv        # 包名 + 版本 + APK 文件清单
#     └── apks/               # 原始 APK（含 split 分包）
#
# 前提: adb 已连接手机。建议在卸载操作之前运行 backup。

set -u

BACKUP_ROOT="./apks_backup"

usage() { sed -n '2,20p' "$0"; exit 1; }

# 取应用版本号
get_version() {
  adb shell dumpsys package "$1" 2>/dev/null \
    | grep -m1 'versionName=' \
    | sed 's/.*versionName=//;s/ .*//'
}

cmd_backup() {
  local mode="$1"; shift || true
  local stamp; stamp="$(date +%Y-%m-%d_%H%M%S)"
  local dest="$BACKUP_ROOT/$stamp"
  mkdir -p "$dest/apks"

  local pkgs=()
  case "$mode" in
    user) pkgs=($(adb shell pm list packages -3 | sed 's/package://' | tr -d '\r')) ;;
    all)  pkgs=($(adb shell pm list packages   | sed 's/package://' | tr -d '\r')) ;;
    *)    pkgs=("$mode" "$@") ;;
  esac

  echo "共 ${#pkgs[@]} 个应用，备份到 $dest"
  local manifest="$dest/manifest.tsv"
  printf 'package\tversion\tapk_files\n' > "$manifest"

  local ok=0 fail=0
  for pkg in "${pkgs[@]}"; do
    # pm path 可能返回多行（base + split 分包），全部拉取
    local paths=($(adb shell pm path "$pkg" 2>/dev/null | sed 's/package://' | tr -d '\r'))
    if [ ${#paths[@]} -eq 0 ]; then
      echo "跳过（无法获取路径）: $pkg"; fail=$((fail+1)); continue
    fi
    local files=()
    local p
    for p in "${paths[@]}"; do
      local fname; fname="$(basename "$p")"
      # 同名冲突时按包名归档
      local local_dir="$dest/apks/$pkg"
      mkdir -p "$local_dir"
      if adb pull "$p" "$local_dir/$fname" >/dev/null 2>&1; then
        files+=("$pkg/$fname")
      else
        echo "拉取失败: $pkg ($p)"
      fi
    done
    if [ ${#files[@]} -gt 0 ]; then
      printf '%s\t%s\t%s\n' "$pkg" "$(get_version "$pkg")" "$(IFS=,; echo "${files[*]}")" >> "$manifest"
      ok=$((ok+1))
    else
      fail=$((fail+1))
    fi
  done

  echo "----------------------------------------"
  echo "备份完成: 成功 $ok 个, 失败 $fail 个"
  echo "备份目录: $dest"
  echo "还原命令: bash $0 restore $dest"
}

cmd_restore() {
  local dir="$1"
  [ -f "$dir/manifest.tsv" ] || { echo "找不到 $dir/manifest.tsv"; exit 1; }
  echo "将从 $dir 还原以下应用到手机："
  cut -f1 "$dir/manifest.tsv" | tail -n +2
  local line pkg
  tail -n +2 "$dir/manifest.tsv" | while IFS=$'\t' read -r pkg _ files; do
    [ -z "$pkg" ] && continue
    echo "== 还原 $pkg"
    # 多 APK（split 分包）用 install-multiple
    local apks=()
    local f
    IFS=',' read -ra apks <<< "$files"
    local args=()
    for f in "${apks[@]}"; do
      args+=("$dir/apks/$f")
    done
    if [ ${#args[@]} -gt 1 ]; then
      adb install-multiple -r "${args[@]}"
    else
      adb install -r "${args[0]}"
    fi
  done
}

cmd_list() {
  column -t -s $'\t' "$1/manifest.tsv" 2>/dev/null || cat "$1/manifest.tsv"
}

main() {
  [ $# -lt 1 ] && usage
  case "$1" in
    backup)  shift; cmd_backup "${@:-user}" ;;
    restore) shift; [ $# -ge 1 ] || usage; cmd_restore "$@" ;;
    list)    shift; [ $# -ge 1 ] || usage; cmd_list "$@" ;;
    *) usage ;;
  esac
}

main "$@"
