#!/bin/bash
# ========================================
# 通用工具函数库
# 颜色、日志函数、常量定义
# ========================================

# 颜色定义
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_NC} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"
}

log_step() {
    echo -e "${COLOR_CYAN}[STEP]${COLOR_NC} $1"
}

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 默认配置路径
CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
PIDFILE="/var/run/ruijie-daemon.pid"
LOGFILE="/var/log/ruijie-daemon.log"

# 配置文件权限修复
fix_config_perms() {
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
广东科学技术职业学院 锐捷网络认证助手

用法: $0 [选项]

选项:
  --student            使用学生账号模式 (默认)
  --teacher            使用教师账号模式
  -u, --username 用户名  指定用户名
  -p, --password 密码   指定密码
  -d, --daemon          以后台守护进程模式运行
  --stop               停止守护进程
  --status             查看守护进程状态
  --setup              交互式配置账号信息
  -h, --help           显示此帮助信息

示例:
  $0 --student -u 2023000001 -p 123456
  $0 --teacher -u T00001 -p 123456
  $0 --daemon
  $0 --setup

无参数运行将进入交互式配置模式。
EOF
}
