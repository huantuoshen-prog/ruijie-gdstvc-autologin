#!/bin/sh
# ========================================
# API: 系统设置
# GET  /ruijie-cgi/settings  → 读取代理设置
# POST /ruijie-cgi/settings  → 保存代理设置
# ========================================

# 纯 shell URL 解码（无需 python3）
urldecode() {
    printf '%s' "$1" | sed '
        s/%20/ /g; s/%21/!/g; s/%23/#/g; s/%24/$/g
        s/%26/\&/g; s/%27/'"'"'/g; s/%28/(/g; s/%29/)/g
        s/%2B/+/g; s/%2C/,/g; s/%2F/\//g; s/%3A/:/g
        s/%3B/;/g; s/%3D/=/g; s/%3F/?/g; s/%40/@/g
        s/%5B/[/g; s/%5D/]/g
        s/%0A//g; s/%0D//g
    '
}

echo "Content-Type: application/json; charset=utf-8"
echo ""

if [ -f /etc/ruijie/ruijie.sh ]; then
    SCRIPT_DIR="/etc/ruijie"
elif [ -f /root/ruijie/ruijie.sh ]; then
    SCRIPT_DIR="/root/ruijie"
else
    printf '{"success":false,"message":"锐捷脚本未安装"}'
    exit 0
fi

. "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null
. "${SCRIPT_DIR}/lib/config.sh" 2>/dev/null

METHOD="${REQUEST_METHOD:-GET}"

if [ "$METHOD" = "POST" ]; then
    CONTENT_LENGTH="${CONTENT_LENGTH:-0}"
    _body=""
    [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null && read -n "$CONTENT_LENGTH" _body 2>/dev/null || true

    _proxy_raw=$(echo "$_body" | sed -n 's/.*proxy_url=\([^&]*\).*/\1/p')
    _proxy_https_raw=$(echo "$_body" | sed -n 's/.*proxy_url_https=\([^&]*\).*/\1/p')

    _proxy=$(urldecode "$_proxy_raw")
    _proxy_https=$(urldecode "$_proxy_https_raw")

    _cfg_tmp=$(mktemp)
    if [ -f "$CONFIG_FILE" ]; then
        sed -e "s|^PROXY_URL=.*|PROXY_URL=$_proxy|" \
            -e "s|^PROXY_URL_HTTPS=.*|PROXY_URL_HTTPS=$_proxy_https|" \
            "$CONFIG_FILE" > "$_cfg_tmp" 2>/dev/null && mv "$_cfg_tmp" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE" 2>/dev/null
        printf '{"success":true,"message":"设置已保存"}'
    else
        rm -f "$_cfg_tmp"
        printf '{"success":false,"message":"配置文件不存在，请先配置账号"}'
    fi
else
    load_config
    _pe=$(echo "${PROXY_URL:-}"     | sed 's/"/\\"/g; s/</\\u003c/g; s/>/\\u003e/g')
    _phe=$(echo "${PROXY_URL_HTTPS:-}" | sed 's/"/\\"/g; s/</\\u003c/g; s/>/\\u003e/g')
    printf '{"proxy_url":"%s","proxy_url_https":"%s"}' "$_pe" "$_phe"
fi
