#!/bin/sh
# ========================================
# 配置文件读写模块
# 存储路径: ~/.config/ruijie/ruijie.conf
# 权限: 600 (仅本人可读写)
# ========================================

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        fix_config_perms
        _cfg_load "$CONFIG_FILE"
    fi
}

# 内部: 逐行解析配置文件
_cfg_load() {
    _cfg_file="$1"
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过注释和空行
        case "$line" in
            \#*|"") continue ;;
        esac
        key="$(echo "$line" | cut -d'=' -f1)"
        value="$(echo "$line" | cut -d'=' -f2-)"
        case "$key" in
            USERNAME)      USERNAME="$value" ;;
            PASSWORD)      PASSWORD="$value" ;;
            ACCOUNT_TYPE)  ACCOUNT_TYPE="$value" ;;
            DAEMON_INTERVAL)
                case "$value" in
                    ''|*[!0-9]*) DAEMON_INTERVAL=300 ;;
                    *) DAEMON_INTERVAL="$value" ;;
                esac ;;
        esac
    done < "$_cfg_file"
}

# 保存配置文件
save_config() {
    _username="$1"
    _password="$2"
    _account_type="${3:-student}"

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# Ruijie Auto-Login Configuration
# Generated $(date '+%Y-%m-%d %H:%M:%S')
USERNAME=$_username
PASSWORD=$_password
ACCOUNT_TYPE=$_account_type
DAEMON_INTERVAL=${DAEMON_INTERVAL:-300}
EOF
    chmod 600 "$CONFIG_FILE"
}

# 检查是否已配置
is_configured() {
    [ -f "$CONFIG_FILE" ] && grep -q "^USERNAME=" "$CONFIG_FILE" && grep -q "^PASSWORD=" "$CONFIG_FILE"
}

# 获取账号类型 (从配置或默认值)
get_account_type() {
    if [ -n "$ACCOUNT_TYPE" ]; then
        echo "$ACCOUNT_TYPE"
    elif [ -f "$CONFIG_FILE" ]; then
        fix_config_perms
        grep "^ACCOUNT_TYPE=" "$CONFIG_FILE" | cut -d= -f2-
    else
        echo "student"
    fi
}

# 交互式配置
interactive_config() {
    echo ""
    echo "=========================================="
    echo "  锐捷网络认证助手 - 交互式配置"
    echo "=========================================="
    echo ""

    echo -n "请选择账号类型 [1]学生 [2]教师 (默认: 1): "
    read _choice
    case "$_choice" in
        2|"") _at="teacher" ;;
        *) _at="student" ;;
    esac

    echo -n "请输入用户名 (学号/工号): "
    read _username
    while [ -z "$_username" ]; do
        echo "用户名不能为空"
        echo -n "请输入用户名: "
        read _username
    done

    echo -n "请输入密码: "
    read -s _password
    echo ""
    while [ -z "$_password" ]; do
        echo "密码不能为空"
        echo -n "请输入密码: "
        read -s _password
        echo ""
    done

    save_config "$_username" "$_password" "$_at"
    log_success "配置已保存到 $CONFIG_FILE"
    echo ""
}
