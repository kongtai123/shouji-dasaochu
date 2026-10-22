# 手机大扫除

> **第一个目的：让家里老人手机里的垃圾快应用、广告应用，被一次性连根拔掉。**
> **第二个目的：让你自己的国产安卓手机用得更久一点，少弹广告、少占空间。**
> 不只是小米——华为、OPPO、vivo、荣耀都适用。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🚀 最推荐的用法：把链接发给 AI，让 AI 替你干活

**你不需要看懂下面的任何命令。** 把这个仓库的链接直接发给任何一个会用电脑的
AI 编程助手（WorkBuddy、Codex、Claude Code、Cursor 等），然后说：

```text
打开这个仓库 https://github.com/kongtai123/shouji-dasaochu ，
按照里面的方法，用 ADB 连接我的安卓手机，扫描一下：
1. 装了哪些应用，哪些是预装垃圾、广告追踪、可疑应用
2. 存储空间被什么吃掉了，哪些大文件可以删
3. 内存被哪些后台应用占着
先分类列给我看，经我确认后再卸载/删除，卸载前告诉我每项的用途和风险。
```

AI 会替你完成：连接手机 → 扫描 → 分类 → 征求你意见 → 执行 → 汇报结果。
老人不方便操作手机的话，**你扫一次，替爸妈也扫一次**。

> ⚠️ 提醒：让 AI 动手前自己过目一遍清单；本仓库所有卸载操作都是可逆的。

---

## 这项目解决什么问题

家里老人的手机常见惨状：

- 「清理大师」「WiFi 万能钥匙」「新闻头条极速版」……装了十几屏
- **快应用**（无需安装的小程序式应用）从网页、应用商店各种入口偷偷「安装」
- 锁屏广告、通知栏「红包」弹个不停
- 128GB 的手机只剩 2GB，微信占用 80GB
- 各种应用在后台常驻，两天一充电都嫌多

这些问题的根源大部分是**预装广告组件 + 全家桶内容应用 + 老人不会拒绝的
「确认」按钮**。普通设置里卸不掉它们（按钮是灰的），但通过 ADB 的官方
调试通道可以为当前用户解除安装——**免 Root、不刷机、全程可逆**。

---

## 场景一：帮爸妈（或任何人）清理手机

### 第 1 步：准备 ADB（一次性）

**macOS**：

```bash
curl -L -o /tmp/platform-tools.zip \
  https://dl.google.com/android/repository/platform-tools-latest-darwin.zip
cd /tmp && unzip -oq platform-tools.zip
/tmp/platform-tools/adb version   # 验证
```

Windows 下载 [platform-tools-windows](https://dl.google.com/android/repository/platform-tools-latest-windows.zip)，
Linux `sudo apt install adb`。

### 第 2 步：手机上打开调试（教老人按三下就行）

1. 设置 → 关于手机 → 连续点击 **「版本号 / OS 版本」7 次**
   （会提示「已进入开发者模式」）
2. 设置里搜 **「USB 调试」**，打开
3. 数据线连电脑，手机弹窗点「允许」

有线连上了就可以干活，**无线调试**（免线）进阶用法见下文。

### 第 3 步：扫描 + 分类（这是核心）

```bash
adb devices                            # 确认手机已连接

adb shell pm list packages -3          # 用户装的应用
adb shell pm list packages -s | wc -l  # 预装应用数量

adb shell df -h /storage/emulated      # 存储还剩多少
adb shell dumpsys diskstats            # 什么在吃存储
adb shell dumpsys meminfo | head -20   # 谁在吃内存

adb shell "ls -S -l /sdcard/Download/ | head -20"          # 下载目录大文件
adb shell "du -sk /sdcard/* | sort -rn | head -15"         # 各目录占用
```

然后把结果**按四类整理**（交给 AI 做也行）：

| 分类 | 判断标准 | 处理 |
|---|---|---|
| 🔴 广告/追踪组件 | 包名含 `ads`/`adSolution`/`analytics`/`track`/`onetrack`，或各品牌「推送/快应用/画报」服务 | 建议卸 |
| 🟠 预装全家桶 | 品牌×音乐/视频/新闻/游戏/主题/阅读商店，老人不用的 | 询问后卸 |
| 🟡 可疑第三方 | 名字看不懂、来源不明、老人说不清是什么的 | 查明用途再问 |
| 🟢 要保留的 | 微信、支付宝、银行、输入法、相册…… | 别动 |

### 第 4 步：卸载（可逆）

```bash
# 单个卸载
adb shell pm uninstall --user 0 包名

# 恢复（后悔药）
adb shell cmd package install-existing 包名

# 小米用户可直接用本仓库的清单脚本
bash scripts/bloat_uninstall.sh uninstall ab   # 卸 A+B 档
bash scripts/bloat_uninstall.sh restore ab     # 一键恢复
```

### 第 5 步：清缓存和垃圾文件

```bash
adb shell pm trim-caches 999999999999999        # 全部应用缓存，自动重建
```

大文件先给老人看一眼再删（比如陈年的视频文件）。

### 收尾三件事

1. 微信 → 设置 → 通用 → 存储空间 → 清理（老人手机的微信普遍占几十 GB）
2. 如果老人用「手机分身/隐私空间」，里面往往还有一个微信，也清
3. 关掉「开发者选项 → 无线调试」（用有线的话），更安全

---

## 场景二：给自己的国产安卓延寿、去广告

和场景一流程相同，重点换成：

- **卸广告源头**：各品牌的广告/追踪/快应用服务（小米清单见
  [scripts/bloat_uninstall.sh](scripts/bloat_uninstall.sh)，实测释放
  后台内存、锁屏广告显著减少）
- **卸预装内容应用**：自己有网易云、B 站的，就不需要厂商的「音乐」「视频」
- **关闭厂商的广告开关**（各品牌路径不同，搜「个性化广告」「系统广告」）
- **应用商店关掉自动更新**，防止全家桶被「更新」回来
- 定期 `pm trim-caches`，一年做一次大扫除

---

## 各品牌预装垃圾速查（包名前缀）

不同品牌垃圾组件的前缀不同，扫描时按这些关键字过滤：

| 品牌 | 系统前缀 | 典型垃圾关键字 |
|---|---|---|
| 小米 / Redmi | `com.miui.*` `com.xiaomi.*` | `systemAdSolution` `analytics` `hybrid`(快应用) `onetrack` `joyose` `emag`(画报) |
| 华为 / 荣耀 | `com.huawei.*` `com.hihonor.*` | `hiview` `hwPostUpdate` `hiasset` `pushagent` `market` 系全家桶 |
| OPPO / 一加 | `com.coloros.*` `com.oplus.*` `com.oppo.*` | `oppomarket` `nearme` `gameservice` `assistantscreen` |
| vivo / iQOO | `com.vivo.*` `com.bb.*` | `PushEngine` `gameassistant` `ewallet` `browser` 系全家桶 |

> ⚠️ 本仓库的小米清单经过实机验证（Redmi Note 13 Pro / HyperOS），
> **其他品牌请只参考方法论**：先 `pm list packages -s` 看清楚，
> 逐个搜索确认用途再动手。卸载前确认该应用不在运行、不是支付/查找设备类。

### 品牌通用红线（哪个牌子都别碰）

- 查找设备 / 手机找回类（`finddevice`、`findmymobile`…）
- 支付、钱包、NFC 交通卡（除非确认不用）
- 云服务 / 账号同步
- 电话、短信、联系人相关
- 名字带 `overlay` 的（界面资源层）

---

## 无线调试（免数据线，Android 11+）

1. 开发者选项 → **无线调试** → 开启
2. 点 **「使用配对码配对设备」**：弹窗里有 6 位配对码 + `IP:端口`
3. ⚠️ 配对端口只在弹窗开着时有效，动作要快：

```bash
adb pair 192.168.1.222:38907 123456       # 配对一次即可
adb connect 192.168.1.222:39069           # 端口在「无线调试」主页面
```

⚠️ 无线调试**每次开关端口都会变**，重连前看一眼新端口。

### 电脑开着代理（Clash/TUN 类）连不上的坑

报 `protocol fault (couldn't read status message)` 是因为 TUN 代理劫持了
发往局域网的 TCP。用本仓库的隧道脚本让 ADB 走代理：

```bash
python3 scripts/adb_relay.py 15556 192.168.1.222:39069
adb connect 127.0.0.1:15556
```

---

## 实测战绩

Redmi Note 13 Pro（256GB，HyperOS）：

| 项目 | 结果 |
|---|---|
| 删除陈年大文件（19.2GB 的 .txt） | +19GB |
| 清理重复安装包 ×12 | +0.5GB |
| 全部应用缓存 | +2GB |
| 卸载预装广告/全家桶 26 个 | 锁屏广告消失、后台内存下降 |
| **合计** | **存储占用 88% → 78%，释放 21GB，用时约 10 分钟** |

## 常见问题

| 现象 | 解法 |
|---|---|
| `device offline` | 手机 adbd 重启了，重新 `adb connect` |
| `failed to connect` | 无线调试端口变了，去手机上看新端口 |
| `protocol fault` | 电脑 TUN 代理劫持，用 `scripts/adb_relay.py` |
| `not installed for 0` | 本来就已卸载，跳过 |
| 配对总失败 | 配对码有效期很短，拿到后立刻执行 |
| 键盘不见了 | 卸输入法前要先 `ime set` 设置默认输入法！方法见脚本注释 |
| 想恢复某个应用 | `adb shell cmd package install-existing 包名` |

## 免责声明

- 全程走 Android 官方 ADB 接口：不 Root、不刷机、不绕过安全机制
- 卸载只是「对当前用户隐藏」，`restore` 可随时恢复；但请对误删
  老人需要的应用保持敬畏，动手前列清单、多确认
