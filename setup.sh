#!/bin/bash
# ========================================
# 锐捷认证安装配置脚本 v2.1
# 广东科学技术职业学院专用
# 支持普通 Linux 和 OpenWrt 路由器
# ========================================

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
echo_success "     锐捷网络认证自动配置工具 v2.1"
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
    echo_step "配置开机自启..."
    if [ -f /etc/rc.local ]; then
        # 去掉旧的相关行
        sed -i '/ruijie/d' /etc/rc.local 2>/dev/null || true
    fi
    {
        echo ""
        echo "# Ruijie auto-login: sync scripts from /etc/ruijie to /root/"
        echo "[ -d /etc/ruijie ] && cp -r /etc/ruijie /root/ruijie"
    } >> /etc/rc.local
    chmod +x /etc/rc.local 2>/dev/null || true
    echo_success "已配置 /etc/rc.local 开机同步"
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
echo "  例如: http://127.0.0.1:7890  或  socks5://127.0.0.1:1080"
echo -n "HTTP 代理地址: "
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

if echo "$test_result" | grep -qi "成功\|already"; then
    echo_success "认证测试通过！"
elif echo "$test_result" | grep -qi "连接"; then
    echo_success "认证测试通过（网络已连接）！"
else
    echo_warning "认证测试结果: $test_result"
    echo_warning "但会继续配置，你可以稍后手动测试"
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

    # 清理旧任务
    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -v "ruijie" | crontab - 2>/dev/null || true
        echo "$CRON_TASK" >> /dev/null 2>&1 || true
        # 更安全的方式: 追加新任务
        (crontab -l 2>/dev/null; echo "$CRON_TASK") | crontab - 2>/dev/null || true
    elif [ -f /etc/crontabs/root ]; then
        grep -v "ruijie" /etc/crontabs/root > /tmp/crontab_tmp 2>/dev/null || true
        echo "$CRON_TASK" >> /tmp/crontab_tmp
        cp /tmp/crontab_tmp /etc/crontabs/root
        rm -f /tmp/crontab_tmp
    fi

    echo_success "定时任务配置成功！"
    echo ""
    echo "  自动登录时间: 每天凌晨 5:00 - 7:00"
    echo "  尝试间隔: 每5分钟"
    echo "  注意: 密码存储在 $CONFIG_FILE 中"
else
    echo_warning "未检测到 cron 服务，定时任务配置失败"
    echo_info "你可以手动添加以下定时任务:"
    echo ""
    echo "  $CRON_TASK"
    echo ""
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
echo "  常用命令:"
echo ""
echo "  手动登录:  ruijie.sh -u $username -p [密码]"
if [ -n "$proxy_url_input" ]; then
echo "  使用代理:  ruijie.sh --proxy $proxy_url_input -u $username -p [密码]"
fi
echo "  守护进程:  ruijie.sh --daemon"
echo "  查看状态:  ruijie.sh --status"
echo "  停止守护:  ruijie.sh --stop"
echo "  重新配置:  ruijie.sh --setup"
echo "  交互帮助:  ruijie.sh --help"
echo ""
echo "  配置文件:  $CONFIG_FILE"
echo "  日志文件:  /var/log/ruijie-daemon.log"
echo ""
echo_success "=============================================="
echo ""
