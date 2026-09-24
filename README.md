# Termux APK Builder
![Last Commit](https://img.shields.io/github/last-commit/alice-bluearchive/java_to_apk)
![Commit Activity](https://img.shields.io/github/commit-activity/m/alice-bluearchive/java_to_apk)
[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

在 Termux 终端里把 Java / HTML 打包成 Android APK 的工具集，兼容 Android 16 (API 36)，支持自定义应用图标。

支持两种项目类型：
- **Java 项目** —— 纯 Java 代码构建 UI
- **HTML 转 APK** —— 用 WebView 把网页打包成 APK

提供两种使用方式：
- **命令行** —— `apk-builder.sh`，适合脚本化
- **图形界面** —— `apk-manager.sh`，用 Termux:API 的原生对话框，手机党友好

## 快速开始

### 1. 安装依赖

```bash
pkg update
pkg install openjdk-17 aapt2 dx zipalign apksigner imagemagick termux-api jq
如果 aapt2 版本太旧，加第三方源装新版：

```bash
# 前置工具
pkg install -y gnupg wget

# 添加 rendiix 源
mkdir -p $PREFIX/etc/apt/sources.list.d
echo "deb https://rendiix.github.io android-tools termux" \
  > $PREFIX/etc/apt/sources.list.d/rendiix.list

# 导入 GPG 公钥
wget -qP $PREFIX/etc/apt/trusted.gpg.d https://rendiix.github.io/rendiix.gpg

# 刷新并安装
pkg update
pkg install -y android-sdk-build-tools

# 验证
aapt2 version
```

imagemagick 只在转换图标格式时需要，纯编译可不装。
termux-api + Termux:API App 是图形界面的依赖，只用命令行可跳过。
jq 强烈推荐装上，用于稳定解析对话框返回的 JSON。

2. 部署脚本

```bash
git clone https://github.com/alice-bluearchive/java_to_apk.git
cd java_to_apk

# 脚本放到 ~/tools/
mkdir -p ~/tools
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh

# android.jar 放到 ~/android-sdk/
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

3. 项目存放位置

所有由 apk-manager.sh 创建的项目会放在：

```
~/apk-projects/<项目名>/
```

想让项目放到别处，导出环境变量即可：

```bash
export APK_BUILDER_HOME=/sdcard/apk-projects
```

用法一：图形界面（推荐）

先装 Termux:API 配套 App（应用商店搜索 "Termux:API"），然后在 Termux 里：

```bash
pkg install termux-api jq
```

把 apk-manager.sh 写到 ~/tools/（见下方"apk-manager.sh 用法"一节），然后：

```bash
bash ~/tools/apk-manager.sh
```

主菜单会弹出底部对话框：

```
┌─────────┐
│ 新建项目         │
│ 打开项目         │
│ 生成 APK        │
│ 删除项目         │
│ 检查依赖         │
│ 退出             │
└───────-─┘
```

· 新建项目 —— 先选 HTML / Java，再依次输入项目名、包名、应用名
· 打开项目 —— 选项目，列出该项目的 .java 和 .html 文件，可选"编辑 / 外部打开 / 预览"
· 生成 APK —— 选项目，输入输出名、可选图标路径，编译完弹通知，可一键安装
· 删除项目 —— 二次确认后 rm -rf

想设个别名少打字：

```bash
echo 'alias apkm="bash $HOME/tools/apk-manager.sh"' >> ~/.bashrc
source ~/.bashrc
apkm
```
用法二：命令行

```bash
# 初始化 Java 项目（在 ~/apk-projects/ 下）
cd ~/apk-projects
apk-builder.sh init MyApp com.example.myapp MyApp

# 编译（默认图标）
apk-builder.sh build MyApp

# 编译（自定义 PNG 图标）
apk-builder.sh build MyApp app ~/storage/shared/Download/icon.png

# HTML 转 APK
apk-builder.sh init -web MyWeb com.example.webapp MyWeb
apk-builder.sh init -web MyWeb com.example.webapp MyWeb ~/storage/shared/MySite/index.html
apk-builder.sh build MyWeb

# 清理 / 检查 / 帮助
apk-builder.sh clean MyApp
apk-builder.sh check
apk-builder.sh help
```

目录结构
```
java_to_apk/
├── android-sdk/
│   └── android-34/
│       └── android.jar          # Android 框架类（编译用）
├── example/
│   ├── MyApp/                   # Java 项目示例
│   └── Web1/                    # HTML 转 APK 示例
├── tools/
│   ├── apk-builder.sh           # 命令行编译脚本
│   └── apk-manager.sh           # Termux:API 图形界面（可选）
└── README.md

~/apk-projects/                  # 你自己的项目（不在 git 仓库里）
├── MyApp/
└── MyWeb/
```

apk-builder.sh 用法

```bash
apk-builder.sh init <项目目录> <包名> <应用名>                 # 初始化 Java 项目
apk-builder.sh init -web <项目目录> <包名> <应用名> [html]     # 初始化 HTML 转 APK 项目
apk-builder.sh build <项目目录> [输出名] [图标.png]            # 编译项目
apk-builder.sh clean <项目目录>                                # 清理构建文件
apk-builder.sh check                                           # 检查依赖
apk-builder.sh help                                            # 显示帮助
```

编译流程

1. aapt2 compile - 编译资源文件为 .flat 格式
2. aapt2 link - 链接资源并生成 R.java
3. javac - 编译 Java 代码
4. d8 - 转换为 DEX 格式
5. zipalign - 对齐 APK
6. apksigner - 使用调试密钥签名 APK

HTML 转 APK

init -web 会生成一个以 WebView 为容器的 Android 项目，网页文件放在 assets/ 目录，编译后通过 file:///android_asset/ 加载
项目结构

```
MyWeb/
├── assets/
│   └── index.html              # 网页首页
├── src/
│   └── com/example/webapp/
│       └── MainActivity.java   # WebView 容器
├── res/
│   └── mipmap/ic_launcher.png
└── AndroidManifest.xml
```

要点

· [html] 参数可选：不传时生成默认 index.html；传入时把指定文件/目录复制到 assets/
· 修改网页：直接编辑 assets/ 下的文件，重新 build 即可
· 引入 CSS / JS / 图片：一起放进 assets/，用相对路径引用
· 需要联网：init -web 生成的 AndroidManifest.xml 已包含 INTERNET 权限

自定义应用图标

init 时会在 res/mipmap/ 下生成一个默认图标。要换成自己的，build 时把 PNG 路径作为第三个参数：

```bash
apk-builder.sh build MyApp app ~/storage/shared/Download/icon.png
```

图标要求

· 必须是真正的 PNG 格式，JPG / WebP 改后缀无效，aapt2 会报：
  ```
  failed to read PNG signature
  ```
· 推荐尺寸 192×192 或 512×512 的正方形，带透明通道最佳
· Termux 默认读不到 /sdcard/，先执行 termux-setup-storage，
  然后用 ~/storage/shared/... 访问手机文件

把 JPG 转成 PNG

```bash
termux-setup-storage
pkg install imagemagick
magick ~/实际目录/文件.png \
  -resize 512x512^ -gravity center -extent 512x512 ~/icon.png
file ~/icon.png   # 必须显示 PNG image data
```

注意事项

· Java 项目：UI 只能用纯 Java 代码创建，不能使用 XML 布局文件
· HTML 项目：网页文件放入 assets/ 目录，通过 WebView 加载
· 生成的 APK 需要 Android 5.0+ (API 21+)
· 使用调试密钥签名，适合开发测试
· 自定义图标只支持 PNG，不支持 SVG / XML vector
· 安装 APK 使用 termux-open 或文件管理器

依赖说明

工具 用途 安装命令
java 编译 Java 代码 pkg install openjdk-17
aapt2 编译资源文件 pkg install aapt2
d8 / dx 转换 DEX 格式 pkg install dx
zipalign 优化 APK pkg install zipalign
apksigner 签名 APK pkg install apksigner
keytool 生成密钥 随 Java 安装
imagemagick 转换图标格式（可选） pkg install imagemagick
termux-api 图形界面（可选） pkg install termux-api
jq 解析对话框 JSON（推荐） pkg install jq

常见问题

Q: apk-manager.sh 点"新建项目"后闪退

A: 通常是对话框 JSON 解析失败。装 jq 即可解决：

```bash
pkg install jq
```

termux-dialog 返回的 code 字段在成功/取消时会返回 -1 / 0 / -2，
不可靠，脚本一律以 text 字段为准。

Q: apk-manager.sh 报"缺 termux-dialog"

A: 需要装两样东西：
1. pkg install termux-api
2. 从应用商店装 Termux:API App（和 Termux 主程序配套的那个）

Q: 安装 APK 时提示"解析安装包出现问题"

A: 确保使用 aapt2 编译，而不是旧版 aapt。

Q: 如何在 MT 管理器中找到 APK？

A: APK 位于项目的 build/ 目录下：

```
/data/data/com.termux/files/home/apk-projects/MyApp/build/app.apk
```

Q: 如何复制 APK 到下载目录？

A:

```bash
cp ~/apk-projects/MyApp/build/app.apk ~/storage/downloads/
```

Q: 编译报 "failed to read PNG signature"

A: 图标不是真正的 PNG。file ~/icon.png 看真实格式，
是 JPEG 就用 magick 转：

```bash
magick old.png new.png
```

Q: 指定了图标，装完还是默认的安卓机器人

A: 两种情况：

1. 启动器缓存了旧图标 —— 先卸载旧版，再重新安装：
   ```bash
   pm uninstall com.example.myapp
   termux-open ~/apk-projects/MyApp/build/app.apk
   ```
2. 图标没真正打进 APK，用这条命令确认：
   ```bash
   unzip -l ~/apk-projects/MyApp/build/app.apk | grep ic_launcher
   ```
   没有输出说明 build 时图标没被复制。

Q: 找不到 /sdcard/ 下的图片

A: Termux 默认无存储权限。执行 termux-setup-storage，
之后用 ~/storage/shared/ 代替 /sdcard/。

Q: HTML 项目网页白屏

A: 检查：

1. 网页文件确实在 assets/ 下，文件名与加载路径一致
2. unzip -l ~/apk-projects/MyWeb/build/app.apk | grep assets 确认打包
3. 需要网络请求时，AndroidManifest.xml 里是否加了 INTERNET 权限

Q: 想改 apk-manager.sh 的项目目录

A: 导出环境变量后再启动：

```bash
export APK_BUILDER_HOME=/sdcard/apk-projects
bash ~/tools/apk-manager.sh
```

或在 ~/.bashrc 里永久设置。

许可证

MIT License

---
小结
邦邦咔邦，我是天童爱丽丝！

爱丽丝在 Termux 里把 Java 和 HTML 都打包成了 .apk，
还在手机上调出了原生对话框做图形界面，老师快夸我！

老师如果有问题或建议，欢迎提 Issue！

---

天童爱丽丝 | 2026.09.22

"一切奇迹的起点"