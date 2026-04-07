#!/bin/sh
# ========================================
# API: 日志查看
# GET /ruijie-cgi/log
#   ?lines=200  → 控制返回行数（默认200）
#   ?level=ERROR → 按级别过滤
# ========================================

# XSS 安全转义：< > " 转为 Unicode 转义
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/</\\u003c/g; s/>/\\u003e/g'
}

# 解析查询参数
_lines=200
_level=""
if [ -n "${QUERY_STRING:-}" ]; then
    _l=$(echo "$QUERY_STRING" | sed -n 's/.*lines=\([0-9]*\).*/\1/p')
    [ -n "$_l" ] && _lines="$_l"
    _lv=$(echo "$QUERY_STRING" | sed -n 's/.*level=\([A-Za-z]*\).*/\1/p')
    [ -n "$_lv" ] && _level="$_lv"
fi

_logfile="/var/log/ruijie-daemon.log"
if [ ! -f "$_logfile" ]; then
    printf '{"lines":[],"total":0}\n'
    exit 0
fi

# 用临时文件避免子 shell 变量丢失问题
_tmp=$(mktemp)
tail -n "$_lines" "$_logfile" 2>/dev/null > "$_tmp"

# 先统计过滤后行数
if [ -n "$_level" ]; then
    _count=$(grep -c "\[$_level\]" "$_tmp" 2>/dev/null || echo 0)
else
    _count=$(wc -l < "$_tmp" | tr -d ' ')
fi

# 输出 JSON
printf '{"lines":['
_first=true

while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue

    # 提取时间戳
    _ts=$(echo "$line" | sed -n 's/^\[\([0-9][0-9-]* [0-9:]*\)\].*/\1/p' | tr -d '[]')

    # 提取级别
    _lvl="INFO"
    case "$line" in
        *'[OK]'*)    _lvl="OK" ;;
        *'[WARN]'*)  _lvl="WARN" ;;
        *'[ERROR]'*) _lvl="ERROR" ;;
        *'[STEP]'*)  _lvl="STEP" ;;
    esac

    # 级别过滤
    [ -n "$_level" ] && [ "$_lvl" != "$_level" ] && continue

    # 提取消息（去掉 [时间] [级别] 前缀）
    _msg=$(echo "$line" | sed \
        -e 's/^\[[0-9][0-9-]* [0-9:]*\] \[INFO\] //' \
        -e 's/^\[[0-9][0-9-]* [0-9:]*\] \[OK\] //' \
        -e 's/^\[[0-9][0-9-]* [0-9:]*\] \[WARN\] //' \
        -e 's/^\[[0-9][0-9-]* [0-9:]*\] \[ERROR\] //' \
        -e 's/^\[[0-9][0-9-]* [0-9:]*\] \[STEP\] //')
    _msg_esc=$(json_escape "$_msg")

    [ "$_first" = true ] && _first=false || printf ','
    printf '{"ts":"%s","level":"%s","msg":"%s"}' "$_ts" "$_lvl" "$_msg_esc"
done < "$_tmp"

printf '],"total":%d}\n' "$_count"
rm -f "$_tmp"
