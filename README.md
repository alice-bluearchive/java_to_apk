# Termux APK Builder

![Last Commit](https://img.shields.io/github/last-commit/alice-bluearchive/java_to_apk)
![Commit Activity](https://img.shields.io/github/commit-activity/m/alice-bluearchive/java_to_apk)
[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

在 Termux 终端中编译 Android APK 的工具集，兼容 Android 16，支持自定义应用图标。

包含两个脚本：

- **`apk-builder.sh`** —— 命令行编译工具（初始化、编译、签名）
- **`apk-manager.sh`** —— 基于 Termux:API 的图形化管理器（弹窗菜单操作）

支持两种项目类型：

- **Java 项目** —— 默认生成 XML 布局 + Java 代码，可自由修改
- **HTML 转 APK** —— 用 WebView 打包网页为 APK

## 快速开始

### 1. 安装依赖

```bash
pkg update
pkg install openjdk-17 apksigner dx zipalign imagemagick
pkg install -y gnupg wget
mkdir -p $PREFIX/etc/apt/sources.list.d
echo "deb https://rendiix.github.io android-tools termux" \
  > $PREFIX/etc/apt/sources.list.d/rendiix.list
wget -qP $PREFIX/etc/apt/trusted.gpg.d https://rendiix.github.io/rendiix.gpg
pkg update
pkg install -y android-sdk-build-tools
aapt2 version
```

> `imagemagick` 只在转换图标格式时才需要。

### 2. 获取工具

**方式 A：只下载脚本（推荐）**

```bash
mkdir -p ~/tools
curl -L -o ~/tools/apk-builder.sh \
  https://github.com/alice-bluearchive/java_to_apk/releases/latest/download/apk-builder.sh
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
# 把 android.jar 放到 ~/android-sdk/android-34/
```

**方式 B：克隆完整仓库（含 android.jar）**

```bash
git clone https://github.com/alice-bluearchive/java_to_apk.git
cd java_to_apk
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

**用图形化管理器的话，再加：**

```bash
cp tools/apk-manager.sh ~/tools/
chmod +x ~/tools/apk-manager.sh
pkg install termux-api jq
# 还要从 F-Droid 安装 Termux:API 应用
```

### 3. 编译 APK

**Java 项目：**

```bash
apk-builder.sh init MyApp com.example.myapp MyApp
apk-builder.sh build MyApp                    # 默认图标
apk-builder.sh build MyApp app ~/icon.png     # 自定义图标
termux-open MyApp/build/app.apk
```

**HTML 转 APK：**

```bash
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp ~/page.html
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp ~/MySite
apk-builder.sh build MyWebApp
termux-open MyWebApp/build/app.apk
```

## 目录结构

```
java_to_apk/
├── android-sdk/
│   └── android-34/
│       └── android.jar          # Android 框架类
├── tools/
│   ├── apk-builder.sh           # 命令行编译脚本
│   └── apk-manager.sh           # 图形化管理器
├── example/                     # 示例项目
└── README.md
```

## 图形化管理器（apk-manager.sh）

基于 **Termux:API**，用弹窗菜单管理项目，不用记命令。

### 依赖

```bash
pkg install termux-api jq
```

⚠️ 还需从 **F-Droid** 安装配套的 **Termux:API** 应用。

### 使用

```bash
~/tools/apk-manager.sh          # 打开菜单
~/tools/apk-manager.sh new      # 新建项目
~/tools/apk-manager.sh open     # 打开/编辑项目
~/tools/apk-manager.sh build    # 生成 APK
~/tools/apk-manager.sh del      # 删除项目
~/tools/apk-manager.sh check    # 检查依赖
```

### 环境变量

| 变量 | 默认值 | 作用 |
|------|--------|------|
| `APK_BUILDER_SCRIPT` | `$HOME/tools/apk-builder.sh` | builder 脚本路径 |
| `APK_BUILDER_HOME` | `$HOME/apk-projects` | 项目存放目录 |

### 功能

- **新建项目** —— 选类型、填名字 / 包名 / 应用名
- **打开项目** —— 列出 `.java` / `.html`，可 vi 编辑、外部打开、弹窗预览
- **生成 APK** —— 填输出名和可选图标，完成后弹通知并可直接安装
- **删除项目** —— 二次确认后删除
- **检查依赖** —— 调用 builder 的 `check`

## 编译脚本用法（apk-builder.sh）

```bash
apk-builder.sh init <目录> <包名> <应用名>                 # 初始化 Java 项目
apk-builder.sh init -web <目录> <包名> <应用名> [html]     # 初始化 HTML 项目
apk-builder.sh build <目录> [输出名] [图标.png]            # 编译
apk-builder.sh clean <目录>                                # 清理
apk-builder.sh check                                       # 检查依赖
apk-builder.sh help                                        # 帮助
```

## 编译流程

1. **aapt2 compile** —— 编译资源为 .flat
2. **aapt2 link** —— 链接资源并生成 R.java
3. **javac** —— 编译 Java
4. **d8** —— 转 DEX
5. **zipalign** —— 对齐优化
6. **apksigner** —— 签名

## HTML 转 APK

`init -web` 生成以 `WebView` 为容器的项目，网页放在 `assets/`，通过 `file:///android_asset/index.html` 加载。默认已加 `INTERNET` 权限。

### 项目结构

```
MyWebApp/
├── assets/index.html           # 网页入口
├── src/com/example/webapp/
│   └── MainActivity.java       # WebView 容器
├── res/values/strings.xml
└── AndroidManifest.xml
```

### `[html]` 参数

| 传入 | 行为 |
|------|------|
| **不传** | 生成默认 `assets/index.html` |
| **文件** | 复制为 `assets/index.html` |
| **目录** | 内容整个复制进 `assets/`，**必须含 `index.html`** |

## 自定义应用图标

**不传图标时，用 Android 系统默认图标（绿色机器人）。**

```bash
apk-builder.sh build MyApp app ~/icon.png
```

### 图标要求

- 必须是**真正的 PNG**，改后缀名无效（会报 `failed to read PNG signature`）
- 推荐 **192×192** 或 **512×512**，带透明通道
- Termux 读不到 `/sdcard/`，先 `termux-setup-storage`，用 `~/storage/shared/` 访问

### JPG 转 PNG

```bash
termux-setup-storage
pkg install imagemagick
magick ~/storage/shared/Pictures/1.png \
  -resize 512x512^ -gravity center -extent 512x512 ~/icon.png
file ~/icon.png   # 必须显示 PNG image data
```

## 注意事项

- **Java 项目**：默认生成 XML 布局 + Java 代码，可自由修改
- **HTML 项目**：网页放 `assets/`，默认带 `INTERNET` 权限
- APK 需 Android 5.0+ (API 21+)，目标 SDK 36
- 使用调试密钥签名，适合开发测试
- 自定义图标只支持 PNG

## 依赖说明

| 工具 | 用途 | 安装命令 |
|------|------|----------|
| java | 编译 Java | `pkg install openjdk-17` |
| aapt2 / d8 / zipalign / apksigner | 编译打包签名 | `pkg install android-sdk-build-tools` |
| keytool | 生成密钥 | 随 Java |
| imagemagick | 转换图标（可选） | `pkg install imagemagick` |
| termux-api | 管理器依赖 | `pkg install termux-api` |
| jq | 解析 JSON | `pkg install jq` |

## 常见问题

### Q: 安装提示"解析安装包出现问题"
A: 确保用 aapt2 编译，不是旧版 aapt。

### Q: APK 在哪？
A: 项目 `build/` 目录下，完整路径：
`/data/data/com.termux/files/home/MyApp/build/app.apk`

### Q: 怎么复制 APK 到下载目录？
```bash
cp MyApp/build/app.apk ~/storage/downloads/
```

### Q: 报 "failed to read PNG signature"
A: 图标不是真 PNG。`file ~/icon.png` 看真实格式，是 JPEG 就：
```bash
magick old.png new.png
```

### Q: 不指定图标显示什么？
A: 系统默认机器人图标。旧版本会显示紫色方块。

### Q: 指定图标后还是默认机器人
A: 两种可能：
1. 启动器缓存 —— 先卸载再装：
   ```bash
   pm uninstall com.example.myapp
   termux-open MyApp/build/app.apk
   ```
2. 图标没打进去 —— 确认：
   ```bash
   unzip -l MyApp/build/app.apk | grep ic_launcher
   ```

### Q: 找不到 /sdcard/ 图片
A: `termux-setup-storage` 后，用 `~/storage/shared/` 代替。

### Q: apk-manager 弹窗出不来
A: 两处都要装：
1. Termux：`pkg install termux-api`
2. 手机：从 F-Droid 装 **Termux:API** 应用

### Q: HTML 白屏
A: 1) 入口得叫 `index.html`；2) `unzip -l MyWebApp/build/app.apk | grep assets` 确认打包；3) WebView 默认支持 JS 和 localStorage。

## 许可证

MIT License

---

## 彩蛋

邦邦咔邦，我是**天童爱丽丝**！

爱丽丝在 termux 把 java 和 html 都转成了 .apk，老师快夸我

**老师如果有问题或建议，欢迎提 Issue！**

---

> 天童爱丽丝 | 2026.09.19
>
> "一切奇迹的起点"
