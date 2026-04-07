#!/bin/sh
# ========================================
# API: 守护进程控制
# POST /ruijie-cgi/daemon
# body: {"action":"start"|"stop"|"restart"}
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
. "${SCRIPT_DIR}/lib/daemon.sh" 2>/dev/null

# 读取 POST body
CONTENT_LENGTH="${CONTENT_LENGTH:-0}"
_body=""
if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    read -n "$CONTENT_LENGTH" _body 2>/dev/null || true
fi

_action=$(echo "$_body" | grep -oE '"action"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"action"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

case "$_action" in
    start)
        load_config
        if daemon_start >/dev/null 2>&1; then
            _pid=$(cat "$PIDFILE" 2>/dev/null)
            printf '{"success":true,"pid":"%s","message":"守护进程已启动"}' "$_pid"
        else
            printf '{"success":false,"message":"启动失败，守护进程可能已在运行"}'
        fi
        ;;
    stop)
        daemon_stop >/dev/null 2>&1
        printf '{"success":true,"message":"守护进程已停止"}'
        ;;
    restart)
        daemon_stop >/dev/null 2>&1
        sleep 1
        load_config
        if daemon_start >/dev/null 2>&1; then
            _pid=$(cat "$PIDFILE" 2>/dev/null)
            printf '{"success":true,"pid":"%s","message":"守护进程已重启"}' "$_pid"
        else
            printf '{"success":false,"message":"重启失败"}'
        fi
        ;;
    *)
        printf '{"success":false,"message":"未知操作，请使用 start/stop/restart"}'
        ;;
esac
