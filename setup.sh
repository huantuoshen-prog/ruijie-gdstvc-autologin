#!/bin/sh

# ========================================
# 锐捷认证自动配置脚本
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

clear
echo ""
echo_success "=============================================="
echo_success "     锐捷网络认证自动配置工具 v1.0"
echo_success "     广东科学技术职业学院专用"
echo_success "=============================================="
echo ""

# 检查 root 权限
echo_step "检查系统权限..."
if [ "$(id -u)" -ne 0 ]; then
    echo_error "请使用 root 权限运行此脚本！"
    echo " sudo sh setup.sh"
    exit 1
fi
echo_success "权限检查通过"

# 检查 curl
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

# 下载主脚本
echo_step "下载认证脚本..."
SCRIPT_DIR="/usr/local/bin"
SCRIPT_NAME="ruijie-login"

mkdir -p "$SCRIPT_DIR"

curl -sL "https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/ruijie_student.sh" -o "${SCRIPT_DIR}/${SCRIPT_NAME}"

if [ -f "${SCRIPT_DIR}/${SCRIPT_NAME}" ]; then
    chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"
    echo_success "脚本下载成功: ${SCRIPT_DIR}/${SCRIPT_NAME}"
else
    echo_error "脚本下载失败，请检查网络连接"
    exit 1
fi

echo ""
echo_step "请输入校园网账号信息"
echo ""

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

echo ""
echo_success "账号信息已记录"

# 测试认证
echo ""
echo_step "正在测试认证..."
test_result=$("${SCRIPT_DIR}/${SCRIPT_NAME}" "$username" "$password" 2>&1)

if echo "$test_result" | grep -q "认证成功\|网络已连接"; then
    echo_success "认证测试通过！"
else
    echo_warning "认证测试结果: $test_result"
    echo_warning "但会继续配置定时任务，你可以稍后手动测试"
fi

# 配置定时任务
echo ""
echo_step "配置自动登录任务..."

# 检测系统类型
if command -v crontab >/dev/null 2>&1; then
    CRON_INSTALLED=1
elif [ -f /etc/crontabs/root ]; then
    CRON_FILE="/etc/crontabs/root"
    CRON_INSTALLED=1
else
    CRON_INSTALLED=0
fi

if [ "$CRON_INSTALLED" = "1" ]; then
    # 创建日志目录
    mkdir -p /var/log
    
    # 添加定时任务: 凌晨5点到7点，每5分钟尝试一次
    CRON_TASK="*/5 5-7 * * * ${SCRIPT_DIR}/${SCRIPT_NAME} ${username} ${password} >> /var/log/ruijie-login.log 2>&1"
    
    # 检查是否已有任务
    if grep -q "ruijie-login" /etc/crontabs/root 2>/dev/null; then
        echo_warning "定时任务已存在，先删除旧的..."
        sed -i '/ruijie-login/d' /etc/crontabs/root 2>/dev/null
    fi
    
    # 添加新任务
    echo "$CRON_TASK" >> /etc/crontabs/root 2>/dev/null || crontab -l 2>/dev/null | grep -v "ruijie-login" | crontab - 2>/dev/null
    
    # 重启 cron 服务
    if command -v service >/dev/null 2>&1; then
        service cron restart 2>/dev/null || service crond restart 2>/dev/null
    elif command -v /etc/init.d/cron >/dev/null 2>&1; then
        /etc/init.d/cron restart 2>/dev/null
    fi
    
    echo_success "定时任务配置成功！"
    echo ""
    echo "自动登录时间: 每天凌晨 5:00 - 7:00"
    echo "尝试间隔: 每5分钟"
    echo "日志位置: /var/log/ruijie-login.log"
else
    echo_warning "未检测到 cron 服务，定时任务配置失败"
    echo_info "你可以手动添加以下定时任务:"
    echo ""
    echo "  */5 5-7 * * * ${SCRIPT_DIR}/${SCRIPT_NAME} ${username} ${password}"
    echo ""
fi

# 保存配置信息
echo_step "保存配置信息..."
cat > /etc/ruijie.conf << EOF
# 锐捷认证配置
USERNAME=$username
SCRIPT_PATH=${SCRIPT_DIR}/${SCRIPT_NAME}
EOF
echo_success "配置已保存到 /etc/ruijie.conf"

# 常用命令提示
echo ""
echo_success "=============================================="
echo_success "          配置完成！"
echo_success "=============================================="
echo ""
echo "📖 常用命令:"
echo ""
echo "  手动登录: ${SCRIPT_DIR}/${SCRIPT_NAME} 你的用户名 你的密码"
echo "  或: /etc/ruijie.conf 中配置了默认账号"
echo ""
echo "  查看日志: tail -f /var/log/ruijie-login.log"
echo "  测试认证: ${SCRIPT_DIR}/${SCRIPT_NAME} ${username} ${password}"
echo ""
echo "📝 定时任务:"
echo "  自动登录时间: 每天 5:00 - 7:00"
echo "  尝试间隔: 每5分钟"
echo ""
echo_success "=============================================="
echo ""
