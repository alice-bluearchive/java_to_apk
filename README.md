[**中文**](#中文) &nbsp;|&nbsp; [**English**](#english)

---

<a id="中文"></a>

# Termux APK Builder

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
pkg install openjdk-17 apksigner imagemagick
pkg install android-sdk-build-tools   # 提供 aapt2 / d8
# 安装 zipalign
curl -s https://raw.githubusercontent.com/rendiix/rendiix.github.io/master/install-repo.sh | bash
pkg install zipalign
# 如果提示找不到这个包
#apt install
```
### 2. 获取工具

**方式 A：克隆完整仓库（含 android.jar）**

```bash
git clone https://github.com/alice-bluearchive/java_to_apk.git
cd java_to_apk
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

**方式 B：只下载脚本（不推荐）**

```bash
mkdir -p ~/tools
curl -L -o ~/tools/apk-builder.sh \
  https://github.com/alice-bluearchive/java_to_apk/releases/latest/download/apk-builder.sh
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
# 把 android.jar 放到 ~/android-sdk/android-34/
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

> 脚本内部临时文件写在 `$TMPDIR`（Termux 自带），不要用 `/tmp` —— Termux 下 `/tmp` 不存在。

### 功能

- **新建项目** —— 选类型、填名字 / 包名 / 应用名
- **打开项目** —— 列出 `.java` / `.html`，可 vi 编辑、外部打开、弹窗预览
- **生成 APK** —— 填输出名和可选图标，完成后弹通知并可直接安装
- **删除项目** —— 二次确认后删除
- **检查依赖** —— 调用 builder 的 `check`

### 操作习惯

弹窗里**点取消 = 中止当前操作**，回到主菜单，不会用默认值继续。

## 编译脚本用法（apk-builder.sh）

```bash
apk-builder.sh init <目录> <包名> <应用名>                 # 初始化 Java 项目
apk-builder.sh init -web <目录> <包名> <应用名> [html]     # 初始化 HTML 项目
apk-builder.sh build <目录> [输出名] [图标]                # 编译
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

支持格式：`png` / `jpg` / `jpeg` / `ico` / `icon` / `webp` / `bmp` / `gif`。
非 PNG 格式会自动用 ImageMagick（或 ffmpeg 兜底）转成 192×192 PNG 再打包。

```bash
apk-builder.sh build MyApp app ~/icon.png
apk-builder.sh build MyApp app ~/icon.jpg
apk-builder.sh build MyApp app ~/icon.ico
apk-builder.sh build MyApp app ~/icon.icon
apk-builder.sh build MyApp app ~/icon.webp
```

转换工具（二选一，推荐 ImageMagick）：
```bash
pkg install imagemagick
# 或
pkg install ffmpeg
```

## 注意事项

- **Java 项目**：默认生成 XML 布局 + Java 代码，可自由修改
- **HTML 项目**：网页放 `assets/`，默认带 `INTERNET` 权限
- APK 需 Android 5.0+ (API 21+)，目标 SDK 36
- 使用调试密钥签名，适合开发测试

## 依赖说明

| 工具 | 用途 | 安装命令 |
|------|------|----------|
| java | 编译 Java | `pkg install openjdk-17` |
| aapt2 / d8 / zipalign / apksigner | 编译打包签名 | `pkg install android-sdk-build-tools` |
| keytool | 生成密钥 | 随 Java |
| termux-api | 管理器依赖 | `pkg install termux-api` |
| jq | 解析 JSON | `pkg install jq` |
| imagemagick | 非 PNG 图标转换 | `pkg install imagemagick` |

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

### Q: 不指定图标显示什么？
A: 系统默认机器人图标。旧版本会显示紫色方块。现今版本应为机器人。

### Q: 图标是 .jpg / .ico / .icon 能用吗？
A: 可以。builder 会自动转成 192×192 PNG。前提是装了 ImageMagick：

```bash
pkg install imagemagick
```

没装的话会退到 ffmpeg；两个都没有则报错。用 `.icon` 时如果实际不是图片，会报转换失败 —— 这种情况请自行换成 png/ico。

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

### Q: 管理器弹窗里点了"取消"没反应？
A: 已修复。取消会正确中止当前操作并回到主菜单，不再用默认值继续创建/编译。

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

---
<a id="english"></a>

# Termux APK Builder

A toolkit for building Android APKs directly in Termux. Android 16 compatible, with custom app icon support.

Two scripts are included:

- **`apk-builder.sh`** — CLI builder (init, build, sign)
- **`apk-manager.sh`** — Termux:API based GUI manager (dialog menus)

Two project types:

- **Java project** — generates XML layout + Java code, freely editable
- **HTML to APK** — wraps a web page into an APK using WebView

## Quick Start

### 1. Install dependencies

```bash
pkg update
pkg install openjdk-17 apksigner imagemagick
pkg install android-sdk-build-tools   # provides aapt2 / d8
# install zipalign
curl -s https://raw.githubusercontent.com/rendiix/rendiix.github.io/master/install-repo.sh | bash
pkg install zipalign
# if the package cannot be found
#apt install
```

### 2. Get the tools

**Option A: clone the full repo (includes android.jar)**

```bash
git clone https://github.com/alice-bluearchive/java_to_apk.git
cd java_to_apk
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

**Option B: download the script only (not recommended)**

```bash
mkdir -p ~/tools
curl -L -o ~/tools/apk-builder.sh \
  https://github.com/alice-bluearchive/java_to_apk/releases/latest/download/apk-builder.sh
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
# place android.jar into ~/android-sdk/android-34/
```

**For the GUI manager, also install:**

```bash
cp tools/apk-manager.sh ~/tools/
chmod +x ~/tools/apk-manager.sh
pkg install termux-api jq
# also install the Termux:API app from F-Droid
```

### 3. Build an APK

**Java project:**

```bash
apk-builder.sh init MyApp com.example.myapp MyApp
apk-builder.sh build MyApp                    # default icon
apk-builder.sh build MyApp app ~/icon.png     # custom icon
termux-open MyApp/build/app.apk
```

**HTML to APK:**

```bash
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp ~/page.html
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp ~/MySite
apk-builder.sh build MyWebApp
termux-open MyWebApp/build/app.apk
```

## Directory Layout

```
java_to_apk/
├── android-sdk/
│   └── android-34/
│       └── android.jar          # Android framework classes
├── tools/
│   ├── apk-builder.sh           # CLI builder
│   └── apk-manager.sh           # GUI manager
├── example/                     # sample projects
└── README.md
```

## GUI Manager (apk-manager.sh)

Built on **Termux:API**, manage projects through dialog menus — no commands to remember.

### Dependencies

```bash
pkg install termux-api jq
```

⚠️ You also need the **Termux:API** app installed from **F-Droid**.

### Usage

```bash
~/tools/apk-manager.sh          # open menu
~/tools/apk-manager.sh new      # create project
~/tools/apk-manager.sh open     # open / edit project
~/tools/apk-manager.sh build    # build APK
~/tools/apk-manager.sh del      # delete project
~/tools/apk-manager.sh check    # check dependencies
```

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `APK_BUILDER_SCRIPT` | `$HOME/tools/apk-builder.sh` | path to the builder script |
| `APK_BUILDER_HOME` | `$HOME/apk-projects` | where projects are stored |

> Temporary files are written to `$TMPDIR` (built into Termux). Do not use `/tmp` — it does not exist on Termux.

### Features

- **New project** — choose type, enter name / package / app name
- **Open project** — lists `.java` / `.html` files; edit with vi, open externally, or preview
- **Build APK** — enter output name and optional icon; notification when done, install directly
- **Delete project** — requires confirmation
- **Check dependencies** — calls the builder's `check`

### Behavior

Pressing **Cancel** in any dialog aborts the current action and returns to the main menu — it will not continue with a default value.

## CLI Usage (apk-builder.sh)

```bash
apk-builder.sh init <dir> <package> <app-name>                 # init Java project
apk-builder.sh init -web <dir> <package> <app-name> [html]     # init HTML project
apk-builder.sh build <dir> [output-name] [icon]                # build
apk-builder.sh clean <dir>                                     # clean
apk-builder.sh check                                           # check dependencies
apk-builder.sh help                                            # help
```

## Build Pipeline
1. **aapt2 compile** — compile resources to .flat
2. **aapt2 link** — link resources and generate R.java
3. **javac** — compile Java
4. **d8** — convert to DEX
5. **zipalign** — align the APK
6. **apksigner** — sign the APK

## HTML to APK

`init -web` generates a `WebView` container project. Web assets go into `assets/`, loaded via `file:///android_asset/index.html`. `INTERNET` permission included by default.

### Project layout

```
MyWebApp/
├── assets/index.html           # entry page
├── src/com/example/webapp/
│   └── MainActivity.java       # WebView container
├── res/values/strings.xml
└── AndroidManifest.xml
```

### `[html]` argument

| Input | Behavior |
|-------|----------|
| **omitted** | generates a default `assets/index.html` |
| **file** | copied as `assets/index.html` |
| **directory** | copied entirely into `assets/`; **must contain `index.html`** |

## Custom App Icon

**If no icon is given, the Android default icon (green robot) is used.**

Supported formats: `png` / `jpg` / `jpeg` / `ico` / `icon` / `webp` / `bmp` / `gif`.
Non-PNG formats are converted to 192×192 PNG via ImageMagick (or ffmpeg as a fallback) before packaging.

```bash
apk-builder.sh build MyApp app ~/icon.png
apk-builder.sh build MyApp app ~/icon.jpg
apk-builder.sh build MyApp app ~/icon.ico
apk-builder.sh build MyApp app ~/icon.icon
apk-builder.sh build MyApp app ~/icon.webp
```

Conversion tools (pick one; ImageMagick recommended):

```bash
pkg install imagemagick
# or
pkg install ffmpeg
```

## Notes

- **Java project**: default XML layout + Java code, freely editable
- **HTML project**: web assets live in `assets/`; `INTERNET` permission included
- Requires Android 5.0+ (API 21+), targets SDK 36
- Signed with a debug keystore — suitable for development and testing

## Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| java | compile Java | `pkg install openjdk-17` |
| aapt2 / d8 / zipalign / apksigner | build / package / sign | `pkg install android-sdk-build-tools` |
| keytool | generate keystore | bundled with Java |
| termux-api | GUI manager | `pkg install termux-api` |
| jq | parse JSON | `pkg install jq` |
| imagemagick | convert non-PNG icons | `pkg install imagemagick` |

## FAQ

### Q: Install fails with "There was a problem parsing the package"
A: Make sure you built with aapt2, not the old aapt.

### Q: Where is the APK?
A: In the project's `build/` directory, full path:
`/data/data/com.termux/files/home/MyApp/build/app.apk`

### Q: How do I copy the APK to Downloads?
```bash
cp MyApp/build/app.apk ~/storage/downloads/
```

### Q: What icon shows when none is specified?
A: The system default robot icon. Older versions showed a purple square; current versions show the robot.

### Q: Can I use a .jpg / .ico / .icon as the icon?
A: Yes. The builder converts it to a 192×192 PNG automatically, provided ImageMagick is installed:

```bash
pkg install imagemagick
```

If ImageMagick is missing it falls back to ffmpeg; if both are missing it errors out. A `.icon` that isn't actually an image will fail conversion — replace it with a png/ico.

### Q: The custom icon still shows the default robot
A: Two possibilities:
1. Launcher cache — uninstall then reinstall:
   ```bash
   pm uninstall com.example.myapp
   termux-open MyApp/build/app.apk
   ```
2. Icon wasn't packaged — verify:
   ```bash
   unzip -l MyApp/build/app.apk | grep ic_launcher
   ```

### Q: Can't find my image under /sdcard/
A: After `termux-setup-storage`, use `~/storage/shared/` instead.

### Q: apk-manager dialogs don't show up
A: Both are required:
1. In Termux: `pkg install termux-api`
2. On the phone: install the **Termux:API** app from F-Droid

### Q: Cancelling a dialog in the manager does nothing?
A: Fixed. Cancel now aborts the current action and returns to the main menu — it no longer continues with default values.

### Q: HTML shows a blank page
A: 1) The entry file must be named `index.html`; 2) verify packaging with `unzip -l MyWebApp/build/app.apk | grep assets`; 3) WebView supports JS and localStorage by default.

## License

MIT License

---

## Easter Egg

BanG Dream! — I'm **Tendou Alice**!

Alice turned both Java and HTML into .apk files in Termux. Sensei, praise me!

**If you have questions or suggestions, feel free to open an Issue!**

---

> Tendou Alice | 2026.09.19
>
> "The starting point of all miracles"