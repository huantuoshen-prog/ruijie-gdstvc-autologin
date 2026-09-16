#!/bin/bash
# ========================================
# 卸载脚本
# 移除锐捷认证脚本、配置、守护进程
# ========================================

set -e

# 解析参数
PURGE=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --purge|-p) PURGE=true ;;
        --force|-f) FORCE=true ;;
        --help|-h)
            echo "用法: $(basename "$0") [选项]"
            echo "选项:"
            echo "  --purge, -p   彻底清除（包括配置文件、账号信息和日志）"
            echo "  --force, -f   无需确认直接卸载"
            echo "  --help, -h    显示帮助"
            exit 0
            ;;
    esac
done

# 确认
if [ "$FORCE" != "true" ]; then
    echo ""
    echo "=========================================="
    echo "  锐捷网络认证助手 - 卸载"
    echo "=========================================="
    echo ""
    [ "$PURGE" = "true" ] && echo "将执行彻底清除（包含配置文件和账号信息）"
    echo ""
    echo -n "确认卸载？(y/N): "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
fi

echo ""
echo "=========================================="
echo "  锐捷网络认证助手 - 卸载"
echo "=========================================="
echo ""

# 检测平台
is_openwrt() {
    [ -f /etc/openwrt_release ] || command -v ubus >/dev/null 2>&1
}

# ========================================
# OpenWrt 路径定义
# ========================================
INIT_SCRIPT="/etc/init.d/ruijie"
CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
PIDFILE="/var/run/ruijie-daemon.pid"
LOCKFILE="/var/run/ruijie-daemon.lock"
LOGFILE="/var/log/ruijie-daemon.log"
STATE_FILE="/var/run/ruijie-daemon.state"
BACKOFF_FILE="/var/run/ruijie-daemon.backoff"

# OpenWrt 特有路径
OPENWRT_SCRIPT_DIR="/etc/ruijie"

# ========================================
# 停止守护进程
# ========================================
echo "[1/6] 停止守护进程..."
if [ -f "$PIDFILE" ]; then
    _pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        kill "$_pid" 2>/dev/null && echo "  已停止 (PID $_pid)"
        sleep 1
        kill -9 "$_pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
fi
# 通过 init.d 停止（OpenWrt）
for _svc in "$INIT_SCRIPT" "$INIT_SCRIPT2"; do
    [ -x "$_svc" ] && "$_svc" stop 2>/dev/null || true
done
echo "  守护进程已停止"

# ========================================
# 禁用服务
# ========================================
echo "[2/6] 禁用服务..."
# OpenWrt init.d
[ -f "$INIT_SCRIPT" ] && "$INIT_SCRIPT" disable 2>/dev/null || true
[ -f "$INIT_SCRIPT" ] && rm -f "$INIT_SCRIPT" && echo "  已移除 $INIT_SCRIPT"

# ========================================
# 移除脚本文件
# ========================================
echo "[3/6] 移除脚本文件..."
# OpenWrt
[ -d "$OPENWRT_SCRIPT_DIR" ] && rm -rf "$OPENWRT_SCRIPT_DIR" && echo "  已移除 $OPENWRT_SCRIPT_DIR"

# ========================================
# 移除配置文件（--purge 时）
# ========================================
echo "[4/6] 移除配置文件..."
if [ "$PURGE" = "true" ]; then
    [ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR" && echo "  已移除 $CONFIG_DIR"
    echo "  配置文件已彻底清除"
else
    echo "  保留配置文件（运行 --purge 可彻底清除）"
fi

# ========================================
# 移除运行状态文件
# ========================================
echo "[5/6] 移除运行时文件..."
for _f in "$PIDFILE" "$LOCKFILE" "$STATE_FILE" "$BACKOFF_FILE" "$LOGFILE"; do
    [ -f "$_f" ] && rm -f "$_f" && echo "  已移除 $_f"
done

echo "[6/6] 未修改 cron 或 rc.local（本版本不使用它们）"

echo ""
echo "=========================================="
echo "  卸载完成！"
echo "=========================================="
echo ""

if [ "$PURGE" = "true" ]; then
    echo "已彻底清除：守护进程、脚本、配置、账号和日志"
else
    echo "已清除：守护进程、脚本、服务和日志"
    echo "已保留：配置文件（账号信息）"
fi
echo ""
echo "如需重新安装，请使用 GitHub Release 中带校验值的完整发布包"
echo ""
