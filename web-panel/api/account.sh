#!/bin/sh
# ========================================
# API: 账号管理
# GET  /ruijie-cgi/account  → 读取账号信息
# POST /ruijie-cgi/account  → 保存账号信息
# ========================================

# 纯 shell URL 解码（无需 python3，兼容 OpenWrt）
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

# 查找 ruijie 脚本路径
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

    # 解析字段（application/x-www-form-urlencoded）
    _username_raw=$(echo "$_body" | sed -n 's/.*username=\([^&]*\).*/\1/p')
    _password_raw=$(echo "$_body" | sed -n 's/.*password=\([^&]*\).*/\1/p')
    _operator_raw=$(echo "$_body" | sed -n 's/.*operator=\([^&]*\).*/\1/p')

    _username=$(urldecode "$_username_raw")
    _password=$(urldecode "$_password_raw")
    _operator=$(urldecode "$_operator_raw")

    if [ -z "$_username" ] || [ -z "$_password" ]; then
        printf '{"success":false,"message":"用户名和密码不能为空"}'
        exit 0
    fi

    # 保存配置
    save_config "$_username" "$_password" "${ACCOUNT_TYPE:-student}"
    fix_config_perms

    # 更新 OPERATOR
    if [ -n "$_operator" ]; then
        _cfg_tmp=$(mktemp)
        if sed "s/^OPERATOR=.*/OPERATOR=$_operator/" "$CONFIG_FILE" > "$_cfg_tmp" 2>/dev/null; then
            mv "$_cfg_tmp" "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"
        else
            rm -f "$_cfg_tmp"
        fi
    fi

    printf '{"success":true,"message":"账号已保存"}'
else
    # GET: 读取（密码脱敏）
    load_config
    _len=${#PASSWORD}
    _masked=""
    _i=0
    while [ "$_i" -lt "$_len" ]; do _masked="${_masked}*"; _i=$((_i+1)); done

    _pu_esc=$(echo "${PROXY_URL:-}" | sed 's/"/\\"/g; s/</\\u003c/g; s/>/\\u003e/g')

    printf '{"username":"%s","password":"%s","operator":"%s","account_type":"%s","proxy_url":"%s"}' \
        "${USERNAME:-}" "$_masked" "${OPERATOR:-DianXin}" "${ACCOUNT_TYPE:-student}" "$_pu_esc"
fi
