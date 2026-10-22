#!/usr/bin/env bash
# bloat_uninstall.sh — 小米 HyperOS 预装应用批量卸载/恢复工具
#
# 用法:
#   bash bloat_uninstall.sh list [a|b|ab]        只列出包名，不执行
#   bash bloat_uninstall.sh uninstall [a|b|ab]   卸载（--user 0，可逆）
#   bash bloat_uninstall.sh restore  [a|b|ab]    恢复已卸载的应用
#
# 前提: adb 已连接手机（adb devices 能看到 device）
# 说明: 所有卸载均为 `pm uninstall --user 0`，只对当前用户生效，
#       系统分区不动，用 `cmd package install-existing 包名` 即可恢复。
#
# 实机验证: Redmi Note 13 Pro (2312DRA50C, HyperOS / Android 16)
# ⚠️ 其他品牌(华为/OPPO/vivo/荣耀)包名不同，请勿直接套用！

set -u

# ============ A 档：纯广告/追踪组件，无任何功能，放心卸 ============
TIER_A=(
  com.miui.systemAdSolution        # MSA 系统广告组件
  com.miui.analytics               # 分析追踪上报
  com.xiaomi.security.onetrack     # 埋点追踪
  com.xiaomi.joyose                # 云控/数据上报
  com.miui.uireporter              # 界面数据上报
  com.miui.contentcatcher          # 剪贴板内容推荐
  com.miui.bugreport               # 用户反馈上报
  com.miui.dmregservice            # 设备注册服务
  com.xiaomi.ab                    # AB 测试组件
  com.xiaomi.ugd                   # 数据组件
  com.mfashiongallery.emag         # 杂志锁屏画报
  com.miui.hybrid                  # 快应用服务（弹窗广告入口）
)

# ============ B 档：预装内容应用，不用就卸 ============
TIER_B=(
  com.miui.player                  # 小米音乐
  com.miui.video                   # 小米视频
  com.miui.newhome                 # 小米新闻资讯
  com.miui.fm                      # 收音机
  com.miui.themestore              # 主题商店
  com.miui.newmidrive              # 小米网盘
  com.miui.miservice               # 小米服务
  com.miui.cleanmaster             # 清理大师
  com.miui.huanji                  # 小米换机
  com.miui.yellowpage              # 黄页
  com.xiaomi.gamecenter.sdk.service# 游戏中心 SDK
  com.xiaomi.migameservice         # 小米游戏服务
  com.xiaomi.minigame              # 小米小游戏
  com.UCMobile                     # UC 浏览器（部分机型预装）
)

# ============ C 档：有功能，按需手动加 ============
# com.miui.voiceassist            # 小爱同学（后台常驻 ~270MB）
# com.miui.voiceassistoverlay     # 小爱悬浮层
# com.miui.voicetrigger           # 语音唤醒
# com.miui.greenguard             # 儿童守护
# com.miui.touchassistant         # 悬浮球
# com.miui.contentextension       # 传送门
# com.miui.backup                 # 本地备份
# com.miui.personalassistant      # 负一屏
# com.duokan.phone.remotecontroller # 万能遥控
# com.miui.tsmclient              # 小米公交卡（用 NFC 乘车的别删）

# ============ 绝对不要碰 ============
# com.xiaomi.finddevice           # 查找设备（防盗）
# com.miui.cloudservice 系列       # 云服务/同步
# com.xiaomi.market               # 应用商店
# com.miui.home / com.miui.securitycenter 系列
# 名字带 overlay 的包              # RRO 资源覆盖层

usage() {
  sed -n '2,12p' "$0"
  exit 1
}

tier_pkgs() {
  case "${1:-ab}" in
    a)  echo "${TIER_A[@]}" ;;
    b)  echo "${TIER_B[@]}" ;;
    ab) echo "${TIER_A[@]}" "${TIER_B[@]}" ;;
    *)  usage ;;
  esac
}

main() {
  [ $# -lt 1 ] && usage
  action="$1"
  tier="${2:-ab}"

  case "$action" in
    list)
      echo "==== ${tier^^} 档包名清单 ===="
      for p in $(tier_pkgs "$tier"); do echo "$p"; done
      ;;
    uninstall)
      echo "==== 卸载 ${tier^^} 档 ===="
      for p in $(tier_pkgs "$tier"); do
        printf '%-42s ' "$p"
        adb shell pm uninstall --user 0 "$p" 2>&1
      done
      ;;
    restore)
      echo "==== 恢复 ${tier^^} 档 ===="
      for p in $(tier_pkgs "$tier"); do
        printf '%-42s ' "$p"
        adb shell cmd package install-existing "$p" 2>&1
      done
      ;;
    *) usage ;;
  esac
}

main "$@"
