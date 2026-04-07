#!/bin/sh
# ========================================
# API: 网络模式切换
# POST /ruijie-cgi/mode
# body: {"operator":"DianXin"|"LianTong"}
# ========================================

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
. "${SCRIPT_DIR}/lib/network.sh" 2>/dev/null

# 读取 POST body
CONTENT_LENGTH="${CONTENT_LENGTH:-0}"
_body=""
if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    read -n "$CONTENT_LENGTH" _body 2>/dev/null || true
fi

_operator=$(echo "$_body" | grep -oE '"operator"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"operator"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

if [ "$_operator" != "DianXin" ] && [ "$_operator" != "LianTong" ]; then
    printf '{"success":false,"message":"运营商参数无效，请使用 DianXin 或 LianTong"}'
    exit 0
fi

# 读取配置
load_config

# 更新 OPERATOR 到配置文件
_cfg_tmp=$(mktemp)
if sed "s/^OPERATOR=.*/OPERATOR=$_operator/" "$CONFIG_FILE" > "$_cfg_tmp" 2>/dev/null; then
    mv "$_cfg_tmp" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
else
    rm -f "$_cfg_tmp"
    printf '{"success":false,"message":"无法写入配置文件"}'
    exit 0
fi

# 立即重新认证
export OPERATOR="$_operator"
_result=false
if do_login "$USERNAME" "$PASSWORD" "$ACCOUNT_TYPE" >/dev/null 2>&1; then
    _result=true
fi

if [ "$_result" = true ]; then
    printf '{"success":true,"message":"已切换到%s，网络已连接","operator":"%s"}' "$_operator" "$_operator"
else
    printf '{"success":true,"message":"运营商已切换为%s，认证稍后由守护进程自动完成","operator":"%s"}' "$_operator" "$_operator"
fi
