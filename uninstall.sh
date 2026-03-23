#!/bin/bash
# ========================================
# 卸载脚本
# 移除锐捷认证脚本、配置、守护进程
# ========================================

set -e

# 配置路径
DAEMON_SCRIPT="/usr/local/bin/ruijie.sh"
SYSTEMD_SERVICE="/etc/systemd/system/ruijie.service"
CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
PIDFILE="/var/run/ruijie-daemon.pid"
LOGFILE="/var/log/ruijie-daemon.log"

echo ""
echo "=========================================="
echo "  锐捷网络认证助手 - 卸载"
echo "=========================================="
echo ""

# 停止守护进程
echo "[1/5] 停止守护进程..."
if [ -f "$PIDFILE" ]; then
    _pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        kill "$_pid" 2>/dev/null && echo "  已停止 (PID $_pid)"
    fi
    rm -f "$PIDFILE"
fi
echo "  守护进程已停止"

# 禁用 systemd 服务
echo "[2/5] 移除 systemd 服务..."
if [ -f "$SYSTEMD_SERVICE" ]; then
    systemctl disable ruijie.service 2>/dev/null || true
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload 2>/dev/null || true
    echo "  已移除 systemd 服务"
else
    echo "  未找到 systemd 服务配置，跳过"
fi

# 移除脚本
echo "[3/5] 移除脚本文件..."
if [ -f "$DAEMON_SCRIPT" ]; then
    rm -f "$DAEMON_SCRIPT"
    echo "  已移除 $DAEMON_SCRIPT"
else
    echo "  未找到脚本文件，跳过"
fi

# 移除配置
echo "[4/5] 移除配置文件..."
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo "  已移除 $CONFIG_DIR"
else
    echo "  未找到配置文件，跳过"
fi

# 移除日志
echo "[5/5] 移除日志文件..."
if [ -f "$LOGFILE" ]; then
    rm -f "$LOGFILE"
    echo "  已移除 $LOGFILE"
else
    echo "  未找到日志文件，跳过"
fi

echo ""
echo "=========================================="
echo "  卸载完成！"
echo "=========================================="
echo ""
echo "已清理：守护进程、systemd 服务、脚本、配置、日志"
echo ""
