#!/bin/bash
# ========================================
# 锐捷认证安装配置脚本 v3.1
# 广东科学技术职业学院专用
# 支持普通 Linux 和 OpenWrt 路由器
# ========================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  锐捷网络认证配置工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  本脚本需要在路由器上运行，不是你的电脑！"
echo ""
echo "  运行前请确保："
echo "    1. 路由器 WAN 口已通过网线连接到校园网"
echo "    2. 你已经通过 SSH 或路由器 Web 后台进入终端"
echo ""
echo "  不知道什么是 SSH 或路由器后台？"
echo "  请先阅读 README 中的【第一步：进入路由器】"
echo ""
read -p "按回车继续，或按 Ctrl+C 退出: "

clear

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}[信息]${NC} $1"; }
echo_success() { echo -e "${GREEN}[成功]${NC} $1"; }
echo_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
echo_error() { echo -e "${RED}[错误]${NC} $1"; }
echo_step() { echo -e "${CYAN}[步骤]${NC} $1"; }

# 配置目录
CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
SYSTEMD_SRC_DIR="$(cd "$(dirname "${0}")" && pwd)/systemd/ruijie.service"

# 检测 OpenWrt 路由器
is_openwrt() {
    [ -f /etc/openwrt_release ] || command -v ubus >/dev/null 2>&1
}

# 设置安装路径
if is_openwrt; then
    echo_info "检测到 OpenWrt 路由器环境"
    SCRIPT_DIR="/etc/ruijie"
else
    SCRIPT_DIR="/usr/local/bin"
fi

clear
echo ""
echo_success "=============================================="
echo_success "     锐捷网络认证自动配置工具 v3.1"
echo_success "     广东科学技术职业学院专用"
echo_success "=============================================="
echo ""

# ========================================
# 检查 root 权限
# ========================================
echo_step "检查系统权限..."
if [ "$(id -u)" -ne 0 ]; then
    echo_error "请使用 root 权限运行此脚本！"
    echo "  sudo sh setup.sh"
    exit 1
fi
echo_success "权限检查通过"

# ========================================
# 检查必要工具
# ========================================
echo_step "检查必要工具..."
if ! command -v curl >/dev/null 2>&1; then
    echo_warning "curl 未安装，正在尝试安装..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v opkg >/dev/null 2>&1; then
        opkg update && opkg install curl
    fi
fi

if command -v curl >/dev/null 2>&1; then
    echo_success "curl 已就绪"
else
    echo_error "curl 安装失败，请手动安装后重试"
    exit 1
fi

# ========================================
# 下载/安装主脚本
# ========================================
echo_step "安装主脚本..."

# 获取安装源目录（setup.sh 所在目录）
SETUP_DIR="$(cd "$(dirname "${0}")" && pwd)"

# OpenWrt: 安装到 /etc/ruijie/（持久化）；普通 Linux: 安装到 SCRIPT_DIR
INSTALL_TARGET="$SCRIPT_DIR"
OPENWRT_ACTIVE_DIR="/root/ruijie"

# 复制整个目录结构（ruijie.sh + lib/）
install_scripts() {
    _target="$1"
    mkdir -p "$_target/lib"

    # 复制所有脚本和 lib/
    cp "${SETUP_DIR}/ruijie.sh" "$_target/ruijie.sh"
    cp "${SETUP_DIR}/ruijie_student.sh" "$_target/ruijie_student.sh"
    cp "${SETUP_DIR}/ruijie_teacher.sh" "$_target/ruijie_teacher.sh"

    for lib in "${SETUP_DIR}/lib"/*.sh; do
        [ -f "$lib" ] && cp "$lib" "$_target/lib/"
    done

    chmod +x "$_target/ruijie.sh" "$_target/ruijie_student.sh" "$_target/ruijie_teacher.sh"
    chmod +x "$_target/lib"/*.sh
}

# 安装到目标目录
install_scripts "$INSTALL_TARGET"
echo_success "脚本安装到 $INSTALL_TARGET"

# OpenWrt 特殊处理: 同步到 /root/（立即生效）
if is_openwrt; then
    install_scripts "$OPENWRT_ACTIVE_DIR"
    echo_success "同步脚本到 $OPENWRT_ACTIVE_DIR (重启后生效)"

    # 设置 /etc/rc.local 开机同步（持久化方案）
    if grep -qF "# ruijie-auto-login" /etc/rc.local 2>/dev/null; then
        echo_info "rc.local 已配置开机自启，跳过"
    else
        echo_info "配置开机自启..."
        sed -i '/ruijie/d' /etc/rc.local 2>/dev/null || true
        {
            echo ""
            echo "# ruijie-auto-login"
            echo "[ -d /etc/ruijie ] && cp -r /etc/ruijie /root/ruijie"
        } >> /etc/rc.local
        chmod +x /etc/rc.local 2>/dev/null || true
        echo_success "已配置 /etc/rc.local 开机同步"
    fi
fi

# 创建符号链接（普通 Linux 才需要到 PATH）
if ! is_openwrt; then
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_student.sh" 2>/dev/null || true
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_teacher.sh" 2>/dev/null || true
fi

# ========================================
# 交互式账号配置
# ========================================
echo ""
echo_step "请输入校园网账号信息"
echo ""

# 选择账号类型
echo "请选择账号类型:"
echo "  [1] 学生账号 (默认)"
echo "  [2] 教师账号"
echo -n "请选择 [1/2]: "
read account_choice
case "$account_choice" in
    2) ACCOUNT_TYPE="teacher" ;;
    *) ACCOUNT_TYPE="student" ;;
esac

# 输入账号
echo -n "请输入用户名 (学号/工号): "
read username

while [ -z "$username" ]; do
    echo_warning "用户名不能为空，请重新输入"
    echo -n "请输入用户名 (学号/工号): "
    read username
done

# 输入密码
echo -n "请输入密码: "
read -s password
echo ""

while [ -z "$password" ]; do
    echo_warning "密码不能为空，请重新输入"
    echo -n "请输入密码: "
    read -s password
    echo ""
done

# 代理配置（可选）
echo ""
echo_info "代理设置（可选，直接回车跳过）:"
echo "  提示：国内校园网通常不需要代理，直接回车即可"
echo "  如果你需要翻墙或使用特殊网络，才需要填写"
echo -n "HTTP 代理地址（直接回车跳过）: "
read proxy_url_input

if [ -n "$proxy_url_input" ]; then
    proxy_https_input=""
    echo -n "HTTPS 代理地址（回车同 HTTP）: "
    read proxy_https_input
    proxy_https_val="${proxy_https_input:-$proxy_url_input}"

    echo -n "不走代理的地址（逗号分隔，回车用默认值）: "
    read no_proxy_input
fi

echo_success "账号信息已记录"

# ========================================
# 保存配置文件 (安全存储)
# ========================================
echo_step "保存配置文件..."

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" << EOF
# Ruijie Auto-Login Configuration
# Generated $(date '+%Y-%m-%d %H:%M:%S')
USERNAME=$username
PASSWORD=$password
ACCOUNT_TYPE=$ACCOUNT_TYPE
DAEMON_INTERVAL=300

# --- Proxy Settings ---
# HTTP proxy, empty = no proxy (default)
PROXY_URL=${proxy_url_input:-}
PROXY_URL_HTTPS=${proxy_https_val:-}
# Bypass proxy for these targets (comma-separated)
NO_PROXY_LIST=${no_proxy_input:-www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com}
EOF

chmod 600 "$CONFIG_FILE"
echo_success "配置已保存到 $CONFIG_FILE (权限 600)"

# ========================================
# 测试认证
# ========================================
echo ""
echo_step "正在测试认证..."
TEST_SCRIPT="$INSTALL_TARGET/ruijie.sh"
if is_openwrt && [ -f "$OPENWRT_ACTIVE_DIR/ruijie.sh" ]; then
    TEST_SCRIPT="$OPENWRT_ACTIVE_DIR/ruijie.sh"
fi
test_result=$("$TEST_SCRIPT" --${ACCOUNT_TYPE} -u "$username" -p "$password" 2>&1)

if echo "$test_result" | grep -qi "认证成功\|网络连接正常\|already\|无需认证"; then
    echo_success "认证测试通过！"
elif echo "$test_result" | grep -qi "连接正常"; then
    echo_success "认证测试通过（网络已在线）！"
else
    echo ""
    echo_warning "认证测试未完全成功，服务器返回如下:"
    echo "----------------------------------------"
    echo "$test_result" | head -20
    echo "----------------------------------------"
    echo ""
    read -p "是否仍要继续完成安装？(y/N，默认N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo_info "已取消安装，请检查账号密码后重新运行"
        exit 1
    fi
    echo_info "继续完成安装..."
fi

# ========================================
# 配置定时任务
# ========================================
echo ""
echo_step "配置定时任务..."

# 检测 cron 是否可用
CRON_CMD=""
if command -v crontab >/dev/null 2>&1; then
    CRON_CMD="crontab"
elif [ -f /etc/crontabs/root ]; then
    CRON_CMD="/bin/sh /etc/crontabs/root"
elif [ -f "/etc/crontabs/$(whoami)" ]; then
    CRON_CMD="/bin/sh /etc/crontabs/$(whoami)"
fi

if [ -n "$CRON_CMD" ]; then
    mkdir -p /var/log

    # 安全: 不在 crontab 中存储密码
    if is_openwrt; then
        CRON_TASK="*/5 5-7 * * * $INSTALL_TARGET/ruijie.sh >> /var/log/ruijie-login.log 2>&1"
    else
        CRON_TASK="*/5 5-7 * * * $INSTALL_TARGET/ruijie.sh"
    fi

# 安装 crontab 任务的原子操作函数
# 用法: install_cron_task "cron_entry_string"
install_cron_task() {
    _task="$1"
    _tmpfile=$(mktemp) || return 1

    if command -v crontab >/dev/null 2>&1; then
        # 普通 Linux: crontab 命令
        # 原子操作：读取 → 过滤 → 写入临时文件 → crontab < tmpfile
        crontab -l 2>/dev/null | grep -vF "$_task" > "$_tmpfile"
        if [ $? -eq 2 ]; then
            # grep 返回2表示文件不存在（非严重错误）
            : > "$_tmpfile"
        fi
        echo "# ruijie-auto-login" >> "$_tmpfile"
        echo "$_task" >> "$_tmpfile"

        if crontab "$_tmpfile" 2>/dev/null; then
            echo_success "定时任务已安装"
        else
            echo_error "定时任务安装失败（crontab 命令错误或权限不足）"
            rm -f "$_tmpfile"
            return 1
        fi
        rm -f "$_tmpfile"

    elif [ -f /etc/crontabs/root ]; then
        # OpenWrt 方式
        if grep -qF "$_task" /etc/crontabs/root 2>/dev/null; then
            echo_info "定时任务已存在，跳过"
            rm -f "$_tmpfile"
            return 0
        fi
        {
            echo ""
            echo "# ruijie-auto-login"
            echo "$_task"
        } >> /etc/crontabs/root 2>/dev/null \
            && echo_success "定时任务已安装" \
            || { echo_error "定时任务安装失败"; rm -f "$_tmpfile"; return 1; }
        rm -f "$_tmpfile"
    else
        echo_warning "未找到 crontab，不配置定时任务"
        rm -f "$_tmpfile"
        return 1
    fi
}

if [ -n "$CRON_TASK" ]; then
    install_cron_task "$CRON_TASK" || echo_warning "定时任务配置未成功，可稍后手动添加"
fi

# ========================================
# systemd 服务安装 (可选)
# ========================================
if command -v systemctl >/dev/null 2>&1 && ! is_openwrt; then
    echo ""
    echo_step "是否安装 systemd 服务? (后台守护进程，自动重连)"
    echo "  [y] 是，安装 systemd 服务 (推荐)"
    echo "  [n] 否，跳过"
    echo -n "请选择 [y/N]: "
    read systemd_choice

    if [ "$systemd_choice" = "y" ] || [ "$systemd_choice" = "Y" ]; then
        if [ -f "$SYSTEMD_SRC_DIR" ]; then
            cp "$SYSTEMD_SRC_DIR" /etc/systemd/system/ruijie.service
            systemctl daemon-reload
            systemctl enable ruijie.service
            echo_success "systemd 服务已安装并启用"
            echo ""
            echo "  启动服务:   systemctl start ruijie"
            echo "  查看状态:   systemctl status ruijie"
            echo "  查看日志:   journalctl -u ruijie -f"
        else
            echo_warning "systemd 服务文件不存在，跳过"
        fi
    fi
fi

# ========================================
# 完成
# ========================================
echo ""
echo_success "=============================================="
echo_success "          配置完成！"
echo_success "=============================================="
echo ""
echo "下一步："
echo ""
echo "  1. 启动守护进程（断线自动重连，推荐）:"
echo "     cd /etc/ruijie && ./ruijie.sh --daemon"
echo ""
echo "  2. 查看运行状态:"
echo "     ./ruijie.sh --status"
echo ""
echo "  3. 如遇问题，查看日志:"
echo "     tail -f /var/log/ruijie-daemon.log"
echo "     （按 Ctrl+C 退出日志）"
echo ""
echo "  4. 如需重新配置:"
echo "     ./ruijie.sh --setup"
echo ""
echo_success "=============================================="
echo ""
