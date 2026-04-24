#!/bin/bash
# ========================================
# 健康监听模块
# 运行环境感知、健康窗口、JSON CLI、健康日志
# ========================================

health_apply_defaults() {
    CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/ruijie}"
    CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/ruijie.conf}"
    HEALTH_CONFIG_FILE="${HEALTH_CONFIG_FILE:-${CONFIG_DIR}/health-monitor.conf}"
    HEALTH_LOGFILE="${HEALTH_LOGFILE:-/var/log/ruijie-health.log}"
    HEALTH_STATUS_FILE="${HEALTH_STATUS_FILE:-/var/run/ruijie-health.status.json}"
    RUNTIME_STATUS_FILE="${RUNTIME_STATUS_FILE:-/var/run/ruijie-runtime.status.json}"
    HEALTH_LOG_ROTATE_BYTES="${HEALTH_LOG_ROTATE_BYTES:-1048576}"
    HEALTH_JSON_SCHEMA_VERSION="${HEALTH_JSON_SCHEMA_VERSION:-1}"
    HEALTH_MONITOR_BASELINE_INTERVAL="${HEALTH_MONITOR_BASELINE_INTERVAL:-900}"
    HEALTH_MONITOR_REDACTION="${HEALTH_MONITOR_REDACTION:-mask_password_and_session_only}"
}

health_now_epoch() {
    date +%s 2>/dev/null || echo "0"
}

health_json_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/	/\\t/g' \
        -e ':a;N;$!ba;s/\r/\\r/g' \
        -e ':b;N;$!bb;s/\n/\\n/g'
}

health_json_string() {
    printf '"%s"' "$(health_json_escape "$1")"
}

health_json_boolean() {
    case "$1" in
        true|1|yes) printf 'true' ;;
        *) printf 'false' ;;
    esac
}

health_json_number_or_null() {
    case "$1" in
        ''|*[!0-9-]*) printf 'null' ;;
        *) printf '%s' "$1" ;;
    esac
}

health_redact_text() {
    printf '%s' "$1" | sed -E \
        -e 's/(密码[^:：=]*[:：=][[:space:]]*)[^", ]+/\1[REDACTED]/g' \
        -e 's/("?(password|cookie|session|token|authorization)"?[[:space:]]*[:=][[:space:]]*"?)[^", }]+("?)/\1[REDACTED]\3/Ig'
}

health_mask_json_fields() {
    printf '%s' "$1" | sed -E \
        -e 's/"(password|cookie|session|token|authorization)"[[:space:]]*:[[:space:]]*"[^"]*"/"\1":"[REDACTED]"/Ig'
}

health_load_config() {
    health_apply_defaults

    HEALTH_MONITOR_ENABLED="false"
    HEALTH_MONITOR_MODE="timed"
    HEALTH_MONITOR_UNTIL=""
    HEALTH_MONITOR_CREATED_AT=""

    [ -f "$HEALTH_CONFIG_FILE" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            \#*|'') continue ;;
        esac

        _key="${line%%=*}"
        _value="${line#*=}"

        case "$_key" in
            HEALTH_MONITOR_ENABLED) HEALTH_MONITOR_ENABLED="$_value" ;;
            HEALTH_MONITOR_MODE) HEALTH_MONITOR_MODE="$_value" ;;
            HEALTH_MONITOR_UNTIL) HEALTH_MONITOR_UNTIL="$_value" ;;
            HEALTH_MONITOR_BASELINE_INTERVAL)
                case "$_value" in
                    ''|*[!0-9]*) HEALTH_MONITOR_BASELINE_INTERVAL="900" ;;
                    *) HEALTH_MONITOR_BASELINE_INTERVAL="$_value" ;;
                esac
                ;;
            HEALTH_MONITOR_REDACTION) HEALTH_MONITOR_REDACTION="$_value" ;;
            HEALTH_MONITOR_CREATED_AT)
                case "$_value" in
                    ''|*[!0-9]*) HEALTH_MONITOR_CREATED_AT="" ;;
                    *) HEALTH_MONITOR_CREATED_AT="$_value" ;;
                esac
                ;;
        esac
    done < "$HEALTH_CONFIG_FILE"
}

health_save_config() {
    health_apply_defaults
    mkdir -p "$(dirname "$HEALTH_CONFIG_FILE")" 2>/dev/null || true
    cat > "$HEALTH_CONFIG_FILE" <<EOF
# Ruijie Health Monitor Configuration
HEALTH_MONITOR_ENABLED=${HEALTH_MONITOR_ENABLED:-false}
HEALTH_MONITOR_MODE=${HEALTH_MONITOR_MODE:-timed}
HEALTH_MONITOR_UNTIL=${HEALTH_MONITOR_UNTIL:-}
HEALTH_MONITOR_BASELINE_INTERVAL=${HEALTH_MONITOR_BASELINE_INTERVAL:-900}
HEALTH_MONITOR_REDACTION=${HEALTH_MONITOR_REDACTION:-mask_password_and_session_only}
HEALTH_MONITOR_CREATED_AT=${HEALTH_MONITOR_CREATED_AT:-}
EOF
    chmod 600 "$HEALTH_CONFIG_FILE" 2>/dev/null || true
}

health_duration_to_seconds() {
    case "$1" in
        1d) echo 86400 ;;
        3d) echo 259200 ;;
        7d) echo 604800 ;;
        permanent) echo 0 ;;
        *) return 1 ;;
    esac
}

health_enable() {
    health_apply_defaults

    _duration="${1:-3d}"
    _now="$(health_now_epoch)"
    _seconds="$(health_duration_to_seconds "$_duration")" || return 1

    HEALTH_MONITOR_ENABLED="true"
    HEALTH_MONITOR_CREATED_AT="$_now"
    HEALTH_MONITOR_BASELINE_INTERVAL="${HEALTH_MONITOR_BASELINE_INTERVAL:-900}"
    HEALTH_MONITOR_REDACTION="${HEALTH_MONITOR_REDACTION:-mask_password_and_session_only}"

    if [ "$_duration" = "permanent" ]; then
        HEALTH_MONITOR_MODE="permanent"
        HEALTH_MONITOR_UNTIL=""
    else
        HEALTH_MONITOR_MODE="timed"
        HEALTH_MONITOR_UNTIL="$((_now + _seconds))"
    fi

    health_save_config
}

health_disable() {
    health_apply_defaults
    health_load_config
    HEALTH_MONITOR_ENABLED="false"
    HEALTH_MONITOR_MODE="${HEALTH_MONITOR_MODE:-timed}"
    HEALTH_MONITOR_UNTIL=""
    [ -n "${HEALTH_MONITOR_CREATED_AT:-}" ] || HEALTH_MONITOR_CREATED_AT="$(health_now_epoch)"
    health_save_config
}

health_remaining_seconds() {
    health_load_config
    if [ "${HEALTH_MONITOR_ENABLED:-false}" != "true" ]; then
        echo "0"
        return 0
    fi

    if [ "${HEALTH_MONITOR_MODE:-timed}" = "permanent" ]; then
        echo ""
        return 0
    fi

    _now="$(health_now_epoch)"
    _until="${HEALTH_MONITOR_UNTIL:-0}"
    case "$_until" in
        ''|*[!0-9]*) echo "0" ;;
        *)
            _remaining=$((_until - _now))
            if [ "$_remaining" -lt 0 ] 2>/dev/null; then
                echo "0"
            else
                echo "$_remaining"
            fi
            ;;
    esac
}

health_expire_if_needed() {
    health_load_config
    [ "${HEALTH_MONITOR_ENABLED:-false}" = "true" ] || return 0
    [ "${HEALTH_MONITOR_MODE:-timed}" = "timed" ] || return 0

    _remaining="$(health_remaining_seconds)"
    if [ "${_remaining:-0}" -gt 0 ] 2>/dev/null; then
        return 0
    fi

    health_disable
}

health_bootstrap_on_first_install() {
    health_apply_defaults
    _script_path="$1"
    _config_path="$2"

    if [ -f "$HEALTH_CONFIG_FILE" ] || [ -f "$_script_path" ] || [ -f "$_config_path" ]; then
        return 0
    fi

    health_enable "3d"
}

health_detect_platform() {
    if [ -f /etc/openwrt_release ] || command -v ubus >/dev/null 2>&1; then
        echo "openwrt"
    elif command -v uname >/dev/null 2>&1; then
        echo "linux"
    else
        echo "unknown"
    fi
}

health_detect_kernel() {
    uname -r 2>/dev/null || echo ""
}

health_detect_arch() {
    uname -m 2>/dev/null || echo ""
}

health_detect_shell() {
    if [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
    elif [ -n "${SHELL:-}" ]; then
        basename "$SHELL"
    else
        echo "sh"
    fi
}

health_detect_busybox() {
    command -v busybox >/dev/null 2>&1 && echo "true" || echo "false"
}

health_detect_curl() {
    command -v curl >/dev/null 2>&1 && echo "true" || echo "false"
}

health_detect_nohup_backend() {
    if command -v nohup >/dev/null 2>&1; then
        echo "nohup"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -qw "nohup"; then
        echo "busybox-nohup"
    elif command -v setsid >/dev/null 2>&1; then
        echo "setsid"
    else
        echo "missing"
    fi
}

health_detect_panel_installed() {
    if [ -f /www/ruijie-panel/index.html ] || [ -f /www/ruijie-panel/dist/index.html ] || [ -d /etc/ruijie-panel ]; then
        echo "true"
    else
        echo "false"
    fi
}

health_detect_panel_web_root() {
    if [ -d /www/ruijie-panel ]; then
        echo "/www/ruijie-panel"
    elif [ -d /www/ruijie-panel/dist ]; then
        echo "/www/ruijie-panel/dist"
    else
        echo ""
    fi
}

health_daemon_running() {
    if command -v daemon_is_running >/dev/null 2>&1; then
        if daemon_is_running >/dev/null 2>&1; then
            echo "true"
            return 0
        fi
    elif [ -f "${PIDFILE:-/var/run/ruijie-daemon.pid}" ]; then
        _pid="$(cat "${PIDFILE:-/var/run/ruijie-daemon.pid}" 2>/dev/null)"
        if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
            echo "true"
            return 0
        fi
    fi
    echo "false"
}

health_collector_active() {
    health_load_config
    [ "${HEALTH_MONITOR_ENABLED:-false}" = "true" ] && [ "$(health_daemon_running)" = "true" ] \
        && echo "true" || echo "false"
}

health_runtime_json() {
    health_apply_defaults

    _platform="$(health_detect_platform)"
    _kernel="$(health_detect_kernel)"
    _arch="$(health_detect_arch)"
    _shell="$(health_detect_shell)"
    _busybox="$(health_detect_busybox)"
    _curl="$(health_detect_curl)"
    _nohup_backend="$(health_detect_nohup_backend)"
    _script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd 2>/dev/null || pwd)}"
    _panel_installed="$(health_detect_panel_installed)"
    _panel_web_root="$(health_detect_panel_web_root)"
    _daemon_running="$(health_daemon_running)"
    _collector_active="$(health_collector_active)"

    printf '{'
    printf '"platform":"%s",' "$(health_json_escape "$_platform")"
    printf '"kernel":"%s",' "$(health_json_escape "$_kernel")"
    printf '"arch":"%s",' "$(health_json_escape "$_arch")"
    printf '"shell":"%s",' "$(health_json_escape "$_shell")"
    printf '"busybox_present":%s,' "$(health_json_boolean "$_busybox")"
    printf '"curl_present":%s,' "$(health_json_boolean "$_curl")"
    printf '"nohup_backend":"%s",' "$(health_json_escape "$_nohup_backend")"
    printf '"script_dir":"%s",' "$(health_json_escape "$_script_dir")"
    printf '"config_file":"%s",' "$(health_json_escape "$CONFIG_FILE")"
    printf '"daemon_pidfile":"%s",' "$(health_json_escape "${PIDFILE:-/var/run/ruijie-daemon.pid}")"
    printf '"daemon_logfile":"%s",' "$(health_json_escape "${LOGFILE:-/var/log/ruijie-daemon.log}")"
    printf '"health_logfile":"%s",' "$(health_json_escape "$HEALTH_LOGFILE")"
    printf '"panel_installed":%s,' "$(health_json_boolean "$_panel_installed")"
    printf '"panel_web_root":"%s",' "$(health_json_escape "$_panel_web_root")"
    printf '"daemon_running":%s,' "$(health_json_boolean "$_daemon_running")"
    printf '"health_collector_active":%s' "$(health_json_boolean "$_collector_active")"
    printf '}'
}

health_snapshot_json() {
    health_apply_defaults
    if command -v load_config >/dev/null 2>&1; then
        load_config 2>/dev/null || true
    fi

    _online="false"
    if command -v check_network >/dev/null 2>&1 && check_network >/dev/null 2>&1; then
        _online="true"
    fi

    _daemon_running="$(health_daemon_running)"
    _daemon_pid=""
    if [ "$_daemon_running" = "true" ] && [ -f "${PIDFILE:-/var/run/ruijie-daemon.pid}" ]; then
        _daemon_pid="$(cat "${PIDFILE:-/var/run/ruijie-daemon.pid}" 2>/dev/null)"
    fi

    printf '{'
    printf '"online":%s,' "$(health_json_boolean "$_online")"
    printf '"daemon_running":%s,' "$(health_json_boolean "$_daemon_running")"
    printf '"daemon_state":"%s",' "$(health_json_escape "$(cat /var/run/ruijie-daemon.state 2>/dev/null || echo "")")"
    printf '"daemon_pid":"%s",' "$(health_json_escape "$_daemon_pid")"
    printf '"username":"%s",' "$(health_json_escape "${USERNAME:-}")"
    printf '"account_type":"%s",' "$(health_json_escape "${ACCOUNT_TYPE:-student}")"
    printf '"operator":"%s"' "$(health_json_escape "${OPERATOR:-DianXin}")"
    printf '}'
}

health_write_runtime_snapshot() {
    health_apply_defaults
    mkdir -p "$(dirname "$RUNTIME_STATUS_FILE")" 2>/dev/null || true
    health_runtime_json | cat > "$RUNTIME_STATUS_FILE" 2>/dev/null || true
}

health_write_status_snapshot() {
    health_apply_defaults
    health_load_config
    mkdir -p "$(dirname "$HEALTH_STATUS_FILE")" 2>/dev/null || true
    _remaining="$(health_remaining_seconds)"
    _collector_active="$(health_collector_active)"
    _runtime_json="$(health_runtime_json)"
    _snapshot_json="$(health_snapshot_json)"
    _last_event_at=""
    if [ -f "$HEALTH_LOGFILE" ]; then
        _last_event_at="$(tail -n 1 "$HEALTH_LOGFILE" 2>/dev/null | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"
    fi

    {
        printf '{'
        printf '"supported":true,'
        printf '"enabled":%s,' "$(health_json_boolean "${HEALTH_MONITOR_ENABLED:-false}")"
        printf '"mode":"%s",' "$(health_json_escape "${HEALTH_MONITOR_MODE:-timed}")"
        printf '"until":%s,' "$(health_json_string "${HEALTH_MONITOR_UNTIL:-}")"
        printf '"remaining_seconds":%s,' "$(health_json_number_or_null "$_remaining")"
        printf '"collector_active":%s,' "$(health_json_boolean "$_collector_active")"
        printf '"baseline_interval":%s,' "$(health_json_number_or_null "${HEALTH_MONITOR_BASELINE_INTERVAL:-900}")"
        printf '"redaction":"%s",' "$(health_json_escape "${HEALTH_MONITOR_REDACTION:-mask_password_and_session_only}")"
        printf '"last_event_at":%s,' "$(health_json_string "$_last_event_at")"
        printf '"runtime":%s,' "$_runtime_json"
        printf '"snapshot":%s' "$_snapshot_json"
        printf '}'
    } | cat > "$HEALTH_STATUS_FILE" 2>/dev/null || true
}

health_rotate_log_if_needed() {
    health_apply_defaults
    [ -f "$HEALTH_LOGFILE" ] || return 0

    _size="$(wc -c < "$HEALTH_LOGFILE" 2>/dev/null | tr -d '[:space:]')"
    case "$_size" in
        ''|*[!0-9]*) return 0 ;;
    esac

    if [ "$_size" -lt "$HEALTH_LOG_ROTATE_BYTES" ] 2>/dev/null; then
        return 0
    fi

    [ -f "${HEALTH_LOGFILE}.1" ] && mv -f "${HEALTH_LOGFILE}.1" "${HEALTH_LOGFILE}.2" 2>/dev/null || true
    mv -f "$HEALTH_LOGFILE" "${HEALTH_LOGFILE}.1" 2>/dev/null || true
    : > "$HEALTH_LOGFILE" 2>/dev/null || true
    chmod 600 "$HEALTH_LOGFILE" 2>/dev/null || true
}

health_log_event() {
    health_apply_defaults
    _level="${1:-INFO}"
    _type="${2:-event}"
    _message="$(health_redact_text "${3:-}")"
    _details="$(health_mask_json_fields "${4:-{}}")"
    case "$_details" in
        \{*\}|\[*\]) ;;
        *) _details="{}" ;;
    esac

    if command -v load_config >/dev/null 2>&1; then
        load_config 2>/dev/null || true
    fi

    mkdir -p "$(dirname "$HEALTH_LOGFILE")" 2>/dev/null || true

    _ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")"
    _runtime_json="$(health_runtime_json)"
    _snapshot_json="$(health_snapshot_json)"

    {
        printf '{"schema_version":%s,' "$HEALTH_JSON_SCHEMA_VERSION"
        printf '"ts":"%s",' "$(health_json_escape "$_ts")"
        printf '"level":"%s",' "$(health_json_escape "$_level")"
        printf '"type":"%s",' "$(health_json_escape "$_type")"
        printf '"message":"%s",' "$(health_json_escape "$_message")"
        printf '"online":%s,' "$(printf '%s' "$_snapshot_json" | sed -n 's/.*"online":\([^,}]*\).*/\1/p')"
        printf '"daemon_state":"%s",' "$(printf '%s' "$_snapshot_json" | sed -n 's/.*"daemon_state":"\([^"]*\)".*/\1/p')"
        printf '"daemon_pid":"%s",' "$(printf '%s' "$_snapshot_json" | sed -n 's/.*"daemon_pid":"\([^"]*\)".*/\1/p')"
        printf '"username":"%s",' "$(health_json_escape "${USERNAME:-}")"
        printf '"account_type":"%s",' "$(health_json_escape "${ACCOUNT_TYPE:-student}")"
        printf '"operator":"%s",' "$(health_json_escape "${OPERATOR:-DianXin}")"
        printf '"runtime":%s,' "$_runtime_json"
        printf '"details":%s' "$_details"
        printf '}\n'
    } >> "$HEALTH_LOGFILE"

    health_rotate_log_if_needed
    health_write_runtime_snapshot
    health_write_status_snapshot
}

health_human_summary() {
    health_load_config
    _remaining="$(health_remaining_seconds)"
    if [ "${HEALTH_MONITOR_ENABLED:-false}" != "true" ]; then
        echo "已关闭"
    elif [ "${HEALTH_MONITOR_MODE:-timed}" = "permanent" ]; then
        echo "已开启（永久）"
    else
        echo "已开启（剩余 ${_remaining:-0} 秒）"
    fi
}

health_print_json_envelope() {
    _command="$1"
    _payload="$2"
    printf '{'
    printf '"success":true,'
    printf '"command":"%s",' "$(health_json_escape "$_command")"
    printf '"schema_version":%s,' "$HEALTH_JSON_SCHEMA_VERSION"
    printf '"generated_at":"%s"' "$(health_json_escape "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")")"
    if [ -n "$_payload" ]; then
        printf ',%s' "$_payload"
    fi
    printf '}'
}

health_status_json() {
    health_apply_defaults
    health_expire_if_needed
    health_load_config
    _remaining="$(health_remaining_seconds)"
    _runtime_json="$(health_runtime_json)"
    _snapshot_json="$(health_snapshot_json)"
    _collector_active="$(health_collector_active)"
    _last_event_at=""
    if [ -f "$HEALTH_LOGFILE" ]; then
        _last_event_at="$(tail -n 1 "$HEALTH_LOGFILE" 2>/dev/null | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"
    fi
    health_write_runtime_snapshot
    health_write_status_snapshot
    health_print_json_envelope "health-status" \
        "\"enabled\":$(health_json_boolean "${HEALTH_MONITOR_ENABLED:-false}"),\"mode\":\"$(health_json_escape "${HEALTH_MONITOR_MODE:-timed}")\",\"until\":$(health_json_string "${HEALTH_MONITOR_UNTIL:-}"),\"remaining_seconds\":$(health_json_number_or_null "$_remaining"),\"collector_active\":$(health_json_boolean "$_collector_active"),\"baseline_interval\":$(health_json_number_or_null "${HEALTH_MONITOR_BASELINE_INTERVAL:-900}"),\"redaction\":\"$(health_json_escape "${HEALTH_MONITOR_REDACTION:-mask_password_and_session_only}")\",\"last_event_at\":$(health_json_string "$_last_event_at"),\"runtime\":${_runtime_json},\"snapshot\":${_snapshot_json}"
}

health_runtime_status_json() {
    _runtime_json="$(health_runtime_json)"
    _runtime_payload="${_runtime_json#\{}"
    _runtime_payload="${_runtime_payload%\}}"
    health_write_runtime_snapshot
    health_print_json_envelope "runtime-status" "$_runtime_payload"
}

health_enable_json() {
    _duration="$1"
    health_enable "$_duration" || return 1
    health_log_event "INFO" "monitor" "健康监听已启用 (${_duration})" "{}" >/dev/null 2>&1 || true
    health_load_config
    _remaining="$(health_remaining_seconds)"
    health_print_json_envelope "health-enable" \
        "\"message\":\"健康监听已启用\",\"enabled\":$(health_json_boolean "${HEALTH_MONITOR_ENABLED:-false}"),\"mode\":\"$(health_json_escape "${HEALTH_MONITOR_MODE:-timed}")\",\"until\":$(health_json_string "${HEALTH_MONITOR_UNTIL:-}"),\"remaining_seconds\":$(health_json_number_or_null "$_remaining")"
}

health_disable_json() {
    health_disable
    health_log_event "INFO" "monitor" "健康监听已禁用" "{}" >/dev/null 2>&1 || true
    health_load_config
    health_print_json_envelope "health-disable" \
        "\"message\":\"健康监听已禁用\",\"enabled\":$(health_json_boolean "${HEALTH_MONITOR_ENABLED:-false}"),\"mode\":\"$(health_json_escape "${HEALTH_MONITOR_MODE:-timed}")\",\"until\":$(health_json_string "${HEALTH_MONITOR_UNTIL:-}")"
}

health_log_json() {
    health_apply_defaults
    _lines="${1:-100}"
    _level="${2:-}"
    _type="${3:-}"
    _tmp_entries=""
    _count=0

    if [ -f "$HEALTH_LOGFILE" ]; then
        while IFS= read -r _line || [ -n "$_line" ]; do
            [ -n "$_line" ] || continue
            if [ -n "$_level" ] && ! printf '%s' "$_line" | grep -q "\"level\":\"${_level}\""; then
                continue
            fi
            if [ -n "$_type" ] && ! printf '%s' "$_line" | grep -q "\"type\":\"${_type}\""; then
                continue
            fi
            _tmp_entries="${_tmp_entries}${_tmp_entries:+,}${_line}"
            _count=$((_count + 1))
        done <<EOF
$(tail -n "$_lines" "$HEALTH_LOGFILE" 2>/dev/null)
EOF
    fi

    health_print_json_envelope "health-log" "\"entries\":[${_tmp_entries}],\"total\":${_count}"
}
