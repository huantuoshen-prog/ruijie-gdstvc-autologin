#!/bin/bash
# ========================================
# 守护进程模块
# pidfile 管理、信号处理、后台循环
# ========================================

# 锁文件路径（用于防止多实例启动）
_LOCKFILE="${LOCKFILE:-/var/run/ruijie-daemon.lock}"

# ========================================
# 状态查询函数
# ========================================

# 获取上次认证成功的时间（格式: YYYY-MM-DD HH:MM:SS）
get_last_auth_time() {
    if [ -f "$LOGFILE" ]; then
        _last=$(grep -E "认证成功|login success|ONLINE" "$LOGFILE" 2>/dev/null \
            | grep -oE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' \
            | tail -1 | sed 's/^\[//; s/\]$//')
        [ -n "$_last" ] && echo "$_last" && return 0
    fi
    return 1
}

daemon_format_duration() {
    _seconds="$1"
    case "$_seconds" in
        ''|*[!0-9]*) return 1 ;;
    esac

    if [ "$_seconds" -lt 60 ]; then
        echo "${_seconds}秒"
    elif [ "$_seconds" -lt 3600 ]; then
        _minutes=$((_seconds / 60))
        _rem_seconds=$((_seconds % 60))
        if [ "$_rem_seconds" -gt 0 ]; then
            echo "${_minutes}分钟${_rem_seconds}秒"
        else
            echo "${_minutes}分钟"
        fi
    else
        _hours=$((_seconds / 3600))
        _minutes=$(((_seconds % 3600) / 60))
        echo "${_hours}小时${_minutes}分钟"
    fi
}

daemon_get_uptime() {
    _pid="$1"
    _proc_root="${2:-/proc}"
    [ -n "$_pid" ] || return 1

    _ps_uptime="$(ps -p "$_pid" -o etime= 2>/dev/null | tr -d '[:space:]')"
    if [ -n "$_ps_uptime" ]; then
        echo "$_ps_uptime"
        return 0
    fi

    [ -f "${_proc_root}/uptime" ] || return 1
    [ -f "${_proc_root}/${_pid}/stat" ] || return 1

    _uptime_sec="$(awk '{print int($1)}' "${_proc_root}/uptime" 2>/dev/null)"
    _start_jiffies="$(awk '{print $22}' "${_proc_root}/${_pid}/stat" 2>/dev/null)"
    case "$_uptime_sec" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$_start_jiffies" in
        ''|*[!0-9]*) return 1 ;;
    esac

    _hz="${DAEMON_PROC_HZ:-}"
    case "$_hz" in
        ''|*[!0-9]*)
            _hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
            ;;
    esac
    case "$_hz" in
        ''|*[!0-9]*|0) _hz=100 ;;
    esac

    _elapsed=$((_uptime_sec - _start_jiffies / _hz))
    if [ "$_elapsed" -lt 0 ] 2>/dev/null; then
        return 1
    fi

    daemon_format_duration "$_elapsed"
}

# 格式化相对时间
format_relative_time() {
    _ts="$1"
    [ -z "$_ts" ] && return 1

    # 解析时间戳
    _then=$(date -d "$_ts" +%s 2>/dev/null) || return 1
    _now=$(date +%s) || return 1
    _diff=$((_now - _then))

    if [ "$_diff" -lt 0 ]; then
        echo "刚刚"
    elif [ "$_diff" -lt 60 ]; then
        echo "${_diff}秒前"
    elif [ "$_diff" -lt 3600 ]; then
        echo "$((_diff / 60))分钟前"
    elif [ "$_diff" -lt 86400 ]; then
        echo "$((_diff / 3600))小时前"
    else
        echo "$((_diff / 86400))天前"
    fi
}

# 显示完整网络与认证状态
show_status() {
    echo ""
    echo "=========================================="
    echo "  锐捷认证状态"
    echo "=========================================="

    # --- 网络在线状态 ---
    echo ""
    log_info "网络状态:"
    if check_network 2>/dev/null; then
        log_success "已连接"
    else
        log_warning "未连接"
    fi

    # --- 账号信息 ---
    if is_configured 2>/dev/null; then
        load_config 2>/dev/null
        echo ""
        log_info "账号信息:"
        log_info "  用户: ${USERNAME:--}"
        log_info "  类型: $(get_account_type 2>/dev/null || echo 'student')"
    fi

    # --- 守护进程状态 ---
    echo ""
    log_info "守护进程:"
    if daemon_is_running; then
        _pid=$(cat "$PIDFILE" 2>/dev/null)
        _started="$(daemon_get_uptime "$_pid" 2>/dev/null || echo "未知")"
        log_success "运行中 (PID $_pid, 运行时间: $_started)"

        # 最后认证时间
        if _last=$(get_last_auth_time 2>/dev/null); then
            _rel=$(format_relative_time "$_last" 2>/dev/null || echo "$_last")
            log_info "  最后认证: $_last ($_rel)"
        fi

        # 状态机当前状态
        if [ -f "/var/run/ruijie-daemon.state" ]; then
            log_info "  状态机: $(cat /var/run/ruijie-daemon.state 2>/dev/null)"
        fi
    else
        log_info "未运行"
    fi

    # --- 配置路径 ---
    echo ""
    log_info "配置:"
    log_info "  $CONFIG_FILE"
    if command -v health_human_summary >/dev/null 2>&1; then
        log_info "健康监听: $(health_human_summary)"
    fi
    echo ""
}

# 检查守护进程是否在运行
daemon_is_running() {
    if [ -f "$PIDFILE" ]; then
        _pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
            return 0
        fi
        # pidfile 存在但进程不在，清理
        rm -f "$PIDFILE"
    fi
    return 1
}

# 查看守护进程状态
daemon_status() {
    if daemon_is_running; then
        _pid=$(cat "$PIDFILE")
        log_success "守护进程正在运行 (PID $_pid)"
        return 0
    else
        log_info "守护进程未运行"
        return 1
    fi
}

# 停止守护进程
daemon_stop() {
    if daemon_is_running; then
        _pid=$(cat "$PIDFILE")
        log_info "正在停止守护进程 (PID $_pid)..."
        _daemon_health_event "INFO" "daemon" "守护进程停止请求" "{\"pid\":\"${_pid}\"}"
        kill -TERM "$_pid" 2>/dev/null

        # 等待进程退出
        _count=0
        while kill -0 "$_pid" 2>/dev/null && [ "$_count" -lt 10 ]; do
            sleep 1
            _count=$((_count + 1))
        done

        if kill -0 "$_pid" 2>/dev/null; then
            kill -KILL "$_pid" 2>/dev/null
        fi

        rm -f "$PIDFILE"
        > "$_LOCKFILE" 2>/dev/null || true
        # 清理状态文件
        rm -f "/var/run/ruijie-daemon.state" "/var/run/ruijie-daemon.backoff" 2>/dev/null || true
        _daemon_health_refresh_snapshots
        log_success "守护进程已停止"
    else
        log_warning "守护进程未运行，无需停止"
    fi
}

# ========================================
# 状态机驱动守护进程
# ========================================

# 动态间隔常量
_DAEMON_INTERVAL_ONLINE="${DAEMON_INTERVAL_ONLINE:-600}"   # 在线检测间隔(秒)
_DAEMON_INTERVAL_SHORT="${DAEMON_INTERVAL_SHORT:-30}"     # 离线首次重试
_DAEMON_INTERVAL_LONG="${DAEMON_INTERVAL_LONG:-300}"       # 长时间等待间隔(秒)
_DAEMON_STATE_FILE="/var/run/ruijie-daemon.state"
_DAEMON_BACKOFF_FILE="/var/run/ruijie-daemon.backoff"

# 获取当前退避计数
_get_backoff_count() {
    [ -f "$_DAEMON_BACKOFF_FILE" ] && cat "$_DAEMON_BACKOFF_FILE" 2>/dev/null || echo "0"
}

# 计算下一次 sleep 秒数（指数退避: 30→60→120→300）
_calc_backoff_sleep() {
    _count=$(_get_backoff_count)
    _count=$((_count + 1))
    case "$_count" in
        1) _sleep=$_DAEMON_INTERVAL_SHORT ;;
        2) _sleep=60 ;;
        3) _sleep=120 ;;
        *) _sleep=300; _count=4 ;;
    esac
    echo "$_sleep"
    echo "$_count" > "$_DAEMON_BACKOFF_FILE"
}

# 重置退避计数
_reset_backoff() {
    rm -f "$_DAEMON_BACKOFF_FILE" 2>/dev/null || true
}

# 写状态文件
_write_daemon_state() {
    echo "$1" > "$_DAEMON_STATE_FILE" 2>/dev/null || true
}

# 记录带时间戳的日志（避免多进程写入混乱）
_log_daemon() {
    _ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$_ts] $1" >> "$LOGFILE" 2>/dev/null || true
}

_daemon_load_health() {
    if command -v health_log_event >/dev/null 2>&1; then
        return 0
    fi

    _base_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)}"
    _health_lib="${_base_dir}/lib/health.sh"
    [ -f "$_health_lib" ] || return 1
    . "$_health_lib"
}

_daemon_health_enabled() {
    _daemon_load_health || return 1
    health_expire_if_needed >/dev/null 2>&1 || true
    health_load_config >/dev/null 2>&1 || true
    [ "${HEALTH_MONITOR_ENABLED:-false}" = "true" ]
}

_daemon_health_event() {
    _level="$1"
    _type="$2"
    _message="$3"
    _details="${4:-{}}"

    _daemon_health_enabled || return 0
    health_log_event "$_level" "$_type" "$_message" "$_details" >/dev/null 2>&1 || true
}

_daemon_health_refresh_snapshots() {
    _daemon_load_health || return 0
    health_write_runtime_snapshot >/dev/null 2>&1 || true
    health_write_status_snapshot >/dev/null 2>&1 || true
}

_daemon_health_collect_baseline_if_due() {
    _daemon_health_enabled || return 0

    _now="$(health_now_epoch)"
    _interval="${HEALTH_MONITOR_BASELINE_INTERVAL:-900}"
    case "$_interval" in
        ''|*[!0-9]*) _interval=900 ;;
    esac

    if [ -z "${_DAEMON_HEALTH_LAST_BASELINE:-}" ] || [ $((_now - _DAEMON_HEALTH_LAST_BASELINE)) -ge "$_interval" ]; then
        _DAEMON_HEALTH_LAST_BASELINE="$_now"
        health_log_event "INFO" "baseline" "在线基线采样" "{}" >/dev/null 2>&1 || true
    fi
}

# 守护进程内统一认证入口
_daemon_login() {
    do_login "$USERNAME" "$PASSWORD" "$ACCOUNT_TYPE" >> "$LOGFILE" 2>&1
}

# 状态机守护进程主循环
daemon_loop() {
    _state="ONLINE"

    # nohup 子进程需自行加载配置
    if ! is_configured; then
        _log_daemon "未检测到配置，请先运行 setup.sh"
        return 1
    fi
    load_config

    # 信号处理：清理所有资源
    _daemon_cleanup() {
        _log_daemon "收到退出信号，正在停止守护进程..."
        rm -f "$PIDFILE" "$_DAEMON_STATE_FILE" "$_DAEMON_BACKOFF_FILE" 2>/dev/null || true
        exec 200>&- || true
        exit 0
    }
    trap '_daemon_cleanup' SIGTERM SIGINT SIGHUP

    _log_daemon "守护进程已启动 (PID $$)"
    _log_daemon "在线检测间隔: ${_DAEMON_INTERVAL_ONLINE}s | 离线重试: ${_DAEMON_INTERVAL_SHORT}s 起(指数退避)"
    _daemon_health_event "INFO" "daemon" "守护进程循环已启动" "{\"pid\":\"$$\"}"
    _daemon_health_refresh_snapshots

    _ONLINE_REFRESH_CYCLE=10
    _online_check_count=0
    _daemon_loop_count=0

    while true; do
        _write_daemon_state "$_state"
        _daemon_health_refresh_snapshots

        case "$_state" in
            ONLINE)
                # 长时间在线状态：定时检测 + 定期刷新 session
                if check_network 2>/dev/null; then
                    _reset_backoff
                    _online_check_count=$((_online_check_count + 1))
                    _daemon_health_collect_baseline_if_due

                    # 每 _ONLINE_REFRESH_CYCLE 次主动刷新一次 session
                    if [ "$_online_check_count" -ge "$_ONLINE_REFRESH_CYCLE" ]; then
                        _online_check_count=0
                        _log_daemon "[ONLINE] 定期刷新 session..."
                        _daemon_login || true
                    else
                        _log_daemon "[ONLINE] 在线检测正常 (${_online_check_count}/${_ONLINE_REFRESH_CYCLE})"
                    fi
                    _interval=$_DAEMON_INTERVAL_ONLINE
                else
                    _online_check_count=0
                    _log_daemon "[ONLINE] 在线检测失败，进入重试"
                    _daemon_health_event "WARN" "network_error" "在线检测失败，进入重试" "{}"
                    _state="CHECKING"
                    _interval=0  # 立即检查
                fi
                ;;

            CHECKING)
                # 首次重试：立即尝试认证
                if _daemon_login; then
                    _reset_backoff
                    _state="ONLINE"
                    _log_daemon "[CHECKING→ONLINE] 认证成功"
                    _daemon_health_event "OK" "auth_success" "首次重试认证成功" "{}"
                    _interval=$_DAEMON_INTERVAL_ONLINE
                else
                    _state="RETRYING"
                    _interval=$(_calc_backoff_sleep)
                    _log_daemon "[CHECKING→RETRYING] 首次重试失败，${_interval}s后退避重试"
                    _daemon_health_event "ERROR" "auth_failed" "首次重试认证失败" "{\"next_retry_seconds\":\"${_interval}\"}"
                fi
                ;;

            RETRYING)
                # 指数退避重试
                if _daemon_login; then
                    _reset_backoff
                    _state="ONLINE"
                    _log_daemon "[RETRYING→ONLINE] 认证成功，网络已恢复"
                    _daemon_health_event "OK" "auth_success" "退避重试认证成功" "{}"
                    _interval=$_DAEMON_INTERVAL_ONLINE
                else
                    _count=$(_get_backoff_count)
                    _interval=$(_calc_backoff_sleep)
                    _log_daemon "[RETRYING] 退避第${_count}次失败，${_interval}s后再试"
                    _daemon_health_event "ERROR" "auth_failed" "退避重试认证失败" "{\"retry_count\":\"${_count}\",\"next_retry_seconds\":\"${_interval}\"}"
                    if [ "$_count" -ge 4 ]; then
                        _state="WAIT_LONG"
                        _log_daemon "[RETRYING→WAIT_LONG] 达到最大退避，进入长时间等待"
                        _daemon_health_event "WARN" "state_transition" "达到最大退避，进入长时间等待" "{\"state\":\"WAIT_LONG\"}"
                    fi
                fi
                ;;

            WAIT_LONG)
                # 长时间等待状态（每5分钟尝试一次）
                if _daemon_login; then
                    _reset_backoff
                    _state="ONLINE"
                    _log_daemon "[WAIT_LONG→ONLINE] 认证成功，网络已恢复"
                    _daemon_health_event "OK" "auth_success" "长时间等待后认证成功" "{}"
                    _interval=$_DAEMON_INTERVAL_ONLINE
                else
                    _interval=$_DAEMON_INTERVAL_LONG
                    _log_daemon "[WAIT_LONG] 离线，长时间等待中..."
                    _daemon_health_event "WARN" "network_error" "长时间等待状态下仍离线" "{\"next_retry_seconds\":\"${_interval}\"}"
                fi
                ;;
        esac

        _write_daemon_state "$_state"
        _daemon_health_refresh_snapshots
        if [ -n "${DAEMON_TEST_MAX_LOOPS:-}" ] && [ "${DAEMON_TEST_MAX_LOOPS}" -gt 0 ] 2>/dev/null; then
            _daemon_loop_count=$((_daemon_loop_count + 1))
            if [ "$_daemon_loop_count" -ge "$DAEMON_TEST_MAX_LOOPS" ]; then
                break
            fi
        fi
        [ "$_interval" -gt 0 ] && sleep "$_interval"
    done
}

# 后台启动守护进程
# 优先使用 nohup (coreutils)，依次回退到 busybox nohup、setsid
_daemon_get_bg_cmd() {
    if command -v nohup >/dev/null 2>&1; then
        echo "nohup"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -qw "nohup"; then
        echo "busybox nohup"
    elif command -v setsid >/dev/null 2>&1; then
        echo "setsid"
    else
        echo ""
    fi
}

daemon_start() {
    # 尝试获取锁，防止多实例启动
    exec 200>"$_LOCKFILE"
    if ! flock -n 200; then
        _old_pid=""
        [ -f "$PIDFILE" ] && _old_pid=$(cat "$PIDFILE" 2>/dev/null)
        log_error "守护进程已在运行 (PID ${_old_pid:-未知})，请勿重复启动"
        return 1
    fi

    if daemon_is_running; then
        _pid=$(cat "$PIDFILE")
        log_warning "守护进程已在运行 (PID $_pid)"
        flock -n 200 && exec 200>&- || true; return 1
    fi

    # 确保有配置
    if ! is_configured; then
        log_error "未检测到配置，请先运行 '$0 --setup' 进行配置"
        flock -n 200 && exec 200>&- || true; return 1
    fi

    # 加载配置
    load_config

    # 检测后台运行方式
    _bg_cmd=$(_daemon_get_bg_cmd)
    if [ -z "$_bg_cmd" ]; then
        log_error "缺少后台运行工具 (nohup/setsid)"
        echo ""
        echo "  推荐安装 coreutils-nohup:"
        echo "    opkg update && opkg install coreutils-nohup"
        echo ""
        echo "  若 opkg 源失效，可手动从备用源下载:"
        echo "    wget https://downloads.openwrt.org/releases/19.07.10/packages/aarch64_cortex-a53/base/coreutils-nohup_9.1-1_aarch64_cortex-a53.ipk -O /tmp/nohup.ipk"
        echo "    opkg install /tmp/nohup.ipk"
        echo ""
        echo "  或使用 BusyBox 内置 nohup:"
        echo "    opkg install busybox && busybox --install"
        exec 200>&- || true
        return 1
    fi

    # 创建日志目录
    _logdir="$(dirname "$LOGFILE")"
    mkdir -p "$_logdir" 2>/dev/null || log_warning "无法创建日志目录 $LOGFILE，日志可能写入失败"

    # 后台启动
    case "$_bg_cmd" in
        "nohup")
            nohup "${SCRIPT_DIR:-.}"/"$(basename "$0")" --daemon-loop >> "$LOGFILE" 2>&1 &
            ;;
        "busybox nohup")
            busybox nohup "${SCRIPT_DIR:-.}"/"$(basename "$0")" --daemon-loop >> "$LOGFILE" 2>&1 &
            ;;
        "setsid")
            setsid "${SCRIPT_DIR:-.}"/"$(basename "$0")" --daemon-loop >> "$LOGFILE" 2>&1 &
            ;;
    esac
    _pid=$!
    echo "$_pid" > "$PIDFILE"

    # 确保进程真正启动
    sleep 1
    if kill -0 "$_pid" 2>/dev/null; then
        _daemon_health_event "INFO" "daemon" "守护进程已启动" "{\"pid\":\"${_pid}\",\"backend\":\"${_bg_cmd}\"}"
        _daemon_health_refresh_snapshots
        log_success "守护进程已启动 (PID $_pid, 后台工具: $_bg_cmd)"
        log_info "日志文件: $LOGFILE"
        flock -n 200 && exec 200>&- || true
        return 0
    else
        rm -f "$PIDFILE"
        log_error "守护进程启动失败（后台工具: $_bg_cmd）"
        exec 200>&- || true
        return 1
    fi
}
