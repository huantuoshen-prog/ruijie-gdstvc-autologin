#!/bin/bash
# ========================================
# 锐捷网络认证 - 统一入口脚本
# 广东科学技术职业学院专用
# ========================================

# 注意: 不使用 set -e，因为 check_network() 等函数正常返回1（离线状态）
# 在需要严格检查的关键段落自行用 || exit 处理

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# 加载模块库
. "${SCRIPT_DIR}/lib/common.sh"
. "${SCRIPT_DIR}/lib/config.sh"
. "${SCRIPT_DIR}/lib/network.sh"
. "${SCRIPT_DIR}/lib/daemon.sh"

# 默认值
ACCOUNT_TYPE="student"
DAEMON_MODE=false
DAEMON_LOOP_MODE=false
ACTION=""

# 自动检测调用方式（通过脚本名判断）
_detect_mode() {
    _name="$(basename "$0")"
    case "$_name" in
        ruijie_student.sh)
            ACCOUNT_TYPE="student"
            ;;
        ruijie_teacher.sh)
            ACCOUNT_TYPE="teacher"
            ;;
        ruijie.sh|*)
            ACCOUNT_TYPE="student"
            ;;
    esac
}

# 解析命令行参数
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --student)
                ACCOUNT_TYPE="student"
                shift
                ;;
            --teacher)
                ACCOUNT_TYPE="teacher"
                shift
                ;;
            -u|--username)
                USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                PASSWORD="$2"
                shift 2
                ;;
            --proxy)
                PROXY_URL="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --daemon-loop)
                # 内部使用：守护进程循环模式
                DAEMON_LOOP_MODE=true
                shift
                ;;
            --stop)
                ACTION="stop"
                shift
                ;;
            --status|--info)
                ACTION="status"
                shift
                ;;
            --logout)
                ACTION="logout"
                shift
                ;;
            --setup)
                ACTION="setup"
                shift
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "Ruijie-Auto-Login v${RUIJIE_VERSION:-3.1} (${RUIJIE_BUILD_DATE:-2026-04-07})"
                exit 0
                ;;
            *)
                # 如果第一个非选项参数是用户名
                case "$1" in
                    --*)
                        shift
                        ;;
                    *)
                        if [ -z "$USERNAME" ]; then
                            USERNAME="$1"
                            PASSWORD="${2:-}"
                            # 只有第二个参数存在且也不是选项时才额外跳过一个
                            if [ -n "$2" ] && [ "${2#--}" = "$2" ]; then
                                shift 2
                            else
                                shift
                            fi
                        else
                            shift
                        fi
                        ;;
                esac
                ;;
        esac
    done
}

# 主流程
main() {
    # 守护进程状态/停止
    case "$ACTION" in
        stop)
            daemon_stop
            exit 0
            ;;
        status)
            show_status
            exit 0
            ;;
        logout)
            if [ -z "$USERNAME" ] && is_configured; then
                load_config
            fi
            if [ -z "$USERNAME" ]; then
                log_error "下线需要提供用户名"
                echo "用法: $0 --logout -u 用户名"
                exit 1
            fi
            echo ""
            echo "即将断开校园网认证（下线）"
            echo "所有通过此路由器上网的设备将暂时无法上网，直到重新认证"
            echo ""
            read -p "确认下线？(y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "已取消"
                exit 0
            fi
            do_logout "$USERNAME"
            exit $?
            ;;
        setup)
            interactive_config
            exit 0
            ;;
    esac

    # 守护进程模式
    if [ "$DAEMON_LOOP_MODE" = "true" ]; then
        daemon_loop
        exit 0
    fi

    if [ "$DAEMON_MODE" = "true" ]; then
        daemon_start
        exit $?
    fi

    # 正常登录流程
    # 打印banner
    echo ""
    log_info "=========================================="
    log_info "  锐捷网络认证助手 v${RUIJIE_VERSION:-3.1}"
    log_info "  广东科学技术职业学院专用"
    log_info "=========================================="
    echo ""

    # 如果没有提供凭据，尝试从配置文件加载
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        if is_configured; then
            load_config
            log_info "已从配置文件加载账号信息"
        else
            log_error "未提供用户名和密码，且未找到配置文件"
            echo ""
            echo "请使用以下方式之一提供凭据:"
            echo "  $0 -u 用户名 -p 密码"
            echo "  $0 用户名 密码"
            echo "  $0 --setup  (交互式配置)"
            echo ""
            exit 1
        fi
    fi

    # 如果也指定了账号类型，覆盖配置
    if [ "$ACCOUNT_TYPE" != "student" ]; then
        log_info "使用教师账号模式"
    fi

    # 执行登录
    do_login "$USERNAME" "$PASSWORD" "$ACCOUNT_TYPE"
}

# 启动
_detect_mode
parse_args "$@"
main
