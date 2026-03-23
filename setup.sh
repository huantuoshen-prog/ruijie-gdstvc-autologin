#!/bin/sh
# ========================================
# 锐捷认证安装配置脚本 v2.0
# 广东科学技术职业学院专用
# 一键安装配置工具
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
SCRIPT_DIR="/usr/local/bin"
SCRIPT_NAME="ruijie-login"
SYSTEMD_SRC_DIR="$(cd "$(dirname "${0}")" && pwd)/systemd/ruijie.service"

clear
echo ""
echo_success "=============================================="
echo_success "     锐捷网络认证自动配置工具 v2.0"
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
MAIN_SCRIPT="${SETUP_DIR}/ruijie.sh"

if [ -f "$MAIN_SCRIPT" ]; then
    # 本地安装
    cp "$MAIN_SCRIPT" "${SCRIPT_DIR}/${SCRIPT_NAME}"
    # 也复制一份 ruijie.sh (统一入口)
    cp "$MAIN_SCRIPT" "${SCRIPT_DIR}/ruijie.sh"

    # 创建符号链接（向后兼容）
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_student.sh"
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_teacher.sh"

    echo_success "主脚本安装成功"
elif command -v git >/dev/null 2>&1; then
    # Git clone
    TEMP_DIR=$(mktemp -d)
    git clone https://github.com/17388749803/Ruijie-Auto-Login.git "$TEMP_DIR"
    cp "${TEMP_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie.sh"
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_student.sh"
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_teacher.sh"
    rm -rf "$TEMP_DIR"
    echo_success "主脚本下载成功"
else
    # 直接下载
    curl -sL "https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/ruijie.sh" -o "${SCRIPT_DIR}/ruijie.sh"
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_student.sh"
    ln -sf "${SCRIPT_DIR}/ruijie.sh" "${SCRIPT_DIR}/ruijie_teacher.sh"
    echo_success "主脚本下载成功"
fi

chmod +x "${SCRIPT_DIR}/ruijie.sh"
chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"

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
EOF

chmod 600 "$CONFIG_FILE"
echo_success "配置已保存到 $CONFIG_FILE (权限 600)"

# ========================================
# 测试认证
# ========================================
echo ""
echo_step "正在测试认证..."
test_result=$("${SCRIPT_DIR}/ruijie.sh" --${ACCOUNT_TYPE} -u "$username" -p "$password" 2>&1)

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
elif [ -f /etc/crontabs/$(whoami) ]; then
    CRON_CMD="/bin/sh /etc/crontabs/$(whoami)"
fi

if [ -n "$CRON_CMD" ]; then
    mkdir -p /var/log

    # 安全: 不在 crontab 中存储密码
    CRON_TASK="*/5 5-7 * * * ${SCRIPT_DIR}/ruijie.sh"

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
if command -v systemctl >/dev/null 2>&1; then
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
