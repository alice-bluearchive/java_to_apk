# Termux APK Builder

在 Termux 终端中编译 Android APK 的工具集，兼容 Android 16，支持自定义应用图标。

支持两种项目类型：
- **Java 项目** —— 纯 Java 代码构建 UI
- **HTML 转 APK** —— 用 WebView 打包网页为 APK

## 快速开始

### 1. 安装依赖

```bash
pkg update
pkg install openjdk-17 apksigner dx zipalign imagemagick
# 1. 安装前置工具
pkg install -y gnupg wget
# 2. 添加第三方 APT 源
mkdir -p $PREFIX/etc/apt/sources.list.d
echo "deb https://rendiix.github.io android-tools termux" \
  > $PREFIX/etc/apt/sources.list.d/rendiix.list

# 3. 导入仓库 GPG 公钥
wget -qP $PREFIX/etc/apt/trusted.gpg.d https://rendiix.github.io/rendiix.gpg

# 4. 刷新并安装
pkg update
pkg install -y android-sdk-build-tools

# 5. 验证
aapt2 version
```

> `imagemagick` 只在你要转换图标格式时才需要，纯编译可不装。

### 2. 下载工具

```bash
git clone https://github.com/3453954723/termux-apk-builder.git
cd termux-apk-builder
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

### 3. 编译 APK

#### Java 项目

```bash
# 初始化项目
apk-builder.sh init MyApp com.example.myapp MyApp

# 编译（使用默认图标）
apk-builder.sh build MyApp

# 编译（指定自己的 PNG 图标）
apk-builder.sh build MyApp app ~/icon.png

# 安装
termux-open MyApp/build/app.apk
```

#### HTML 转 APK 项目

```bash
# 初始化（生成默认 index.html）
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp

# 或使用自己的 HTML 作为首页
apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp ~/index.html

# 编译
apk-builder.sh build MyWebApp

# 安装
termux-open MyWebApp/build/app.apk
```

## 目录结构

```
termux-apk-builder/
├── android-sdk/
│   └── android-34/
│       └── android.jar          # Android 框架类 （编译用）
├── tools/
│   └── apk-builder.sh           # 编译脚本
├── examples/
│   └── calculator.apk           # 示例计算器 App
└── README.md
```

## 编译脚本用法

```bash
apk-builder.sh init <项目目录> <包名> <应用名>                 # 初始化 Java 项目
apk-builder.sh init -web <项目目录> <包名> <应用名> [html]     # 初始化 HTML 转 APK 项目
apk-builder.sh build <项目目录> [输出名] [图标.png]            # 编译项目
apk-builder.sh clean <项目目录>                                # 清理构建文件
apk-builder.sh check                                           # 检查依赖
apk-builder.sh help                                            # 显示帮助
```

## 编译流程

1. **aapt2 compile** - 编译资源文件为 .flat 格式
2. **aapt2 link** - 链接资源并生成 R.java
3. **javac** - 编译 Java 代码
4. **d8 / dx** - 转换为 DEX 格式
5. **zipalign** - 优化 APK 对齐
6. **apksigner** - 签名 APK

## HTML 转 APK

`init -web` 会生成一个以 `WebView` 为容器的 Android 项目，网页文件放在 `assets/` 目录，编译后通过 `file:///android_asset/` 加载。

### 项目结构

```
MyWebApp/
├── assets/
│   └── index.html              # 网页文件（首页）
├── src/
│   └── com/example/webapp/
│       └── MainActivity.java   # WebView 容器
├── res/
│   └── mipmap/ic_launcher.png
└── AndroidManifest.xml
```

### 用法

- **`[html]` 参数可选**：不传时生成一个默认的 `index.html`；传入时会把指定的 HTML 文件复制为 `assets/index.html`
- **修改网页**：直接编辑 `assets/` 下的文件，重新 `build` 即可
- **引入 CSS / JS / 图片**：一起放进 `assets/`，用相对路径引用
- **需要联网**：在 `AndroidManifest.xml` 里加 `<uses-permission android:name="android.permission.INTERNET"/>`

### 示例：用自己的 HTML 初始化

```bash
# 手机上先授权存储
termux-setup-storage

apk-builder.sh init -web MyWebApp com.example.webapp MyWebApp \
  ~/storage/shared/MySite/index.html
```

## 自定义应用图标

`init` 时会自动在 `res/mipmap/` 下生成一个 1×1 的默认图标。想换成自己的图标，只需在 `build` 时把 PNG 路径作为第三个参数传入：

```bash
apk-builder.sh build MyApp app ~/icon.png
```

### 图标要求

- **必须是真正的 PNG 格式**，把 JPG/WebP 改后缀名是无效的，`aapt2` 会报：
  ```
  failed to read PNG signature
  ```
- 推荐尺寸 **192×192** 或 **512×512** 的正方形，带透明通道效果最好
- Termux 默认读不到 `/sdcard/`，先执行 `termux-setup-storage` 授权，
  然后用 `~/storage/shared/...` 路径访问手机文件

### 把 JPG 转成 PNG

如果手上只有 JPG，用 ImageMagick 转一下（顺便裁成正方形）：

```bash
termux-setup-storage
pkg install imagemagick
magick ~/storage/shared/Pictures/bili/1.png \
  -resize 512x512^ -gravity center -extent 512x512 ~/icon.png

file ~/icon.png   # 必须显示 PNG image data
```

## 注意事项

- **Java 项目**：UI 只能用纯 Java 代码创建，不能使用 XML 布局文件
- **HTML 项目**：网页文件放入 `assets/` 目录，通过 WebView 加载
- 生成的 APK 需要 Android 5.0+ (API 21+)
- 使用调试密钥签名，适合开发测试
- 自定义图标只支持 PNG，不支持 SVG / XML vector
- 安装 APK 需要使用 `termux-open` 或文件管理器

## 示例项目

`每次 init 初始化的项目都是一个可直接编译使用的项目`

## 依赖说明

| 工具 | 用途 | 安装命令 |
|------|------|----------|
| java | 编译 Java 代码 | `pkg install openjdk-17` |
| aapt2 | 编译资源文件 | `pkg install aapt2` |
| dx / d8 | 转换 DEX 格式 | `pkg install dx` |
| zipalign | 优化 APK | `pkg install zipalign` |
| apksigner | 签名 APK | `pkg install apksigner` |
| keytool | 生成密钥 | 随 Java 安装 |
| imagemagick | 转换图标格式（可选） | `pkg install imagemagick` |

## 常见问题

### Q: 安装 APK 时提示"解析安装包出现问题"
A: 确保使用 aapt2 编译，而不是旧版 aapt。

### Q: 如何在 MT 管理器中找到 APK？
A: APK 位于项目的 `build/` 目录下，完整路径如：
```
/data/data/com.termux/files/home/MyApp/build/app.apk
```

### Q: 如何复制 APK 到下载目录？
A: 使用命令：
```bash
cp MyApp/build/app.apk ~/storage/downloads/
```

### Q: 编译时报 "failed to read PNG signature"
A: 你的图标不是真正的 PNG。用 `file ~/icon.png` 查看真实格式，
如果是 JPEG 就用 `magick` 转成 PNG 再编译：
```bash
magick old.png new.png
```

### Q: 指定了图标，装完还是默认的安卓机器人
A: 两种情况：
1. 手机启动器缓存了旧图标 —— **先卸载旧版本，再重新安装**：
   ```bash
   pm uninstall com.example.myapp
   termux-open MyApp/build/app.apk
   ```
2. 图标没真正打进 APK，用这条命令确认：
   ```bash
   unzip -l MyApp/build/app.apk | grep ic_launcher
   ```
   看不到输出就说明 build 时图标没被复制。

### Q: 找不到 /sdcard/ 下的图片
A: Termux 默认没有存储权限。执行 `termux-setup-storage` 授权，
之后用 `~/storage/shared/` 代替 `/sdcard/`。

### Q: HTML 项目里的网页加载不出来 / 白屏
A: 检查几点：
1. 网页文件确实在 `assets/` 下，且文件名与加载路径一致
2. 用 `unzip -l MyWebApp/build/app.apk | grep assets` 确认文件被打包
3. 如果需要网络请求，`AndroidManifest.xml` 里是否加了 `INTERNET` 权限

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