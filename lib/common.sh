#!/bin/bash
# ========================================
# 通用工具函数库
# 颜色、日志函数、常量定义
# ========================================

# 版本信息
RUIJIE_VERSION="3.1"
RUIJIE_BUILD_DATE="2026-04-07"

# 退出码常量
EXIT_NETWORK_UNREACHABLE=10
EXIT_AUTH_FAILED=11
EXIT_CONFIG_MISSING=12
EXIT_DAEMON_ALREADY_RUNNING=13
EXIT_PERMISSION_DENIED=14

# 调试模式（可通过 -v/--verbose 开启）
VERBOSE=false

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

# ========================================
# 代理相关常量和工具函数
# ========================================

# 默认不经过代理的目标（锐捷认证必须直连）
DEFAULT_NO_PROXY="www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com"

# 合并默认 + 用户配置的 NO_PROXY_LIST
get_no_proxy_list() {
    _user_list="${NO_PROXY_LIST:-}"
    if [ -n "$_user_list" ]; then
        echo "${DEFAULT_NO_PROXY},${_user_list}"
    else
        echo "$DEFAULT_NO_PROXY"
    fi
}

# curl 统一代理包装：配置了 PROXY_URL 则走代理，否则直连
# 支持 EXTRA_NO_PROXY 环境变量追加额外的 no_proxy 条目
curl_with_proxy() {
    _proxy="${PROXY_URL:-}"
    if [ -z "$_proxy" ]; then
        curl "$@"
    else
        _noproxy="$(get_no_proxy_list)"
        _extra="${EXTRA_NO_PROXY:-}"
        [ -n "$_extra" ] && _noproxy="${_noproxy},${_extra}"
        curl --proxy "$_proxy" --noproxy "$_noproxy" "$@"
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
  --proxy URL          设置 HTTP 代理地址（如 http://127.0.0.1:7890）
  -d, --daemon          以后台守护进程模式运行
  --stop               停止守护进程
  --status, --info      查看网络与认证状态
  --logout              下线（断开认证）
  --setup               交互式配置账号信息
  -v, --verbose         显示详细调试信息（排查问题时使用）
  -h, --help           显示帮助信息
  -v, --version        显示版本号

示例:
  $0 --student -u 2023000001 -p 123456
  $0 --teacher -u T00001 -p 123456
  $0 --proxy http://127.0.0.1:7890 --student -u 2023000001 -p 123456
  $0 --daemon
  $0 --setup

无参数运行将进入交互式配置模式。
EOF
}
