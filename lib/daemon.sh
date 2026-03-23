#!/bin/bash
# ========================================
# 守护进程模块
# pidfile 管理、信号处理、后台循环
# ========================================

# 获取脚本所在目录
_get_script_dir() {
    if [ -n "$SCRIPT_DIR" ]; then
        echo "$SCRIPT_DIR"
        return
    fi
    _d="$(dirname "${0}")"
    if [ "$_d" = "." ]; then
        _d="$(pwd)"
    elif echo "$_d" | grep -q "^/"; then
        # 绝对路径
        :
    else
        # 相对路径，转为绝对路径
        _pwd="$(pwd)"
        _d="$_pwd/$_d"
    fi
    echo "$_d"
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
        log_success "守护进程已停止"
    else
        log_warning "守护进程未运行，无需停止"
    fi
}

# 启动守护进程（前台循环，由daemon_launch调用）
daemon_loop() {
    _interval="${DAEMON_INTERVAL:-300}"

    # 信号处理
    _daemon_cleanup() {
        log_info "收到退出信号，正在停止守护进程..."
        rm -f "$PIDFILE"
        exit 0
    }
    trap '_daemon_cleanup' SIGTERM SIGINT SIGHUP

    log_success "守护进程已启动 (PID $$)"
    log_info "检测间隔: ${_interval} 秒"

    while true; do
        _timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        # 尝试登录
        if is_online; then
            echo "[$_timestamp] 网络已连接" >> "$LOGFILE" 2>/dev/null || true
        else
            echo "[$_timestamp] 检测到断线，开始认证..." >> "$LOGFILE" 2>/dev/null || true
            _login_result=0
            do_login "$USERNAME" "$PASSWORD" "$ACCOUNT_TYPE" >> "$LOGFILE" 2>&1 || _login_result=$?

            if [ "$_login_result" = "0" ]; then
                echo "[$_timestamp] 认证成功" >> "$LOGFILE" 2>/dev/null || true
            else
                echo "[$_timestamp] 认证失败 (退出码: $_login_result)" >> "$LOGFILE" 2>/dev/null || true
            fi
        fi

        sleep "$_interval"
    done
}

# 后台启动守护进程
daemon_start() {
    if daemon_is_running; then
        _pid=$(cat "$PIDFILE")
        log_warning "守护进程已在运行 (PID $_pid)"
        return 1
    fi

    # 确保有配置
    if ! is_configured; then
        log_error "未检测到配置，请先运行 '$0 --setup' 进行配置"
        return 1
    fi

    # 加载配置
    load_config

    # 创建日志目录
    _logdir="$(dirname "$LOGFILE")"
    mkdir -p "$_logdir" 2>/dev/null || true

    # 后台启动
    nohup "$0" --daemon-loop >> "$LOGFILE" 2>&1 &
    _pid=$!
    echo "$_pid" > "$PIDFILE"

    # 确保进程真正启动
    sleep 1
    if kill -0 "$_pid" 2>/dev/null; then
        log_success "守护进程已启动 (PID $_pid)"
        log_info "日志文件: $LOGFILE"
        return 0
    else
        rm -f "$PIDFILE"
        log_error "守护进程启动失败"
        return 1
    fi
}
