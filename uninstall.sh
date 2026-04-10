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
            echo "  --purge, -p   彻底清除（包括配置文件、账号信息、日志、rc.local）"
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
# 路径定义（覆盖 OpenWrt + 普通 Linux 所有可能位置）
# ========================================
SYSTEMD_SERVICE="/etc/systemd/system/ruijie.service"
SYSTEMD_SERVICE2="/lib/systemd/system/ruijie.service"
INIT_SCRIPT="/etc/init.d/ruijie"
INIT_SCRIPT2="/etc/init.d/ruijie-panel"
CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
PIDFILE="/var/run/ruijie-daemon.pid"
LOCKFILE="/var/run/ruijie-daemon.lock"
LOGFILE="/var/log/ruijie-daemon.log"
STATE_FILE="/var/run/ruijie-daemon.state"
BACKOFF_FILE="/var/run/ruijie-daemon.backoff"

# OpenWrt 特有路径
OPENWRT_SCRIPT_DIR="/etc/ruijie"
OPENWRT_ACTIVE_DIR="/root/ruijie"

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
# systemd
for _svc in "$SYSTEMD_SERVICE" "$SYSTEMD_SERVICE2"; do
    [ -f "$_svc" ] && systemctl disable ruijie 2>/dev/null || true
    [ -f "$_svc" ] && rm -f "$_svc" && echo "  已移除 $_svc"
done
systemctl daemon-reload 2>/dev/null || true
# OpenWrt init.d
for _svc in "$INIT_SCRIPT" "$INIT_SCRIPT2"; do
    [ -f "$_svc" ] && "$_svc" disable 2>/dev/null || true
    [ -f "$_svc" ] && rm -f "$_svc" && echo "  已移除 $_svc"
done
# rc.local 开机同步清理（OpenWrt）
if [ -f /etc/rc.local ] && grep -q "ruijie" /etc/rc.local 2>/dev/null; then
    sed -i '/ruijie/d' /etc/rc.local 2>/dev/null
    echo "  已清理 /etc/rc.local 中的 ruijie 启动项"
fi

# ========================================
# 移除脚本文件
# ========================================
echo "[3/6] 移除脚本文件..."
# OpenWrt
for _dir in "$OPENWRT_SCRIPT_DIR" "$OPENWRT_ACTIVE_DIR"; do
    [ -d "$_dir" ] && rm -rf "$_dir" && echo "  已移除 $_dir"
done
# 普通 Linux
[ -f "/usr/local/bin/ruijie.sh" ] && rm -f "/usr/local/bin/ruijie.sh" && echo "  已移除 /usr/local/bin/ruijie.sh"
[ -f "/usr/local/bin/ruijie_student.sh" ] && rm -f "/usr/local/bin/ruijie_student.sh"
[ -f "/usr/local/bin/ruijie_teacher.sh" ] && rm -f "/usr/local/bin/ruijie_teacher.sh"

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

# ========================================
# 清理 crontab
# ========================================
echo "[6/6] 清理定时任务..."
_clean_cron() {
    local _cronfile="$1"
    [ -f "$_cronfile" ] || return
    if grep -q "ruijie" "$_cronfile" 2>/dev/null; then
        sed -i '/ruijie/d' "$_cronfile" 2>/dev/null
        echo "  已清理 $_cronfile 中的 ruijie 任务"
    fi
}
_clean_cron "/etc/crontabs/root"
_clean_cron "/etc/crontabs/$(whoami)"
if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "ruijie" | crontab - 2>/dev/null && echo "  已清理 crontab 中的 ruijie 任务"
fi

echo ""
echo "=========================================="
echo "  卸载完成！"
echo "=========================================="
echo ""

if [ "$PURGE" = "true" ]; then
    echo "已彻底清除：守护进程、脚本、配置、账号、日志、定时任务、rc.local"
else
    echo "已清除：守护进程、脚本、服务、定时任务、日志"
    echo "已保留：配置文件（账号信息）"
fi
echo ""
echo "如需重新安装，请运行 setup.sh 或从 GitHub 拉取最新版本"
echo ""
