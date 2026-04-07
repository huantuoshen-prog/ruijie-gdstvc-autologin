#!/bin/sh
# ========================================
# API: 获取系统状态
# GET /ruijie-cgi/status
# ========================================

# 设置字符编码
echo "Content-Type: application/json; charset=utf-8"
echo ""

# 查找 ruijie 脚本路径
if [ -f /etc/ruijie/ruijie.sh ]; then
    SCRIPT_DIR="/etc/ruijie"
elif [ -f /root/ruijie/ruijie.sh ]; then
    SCRIPT_DIR="/root/ruijie"
else
    # 未安装
    printf '{"installed":false,"online":false,"message":"锐捷脚本未安装，请先运行安装脚本"}'
    exit 0
fi

# 加载已有模块
. "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null
. "${SCRIPT_DIR}/lib/config.sh" 2>/dev/null
. "${SCRIPT_DIR}/lib/daemon.sh" 2>/dev/null
. "${SCRIPT_DIR}/lib/network.sh" 2>/dev/null

# 加载配置
load_config

# 获取网络状态
online=false
if check_network 2>/dev/null; then
    online=true
fi

# 获取守护进程状态
daemon_running=false
daemon_pid=""
daemon_uptime=""
daemon_state=""
if daemon_is_running 2>/dev/null; then
    daemon_running=true
    daemon_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$daemon_pid" ]; then
        # 计算运行时间
        _start=$(ps -o lstart= -p "$daemon_pid" 2>/dev/null)
        if [ -n "$_start" ]; then
            _now=$(date +%s)
            _then=$(date -d "$_start" +%s 2>/dev/null || echo "$_now")
            _diff=$((_now - _then))
            if [ "$_diff" -gt 0 ]; then
                if [ "$_diff" -lt 60 ]; then
                    daemon_uptime="${_diff}秒"
                elif [ "$_diff" -lt 3600 ]; then
                    daemon_uptime="$((_diff / 60))分钟"
                else
                    daemon_uptime="$((_diff / 3600))小时$(((_diff % 3600) / 60))分钟"
                fi
            fi
        fi
    fi
    # 读取状态机状态
    if [ -f /var/run/ruijie-daemon.state ]; then
        daemon_state=$(cat /var/run/ruijie-daemon.state 2>/dev/null)
    fi
fi

# 获取上次认证时间
last_auth=""
if _last=$(get_last_auth_time 2>/dev/null); then
    last_auth="$_last"
fi

# 输出 JSON
printf '{"installed":true,'
printf '"online":%s,' "$online"
printf '"username":"%s",' "${USERNAME:-}"
printf '"operator":"%s",' "${OPERATOR:-DianXin}"
printf '"account_type":"%s",' "${ACCOUNT_TYPE:-student}"
printf '"daemon_running":%s,' "$daemon_running"
printf '"daemon_pid":"%s",' "${daemon_pid:-}"
printf '"daemon_uptime":"%s",' "${daemon_uptime:-}"
printf '"daemon_state":"%s",' "${daemon_state:-}"
printf '"last_auth":"%s",' "${last_auth:-}"
printf '"version":"%s",' "${RUIJIE_VERSION:-3.1}"
printf '"message":""}'
