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
. "${SCRIPT_DIR}/lib/health.sh"

# 默认值
ACCOUNT_TYPE="student"
DAEMON_MODE=false
DAEMON_LOOP_MODE=false
ACTION=""
CLI_ARGC=$#
OUTPUT_JSON=false
HEALTH_DURATION=""
HEALTH_LOG_LINES="100"
HEALTH_LOG_LEVEL=""
HEALTH_LOG_TYPE=""

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
            --operator)
                OPERATOR="$2"
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
            --health-status)
                ACTION="health-status"
                shift
                ;;
            --health-enable)
                ACTION="health-enable"
                HEALTH_DURATION="$2"
                shift 2
                ;;
            --health-disable)
                ACTION="health-disable"
                shift
                ;;
            --health-log)
                ACTION="health-log"
                shift
                ;;
            --runtime-status)
                ACTION="runtime-status"
                shift
                ;;
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            --lines)
                HEALTH_LOG_LINES="$2"
                shift 2
                ;;
            --level)
                HEALTH_LOG_LEVEL="$2"
                shift 2
                ;;
            --type)
                HEALTH_LOG_TYPE="$2"
                shift 2
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            -V|--version)
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

show_status_json() {
    _online=false
    if check_network 2>/dev/null; then
        _online=true
    fi

    _daemon_running=false
    _daemon_pid=""
    _daemon_state=""
    _daemon_uptime=""
    if daemon_is_running 2>/dev/null; then
        _daemon_running=true
        _daemon_pid="$(cat "$PIDFILE" 2>/dev/null)"
        _daemon_state="$(cat /var/run/ruijie-daemon.state 2>/dev/null || echo "")"
        _daemon_uptime="$(daemon_get_uptime "$_daemon_pid" 2>/dev/null || echo "")"
    fi

    _last_auth=""
    if _last="$(get_last_auth_time 2>/dev/null)"; then
        _last_auth="$_last"
    fi

    if is_configured 2>/dev/null; then
        load_config 2>/dev/null || true
    fi

    health_expire_if_needed
    health_load_config

    printf '{'
    printf '"success":true,'
    printf '"command":"status",'
    printf '"schema_version":%s,' "${HEALTH_JSON_SCHEMA_VERSION:-1}"
    printf '"generated_at":"%s",' "$(health_json_escape "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")")"
    printf '"online":%s,' "$_online"
    printf '"username":"%s",' "$(health_json_escape "${USERNAME:-}")"
    printf '"operator":"%s",' "$(health_json_escape "${OPERATOR:-DianXin}")"
    printf '"account_type":"%s",' "$(health_json_escape "${ACCOUNT_TYPE:-student}")"
    printf '"daemon_running":%s,' "$_daemon_running"
    printf '"daemon_pid":"%s",' "$(health_json_escape "${_daemon_pid:-}")"
    printf '"daemon_uptime":"%s",' "$(health_json_escape "${_daemon_uptime:-}")"
    printf '"daemon_state":"%s",' "$(health_json_escape "${_daemon_state:-}")"
    printf '"last_auth":"%s",' "$(health_json_escape "${_last_auth:-}")"
    printf '"version":"%s",' "$(health_json_escape "${RUIJIE_VERSION:-3.1}")"
    printf '"health":{'
    printf '"enabled":%s,' "$(health_json_boolean "${HEALTH_MONITOR_ENABLED:-false}")"
    printf '"mode":"%s",' "$(health_json_escape "${HEALTH_MONITOR_MODE:-timed}")"
    printf '"until":%s,' "$(health_json_string "${HEALTH_MONITOR_UNTIL:-}")"
    printf '"remaining_seconds":%s,' "$(health_json_number_or_null "$(health_remaining_seconds)")"
    printf '"collector_active":%s' "$(health_json_boolean "$(health_collector_active)")"
    printf '}'
    printf '}'
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
            if [ "$OUTPUT_JSON" = "true" ]; then
                show_status_json
            else
                show_status
            fi
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
        health-status)
            if [ "$OUTPUT_JSON" = "true" ]; then
                health_status_json
            else
                echo "健康监听: $(health_human_summary)"
            fi
            exit 0
            ;;
        health-enable)
            _duration="${HEALTH_DURATION:-3d}"
            if [ "$OUTPUT_JSON" = "true" ]; then
                health_enable_json "$_duration"
            else
                health_enable "$_duration"
                echo "健康监听已启用: ${_duration}"
            fi
            exit 0
            ;;
        health-disable)
            if [ "$OUTPUT_JSON" = "true" ]; then
                health_disable_json
            else
                health_disable
                echo "健康监听已关闭"
            fi
            exit 0
            ;;
        health-log)
            if [ "$OUTPUT_JSON" = "true" ]; then
                health_log_json "${HEALTH_LOG_LINES:-100}" "${HEALTH_LOG_LEVEL:-}" "${HEALTH_LOG_TYPE:-}"
            else
                tail -n "${HEALTH_LOG_LINES:-100}" "${HEALTH_LOGFILE:-/var/log/ruijie-health.log}" 2>/dev/null || true
            fi
            exit 0
            ;;
        runtime-status)
            if [ "$OUTPUT_JSON" = "true" ]; then
                health_runtime_status_json
            else
                echo "$(health_runtime_json)"
            fi
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
            if [ "$CLI_ARGC" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then
                interactive_config
                load_config
                log_info "已完成交互式配置，开始认证"
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
    fi

    # 如果也指定了账号类型，覆盖配置
    if [ "$ACCOUNT_TYPE" != "student" ]; then
        log_info "使用教师账号模式"
    fi

    # 执行登录（OPERATOR 由 get_service_type 内部使用，默认为 DianXin）
    do_login "$USERNAME" "$PASSWORD" "$ACCOUNT_TYPE" "$OPERATOR"
}

# 启动
_detect_mode
parse_args "$@"
main
