# 优化国产手机的一些方法

> 用 ADB 调试给国产安卓手机（小米 / Redmi / HyperOS / MIUI）做一次彻底的「大扫除」：
> 卸预装广告、清缓存、腾存储、降内存——特别适合帮**中老年人**清理被垃圾应用塞满的手机。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 这个项目能做什么

| 能做 | 不能做 |
|---|---|
| ✅ 无线连接手机（不用数据线） | ❌ 不需要 Root |
| ✅ 卸载预装广告/追踪组件 | ❌ 不会动你的照片、联系人、聊天记录 |
| ✅ 清理应用缓存、定位大文件 | ❌ 不破解、不刷机、不绕过任何安全机制 |
| ✅ 所有操作**可逆**，随时恢复 | |

## 原理：为什么国产手机会越用越卡

以小米 HyperOS 为例，新机自带大量「内容应用 + 广告/追踪组件」：

- `com.miui.systemAdSolution`（MSA）：系统级广告组件，锁屏弹广告的源头
- `com.miui.analytics`、`com.xiaomi.security.onetrack`：行为追踪上报
- `com.miui.hybrid`：快应用服务，各种「领红包」「极速版」弹窗的入口
- 小米音乐 / 视频 / 新闻 / 游戏 / 主题商店……每个都常驻后台

普通用户在设置里**卸不掉**它们（按钮是灰的），但通过 ADB 的
`pm uninstall --user 0` 可以为当前用户「解除安装」——系统分区不动，
随时可以用一条命令恢复。**这是官方支持的调试通道，不是越狱。**

---

## 第一步：准备 ADB

**macOS**（推荐直接下载官方包，Homebrew 在部分环境会沙箱报错）：

```bash
curl -L -o /tmp/platform-tools.zip \
  https://dl.google.com/android/repository/platform-tools-latest-darwin.zip
cd /tmp && unzip -oq platform-tools.zip
/tmp/platform-tools/adb version   # 验证
```

**Windows**：下载 [platform-tools-windows.zip](https://dl.google.com/android/repository/platform-tools-latest-windows.zip) 解压即可。

**Linux**：`sudo apt install adb` 或下载 [linux 版](https://dl.google.com/android/repository/platform-tools-latest-linux.zip)。

## 第二步：打开手机的开发者选项

1. 设置 → 我的设备 → 全部参数 → 连续点击 **「OS 版本」7 次**
2. 设置 → 更多设置 → 开发者选项 → 打开 **「USB 调试」**

### 方式 A：USB 有线调试（最稳，推荐第一次用）

数据线连接电脑，手机弹窗选「文件传输」并**允许 USB 调试**：

```bash
adb devices          # 看到 device 即成功
```

### 方式 B：无线调试（免线，Android 11+）

前提：手机和电脑在**同一个 Wi-Fi**。

1. 开发者选项 → **无线调试** → 开启
2. 点 **「使用配对码配对设备」**，弹窗里有：6 位配对码 + `IP:端口`
3. ⚠️ 配对端口**只在弹窗开着时有效**，关闭弹窗就换端口
4. 电脑上执行（把 IP:端口和配对码换成弹窗里的）：

```bash
adb pair 192.168.1.222:38907 123456
adb connect 192.168.1.222:39069    # 这个端口在「无线调试」主页面
```

> 💡 配对一次即可。之后每次连接只需要 `adb connect IP:端口`。
> ⚠️ 无线调试**每次开关，端口都会变**，要重新看一眼。

### 方式 C：电脑开着代理（TUN/Clash 类）的额外坑

如果你的电脑开了 TUN 模式代理（Clash / Mihomo / Surge 等），
直连手机会报 `protocol fault (couldn't read status message)`——
代理把发往局域网的 TCP 劫持了。解决办法：让 ADB 流量走本地混合代理端口
（一般是 `127.0.0.1:7890`），用本项目提供的隧道脚本：

```bash
python3 scripts/adb_relay.py 15556 192.168.1.222:39069
# 新开一个终端
adb connect 127.0.0.1:15556
```

详见 [scripts/adb_relay.py](scripts/adb_relay.py) 顶部注释。

---

## 第三步：先拍快照，再动手

```bash
adb shell pm list packages -s | wc -l   # 系统应用数
adb shell pm list packages -3           # 第三方应用清单
adb shell df -h /storage/emulated       # 存储占用
adb shell dumpsys diskstats             # 各类数据大小明细
adb shell dumpsys meminfo | head -20    # 内存大户
```

**把输出存下来**，清理后好对比。

## 第四步：安全卸载预装垃圾

本仓库 [scripts/bloat_uninstall.sh](scripts/bloat_uninstall.sh) 内置了一份
经过实机验证的小米 HyperOS 清单，分三档：

- **A 档（纯广告/追踪，无任何功能）**：MSA、analytics、onetrack、
  快应用服务、杂志锁屏、joyose 云控……放心卸
- **B 档（预装内容应用）**：小米音乐/视频/新闻/游戏/主题商店/黄页等，
  不用就卸
- **C 档（有功能，按需）**：小爱同学、负一屏、传送门、万能遥控等，
  自己决定

```bash
# 卸载 A+B 档
bash scripts/bloat_uninstall.sh uninstall ab

# 只看清单不执行
bash scripts/bloat_uninstall.sh list

# 后悔了？一键全部恢复
bash scripts/bloat_uninstall.sh restore ab
```

### ⚠️ 三条铁律（都是踩过的坑）

1. **不要卸载**：查找设备、云服务、应用商店、天气、相册、
   电话/短信相关、名字带 `overlay` 的包
2. **卸输入法前，先把想留的输入法设为默认**，否则键盘直接没了：

   ```bash
   adb shell ime list -a -s                          # 找到组件名
   adb shell ime enable 包名/.ImeService
   adb shell ime set   包名/.ImeService              # 先切换
   adb shell pm uninstall --user 0 其他的输入法        # 再卸载
   ```

3. **卸载系统组件时手机 adbd 会重启**，无线调试可能短暂掉线、
   端口变化——重连即可，不是翻车。

## 第五步：清缓存、找大文件

```bash
# 清理全部应用缓存（安全，会自动重建）
adb shell pm trim-caches 999999999999999

# 找出下载目录的大文件（按大小排序）
adb shell "ls -S -l /sdcard/Download/ | head -20"

# 统计各目录占用（KB）
adb shell "du -sk /sdcard/* | sort -rn | head -15"
```

实测案例：一部 256GB 的 Redmi Note 13 Pro，
删除一个 19GB 的陈年文件 + 12 个重复 APK + 全部缓存，
**占用从 88% 降到 78%，释放 21GB**，全程 10 分钟。

## 帮中老年人清理手机的额外建议

给爸妈的手机做清理，技术之外更重要的是这几条：

1. **卸载输入法用「换」不用「删」**：先把老人习惯的输入法设为默认
2. **装一个「远程协助」**：如网易 UU远程 / 向日葵，下次直接远程帮操作
3. **关掉应用商店的自动更新**，避免垃圾应用「复活」
4. **关闭系统广告开关**：设置 → 安全 → 更多安全设置 → 个性化广告推荐
5. **微信是存储黑洞**：微信 → 设置 → 通用 → 存储空间，
   定期清「聊天文件/视频」，动辄几十 GB
6. 如果老人用「手机分身/隐私空间」，**里面往往还藏着一个微信**，记得也清
7. 清理完把「无线调试」关掉，更安全

## 常见问题

| 现象 | 原因与解法 |
|---|---|
| `device offline` | 手机 adbd 重启了，`adb connect IP:端口` 重连 |
| `failed to connect` | 无线调试端口变了，去手机上看新端口 |
| `protocol fault` | 电脑 TUN 代理劫持，用 `adb_relay.py` 走代理隧道 |
| `not installed for 0` | 该应用本来就已卸载，跳过即可 |
| 配对总失败 | 配对弹窗有效期很短，拿到配对码后立刻执行 `adb pair` |
| 恢复某个应用 | `adb shell cmd package install-existing 包名` |

## 恢复所有被卸载的应用

```bash
bash scripts/bloat_uninstall.sh restore ab   # A+B 档全部恢复
adb shell cmd package install-existing com.miui.player   # 恢复单个
```

## 免责声明

- 本项目所有操作均通过 Android 官方 ADB 接口完成，不 Root、不刷机
- 卸载清单基于小米 HyperOS（Android 16）实机验证，**其他品牌
  （华为/OPPO/vivo/荣耀）包名不同，请勿直接套用**，先用
  `adb shell pm list packages -s` 自己核对
- 执行 `restore` 前应用从未被真正删除，但因误操作导致的
  数据丢失仍请自行负责

## License

MIT
