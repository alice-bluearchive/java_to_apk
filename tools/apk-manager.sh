#!/data/data/com.termux/files/usr/bin/bash
# apk-manager.sh — Termux:API APK 项目管理器
# 依赖: pkg install termux-api jq ; ~/tools/apk-builder.sh

BUILDER="${APK_BUILDER_SCRIPT:-$HOME/tools/apk-builder.sh}"
BASE="${APK_BUILDER_HOME:-$HOME/apk-projects}"
DLG_TEXT=""

for c in termux-dialog termux-toast termux-notification; do
    command -v "$c" >/dev/null || { echo "缺 $c: pkg install termux-api"; exit 1; }
done
[ -f "$BUILDER" ] || { echo "找不到 $BUILDER"; exit 1; }
mkdir -p "$BASE"

# 解析 termux-dialog 的 JSON，结果放 DLG_TEXT
# 注意: 返回 code 不可靠 (-1 / 0 / -2 都可能出现在成功场景)，一律以 text 为准
_dlg(){
    local out
    out=$("$@" 2>/dev/null)
    DLG_TEXT=""
    if command -v jq >/dev/null 2>&1; then
        DLG_TEXT=$(printf %s "$out" | jq -r '.text // ""' 2>/dev/null)
    else
        DLG_TEXT=$(printf %s "$out" \
            | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
        DLG_TEXT=$(printf '%b' "$DLG_TEXT")
    fi
}

# 单选/底部菜单: text 非空视为选中
ask_sheet(){ _dlg termux-dialog sheet -t "$1" -v "$2"; [ -n "$DLG_TEXT" ] || return 1; echo "$DLG_TEXT"; }
ask_radio(){ _dlg termux-dialog radio -t "$1" -v "$2"; [ -n "$DLG_TEXT" ] || return 1; echo "$DLG_TEXT"; }

# 输入框: 空则回退默认值
ask(){ local d="${2:-}"; _dlg termux-dialog text -t "$1" -i "$d"; [ -n "$DLG_TEXT" ] && echo "$DLG_TEXT" || echo "$d"; }

# 输入框: 允许空 (可选路径)
ask_raw(){ _dlg termux-dialog text -t "$1" -i "${2:-}"; echo "$DLG_TEXT"; }

# 确认框: 只有 text=="yes" 才算确认
ask_ok(){ _dlg termux-dialog confirm -t "$1" -i "$2"; [ "$DLG_TEXT" = yes ]; }

# 首次运行提示存储授权
if [ ! -d "$HOME/storage" ]; then
    termux-notification --title "APK Builder" \
        --content "建议先在 Termux 里跑: termux-setup-storage" 2>/dev/null
fi

pick(){
    local l=() d c
    while IFS= read -r d; do l+=("$(basename "$d")"); done \
        < <(find "$BASE" -mindepth 1 -maxdepth 1 -type d|sort)
    [ ${#l[@]} -eq 0 ] && { termux-toast "没有项目"; return 1; }
    c=$(ask_radio "选择项目" "$(IFS=,; echo "${l[*]}")") || return 1
    [ -z "$c" ] && return 1
    echo "$BASE/$c"
}

new_p(){
    local t n p a h rc=0
    t=$(ask_radio "项目类型" "HTML 应用,Java 应用") || return
    n=$(ask "项目名" "myapp") || return
    echo "$n" | grep -qE '^[A-Za-z0-9_-]+$' || { termux-toast "名字不合法"; return; }
    p=$(ask "包名" "com.example.$n") || return
    a=$(ask "应用名" "$n") || return
    [ -d "$BASE/$n" ] && { termux-toast "已存在: $n"; return; }
    cd "$BASE" || return
    if [ "$t" = "HTML 应用" ]; then
        h=$(ask_raw "HTML 路径(可空)" "$HOME/storage/shared/Download/index.html")
        if [ -n "$h" ] && [ -e "$h" ]; then
            bash "$BUILDER" init -web "$n" "$p" "$a" "$h" || rc=1
        else
            bash "$BUILDER" init -web "$n" "$p" "$a" || rc=1
        fi
    else
        bash "$BUILDER" init "$n" "$p" "$a" || rc=1
    fi
    [ $rc -eq 0 ] && termux-toast "✓ $n 已创建" || termux-toast "创建失败"
}

open_p(){
    local dir f=() c p act x
    dir=$(pick) || return
    while IFS= read -r x; do f+=("${x#$dir/}"); done \
        < <(find "$dir" -type f \( -name '*.java' -o -name '*.html' \) \
            -not -path '*/build/*'|sort)
    [ ${#f[@]} -eq 0 ] && { termux-toast "没有 .java/.html"; return; }
    c=$(ask_sheet "$(basename "$dir")" "$(IFS=,; echo "${f[*]}")") || return
    [ -z "$c" ] && return
    p="$dir/$c"
    [ -f "$p" ] || { termux-toast "不存在"; return; }
    act=$(ask_radio "打开方式" "编辑 (vi),外部打开,预览") || return
    case "$act" in
        编辑*) vi "$p" ;;
        外部*) termux-open "$p" ;;
        预览*) termux-dialog text -m -t "$c" -i "$(head -c 4000 "$p")" >/dev/null ;;
    esac
}

build_p(){
    local dir o ic apk
    dir=$(pick) || return
    o=$(ask "输出名" "app") || return
    ic=$(ask_raw "图标 PNG (可空)" "$HOME/storage/shared/Download/icon.png")
    apk="$dir/build/$o.apk"; rm -f "$apk"
    termux-toast "编译 $o ..."
    if [ -n "$ic" ] && [ -f "$ic" ]; then
        bash "$BUILDER" build "$dir" "$o" "$ic"
    else
        bash "$BUILDER" build "$dir" "$o"
    fi
    if [ -f "$apk" ]; then
        termux-notification --title "编译成功" --content "$o.apk" --priority high 2>/dev/null
        ask_ok "完成" "安装 $o.apk ?" && termux-open "$apk"
    else
        termux-notification --title "编译失败" --content "看终端输出" --priority high 2>/dev/null
        termux-toast "编译失败"
    fi
}

del_p(){
    local dir n
    dir=$(pick) || return
    n=$(basename "$dir")
    ask_ok "删除" "确定删除 $n ?" && rm -rf "$dir" && termux-toast "✓ 已删除"
}

menu(){
    while :; do
        local c
        c=$(ask_sheet "APK Builder" \
            "新建项目,打开项目,生成 APK,删除项目,检查依赖,退出") || break
        case "$c" in
            新建*) new_p ;;
            打开*) open_p ;;
            生成*) build_p ;;
            删除*) del_p ;;
            检查*) bash "$BUILDER" check; read -n1 -rp "回车继续..." _ ;;
            *) break ;;
        esac
    done
}

case "${1:-}" in
    new)   new_p ;;
    open)  open_p ;;
    build) build_p ;;
    del)   del_p ;;
    check) bash "$BUILDER" check ;;
    *)     menu ;;
esac
