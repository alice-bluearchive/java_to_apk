#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
ANDROID_SDK="/data/data/com.termux/files/home/android-sdk"
ANDROID_JAR="$ANDROID_SDK/android-34/android.jar"
DEBUG_KEYSTORE="$ANDROID_SDK/debug.keystore"

info(){ echo -e "${BLUE}[INFO]${NC} $1";}
success(){ echo -e "${GREEN}[OK]${NC} $1";}
error(){ echo -e "${RED}[ERROR]${NC} $1"; exit 1;}
step(){ echo -e "${CYAN}[$1/$2]${NC} $3";}

help(){
    echo "用法: $(basename "$0") <命令> [参数...]"
    echo ""
    echo "命令:"
    echo "  init   <目录> <包名> <应用名>              初始化 Java 项目"
    echo "  init -web <目录> <包名> <应用名> [html]    初始化 HTML 转 APK 项目"
    echo "  build  <目录> [输出名] [图标.png]          编译项目"
    echo "  clean  <目录>                            清理构建文件"
    echo "  check                                    检查依赖"
    echo "  help                                     显示帮助"
}

check(){
    local miss=0
    for c in java javac aapt2 d8 zipalign apksigner keytool; do
        if command -v "$c" >/dev/null 2>&1; then
            echo -e "${GREEN}[OK]${NC} $c"
        else
            echo -e "${RED}[MISS]${NC} $c"
            miss=1
        fi
    done
    [ $miss -eq 0 ] && success "依赖完整" || error "请先安装缺失的依赖"
}

apply_icon(){
    local d="$1" icon="$2"
    mkdir -p "$d/res/mipmap"
    if [ -n "$icon" ]; then
        [ -f "$icon" ] || error "图标文件不存在: $icon"
        cp -f "$icon" "$d/res/mipmap/ic_launcher.png"
        if ! grep -q 'android:icon="@mipmap/ic_launcher"' "$d/AndroidManifest.xml"; then
            sed -i 's|android:label="@string/app_name"|android:label="@string/app_name" android:icon="@mipmap/ic_launcher"|' "$d/AndroidManifest.xml"
        fi
        info "已应用自定义图标: $icon"
    else
        info "未指定图标，使用 Android 系统默认图标"
    fi
}

apk_is_signed(){
    local f="$1"
    # v1 签名：META-INF 下存在 .RSA/.DSA/.EC
    if unzip -l "$f" 2>/dev/null | grep -qE 'META-INF/.*\.(RSA|DSA|EC)'; then
        return 0
    fi
    # v2/v3 签名：文件内包含 APK 签名块魔数
    if grep -aq 'APK Sig Block 42' "$f"; then
        return 0
    fi
    return 1
}

init_project(){
    local web=0
    if [ "$1" = "-web" ]; then
        web=1
        shift
    fi

    local d="$1" p="$2" n="$3" html="$4"

    if [ "$web" -eq 1 ]; then
        [ -z "$d" ] || [ -z "$p" ] || [ -z "$n" ] && {
            echo "用法: $0 init -web <目录> <包名> <应用名> [html文件或目录]"
            exit 1
        }
    else
        [ -z "$d" ] || [ -z "$p" ] || [ -z "$n" ] && {
            echo "用法: $0 init <目录> <包名> <应用名>"
            exit 1
        }
    fi

    [ -d "$d" ] && error "目录已存在: $d"
    local pp=$(echo "$p" | tr '.' '/')

    if [ "$web" -eq 1 ]; then
        mkdir -p "$d"/{src/"$pp",res/{values,mipmap},assets,build}

        if [ -z "$html" ]; then
            info "未指定 HTML，使用默认页面"
            cat > "$d/assets/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>My Web App</title>
<style>
  body{margin:0;font-family:sans-serif;display:flex;align-items:center;
       justify-content:center;height:100vh;background:#f5f5f5;color:#333}
  .card{text-align:center;padding:32px}
  h1{font-size:24px;margin:0 0 12px}
  p{color:#666;margin:0 0 20px}
  button{padding:10px 24px;font-size:16px;border:none;border-radius:8px;
         background:#3b82f6;color:#fff}
</style>
</head>
<body>
<div class="card">
  <h1>Hello, WebView!</h1>
  <p>把 assets/index.html 换成你自己的页面即可。</p>
  <button onclick="alert('JS 正常工作')">点我</button>
</div>
</body>
</html>
HTML
        elif [ -d "$html" ]; then
            cp -r "$html"/. "$d/assets/"
            [ -f "$d/assets/index.html" ] || error "目录中缺少 index.html 作为入口"
            info "已复制网页文件到 assets/"
        elif [ -f "$html" ]; then
            cp -f "$html" "$d/assets/index.html"
            info "已复制网页文件到 assets/"
        else
            error "HTML 文件/目录不存在: $html"
        fi

        cat > "$d/AndroidManifest.xml" << 'M'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="PKG">
<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="36"/>
<uses-permission android:name="android.permission.INTERNET"/>
<application android:label="@string/app_name" android:theme="@android:style/Theme.Material.Light.DarkActionBar">
<activity android:name=".MainActivity" android:exported="true"
    android:configChanges="orientation|screenSize|keyboardHidden">
<intent-filter><action android:name="android.intent.action.MAIN"/>
<category android:name="android.intent.category.LAUNCHER"/></intent-filter>
</activity></application></manifest>
M
        sed -i "s/PKG/$p/" "$d/AndroidManifest.xml"

        cat > "$d/res/values/strings.xml" << S
<?xml version="1.0" encoding="utf-8"?>
<resources><string name="app_name">$n</string></resources>
S

        cat > "$d/src/$pp/MainActivity.java" << J
package $p;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebSettings;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
public class MainActivity extends Activity {
    private WebView wv;
    protected void onCreate(Bundle s) {
        super.onCreate(s);
        wv = new WebView(this);
        WebSettings ws = wv.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);
        ws.setAllowFileAccess(true);
        ws.setAllowContentAccess(true);
        ws.setLoadWithOverviewMode(true);
        ws.setUseWideViewPort(true);
        wv.setWebViewClient(new WebViewClient());
        wv.setWebChromeClient(new WebChromeClient());
        wv.loadUrl("file:///android_asset/index.html");
        setContentView(wv);
    }
    public void onBackPressed() {
        if (wv.canGoBack()) { wv.goBack(); } else { super.onBackPressed(); }
    }
}
J

        [ ! -f "$DEBUG_KEYSTORE" ] && keytool -genkey -v -keystore "$DEBUG_KEYSTORE" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Debug,O=Android,C=US" 2>/dev/null
        success "Web 项目 $n 初始化完成（入口: assets/index.html）"
        return
    fi

    mkdir -p "$d"/{src/"$pp",res/{layout,values,mipmap},build}
    cat > "$d/AndroidManifest.xml" << 'M'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="PKG">
<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="36"/>
<application android:label="@string/app_name" android:theme="@android:style/Theme.Material.Light.DarkActionBar">
<activity android:name=".MainActivity" android:exported="true">
<intent-filter><action android:name="android.intent.action.MAIN"/>
<category android:name="android.intent.category.LAUNCHER"/></intent-filter>
</activity></application></manifest>
M
    sed -i "s/PKG/$p/" "$d/AndroidManifest.xml"
    cat > "$d/res/layout/activity_main.xml" << 'L'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
android:layout_width="match_parent" android:layout_height="match_parent"
android:orientation="vertical" android:gravity="center" android:padding="24dp">
<TextView android:id="@+id/t" android:layout_width="wrap_content" android:layout_height="wrap_content"
android:text="@string/app_name" android:textSize="28sp"/>
<Button android:id="@+id/b" android:layout_width="wrap_content" android:layout_height="wrap_content"
android:text="Click" android:layout_marginTop="16dp"/>
</LinearLayout>
L
    cat > "$d/res/values/strings.xml" << S
<?xml version="1.0" encoding="utf-8"?>
<resources><string name="app_name">$n</string></resources>
S
    cat > "$d/src/$pp/MainActivity.java" << J
package $p;
import android.app.Activity;
import android.os.Bundle;
import android.widget.Button;
import android.view.View;
import android.widget.Toast;
public class MainActivity extends Activity{
protected void onCreate(Bundle s){
super.onCreate(s);
setContentView(R.layout.activity_main);
((Button)findViewById(R.id.b)).setOnClickListener(new View.OnClickListener(){
public void onClick(View v){
Toast.makeText(MainActivity.this,"Hi",0).show();
}});}}
J
    [ ! -f "$DEBUG_KEYSTORE" ] && keytool -genkey -v -keystore "$DEBUG_KEYSTORE" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Debug,O=Android,C=US" 2>/dev/null
    success "项目 $n 初始化完成"
}

build_project(){
    local dir="$1" out="${2:-app}" icon="$3"
    [ -z "$dir" ] && error "用法: $0 build <目录> [输出名] [图标.png]"
    [ ! -d "$dir" ] && error "目录不存在: $dir"
    if [ -n "$icon" ]; then
        [ -f "$icon" ] || error "图标文件不存在: $icon"
        icon="$(cd "$(dirname "$icon")" && pwd)/$(basename "$icon")"
    fi
    cd "$dir"
    apply_icon "." "$icon"
    rm -rf build && mkdir -p build/{classes,compiled_res,dex,gen}

    step 1 6 "编译资源"
    if [ -d res ] && [ -n "$(find res -type f 2>/dev/null)" ]; then
        aapt2 compile --dir res -o build/compiled_res/ || error "资源编译失败"
    fi

    step 2 6 "链接资源"
    local flats=$(ls build/compiled_res/*.flat 2>/dev/null)
    if [ -f assets/index.html ]; then
        aapt2 link -o build/app.apk -I "$ANDROID_JAR" \
            --manifest AndroidManifest.xml --java build/gen \
            --auto-add-overlay --min-sdk-version 21 --target-sdk-version 36 \
            -A assets \
            $flats || error "资源链接失败"
    else
        aapt2 link -o build/app.apk -I "$ANDROID_JAR" \
            --manifest AndroidManifest.xml --java build/gen \
            --auto-add-overlay --min-sdk-version 21 --target-sdk-version 36 \
            $flats || error "资源链接失败"
    fi

    step 3 6 "编译Java"
    find src build/gen -name "*.java" > build/src.txt
    javac --release 8 -Xlint:-options -Xlint:-deprecation -nowarn -cp "$ANDROID_JAR" -d build/classes @build/src.txt 2>/dev/null || error "Java编译失败"

    step 4 6 "转换DEX"
    d8 --min-api 21 --lib "$ANDROID_JAR" --classpath "$ANDROID_JAR" --output build/dex $(find build/classes -name "*.class") || error "DEX失败"

    step 5 6 "打包"
    cp build/app.apk build/u.apk
    cp build/dex/classes.dex build/classes.dex
    cd build && zip -u u.apk classes.dex && cd ..

    step 6 6 "签名"
    zipalign -f 4 build/u.apk build/a.apk
    apksigner sign --min-sdk-version 21 --ks "$DEBUG_KEYSTORE" --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out "build/$out.apk" build/a.apk || error "签名失败"
    rm -f build/u.apk build/a.apk build/classes.dex

    # 清理未签名 APK：通过 apk_is_signed 检测文件内是否有 v1 或 v2/v3 签名数据
    local final_apk="build/$out.apk"
    local f
    for f in build/*.apk; do
        [ -e "$f" ] || continue
        if apk_is_signed "$f"; then
            info "保留已签名 APK: $f"
        else
            rm -f "$f"
            info "已删除未签名 APK: $f"
        fi
    done

    [ -f "$final_apk" ] || error "最终 APK 未生成: $final_apk"
    success "完成! $final_apk"
}

clean_project(){ [ -z "$1" ] && error "用法: $0 clean <目录>"; rm -rf "$1/build"; success "清理完成";}

main(){
    case "$1" in
        init)  shift; init_project "$@";;
        build) shift; build_project "$@";;
        clean) shift; clean_project "$@";;
        check) check;;
        help|--help|-h) help;;
        *) help;;
    esac
}
main "$@"
