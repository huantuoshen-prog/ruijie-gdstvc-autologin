#!/bin/bash
# ========================================
# 网络检测与认证模块
# 多URL检测、登录参数提取、认证请求
# ========================================

# 获取认证页面URL
# 返回: 重定向到的登录页面URL
get_login_page_url() {
    _url="$1"
    _page=$(curl -s -L -m 10 "$_url" 2>&1)
    if [ -n "$_page" ]; then
        echo "$_page" | grep -oE "http[^'\"]+" | head -1
    fi
}

# 构建认证URL
build_login_url() {
    _login_page_url="$1"
    if [ -z "$_login_page_url" ]; then
        return 1
    fi

    _login_url=$(echo "$_login_page_url" | awk -F'?' '{print $1}')
    if echo "$_login_url" | grep -q "index.jsp"; then
        _login_url="${_login_url/index.jsp/InterFace.do?method=login}"
    fi
    echo "$_login_url"
}

# 动态提取queryString参数
build_query_string() {
    _login_page_url="$1"

    _wlanuserip=$(echo "$_login_page_url" | grep -oE "wlanuserip=[^&]+" | head -1)
    _wlanacname=$(echo "$_login_page_url" | grep -oE "wlanacname=[^&]+" | head -1)
    _nasip=$(echo "$_login_page_url" | grep -oE "nasip=[^&]+" | head -1)
    _mac=$(echo "$_login_page_url" | grep -oE "mac=[^&]+" | head -1)
    _nasid=$(echo "$_login_page_url" | grep -oE "nasid=[^&]+" | head -1)

    # 提取值
    _wlanuserip_v=$(echo "$_wlanuserip" | cut -d= -f2-)
    _wlanacname_v=$(echo "$_wlanacname" | cut -d= -f2-)
    _nasip_v=$(echo "$_nasip" | cut -d= -f2-)
    _mac_v=$(echo "$_mac" | cut -d= -f2-)
    _nasid_v=$(echo "$_nasid" | cut -d= -f2-)

    # 构建 queryString
    _qs="wlanuserip=${_wlanuserip_v}&wlanacname=${_wlanacname_v}&ssid=&nasip=${_nasip_v}&snmpagentip=&mac=${_mac_v}&t=wireless-v2&url=&apmac=&nasid=${_nasid_v}&vid=&port=&nasportid="

    # URL编码 (& -> %2526, = -> %253D)
    _qs="${_qs//&/%2526}"
    _qs="${_qs//=/%253D}"

    echo "$_qs"
}

# 获取服务类型
get_service_type() {
    _account_type="${1:-student}"
    case "$_account_type" in
        teacher) echo "default" ;;
        *) echo "DianXin" ;;
    esac
}

# 发送认证请求
send_auth_request() {
    _login_url="$1"
    _username="$2"
    _password="$3"
    _account_type="${4:-student}"

    _query_string="$(build_query_string "$(curl -s -L -m 10 "http://www.baidu.com" 2>&1 | grep -oE "http[^'\"]+" | head -1)")"
    _service="$(get_service_type "$_account_type")"
    _login_page_url=$(curl -s -I -m 5 -o /dev/null -w "%{redirect_url}" "http://www.baidu.com" 2>/dev/null)

    curl -s -L -m 30 \
        -A "$USER_AGENT" \
        -e "${_login_page_url:-http://www.baidu.com}" \
        -b "EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=; EPORTAL_COOKIE_OPERATORPWD=;" \
        -d "userId=${_username}&password=${_password}&service=${_service}&queryString=${_query_string}&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        "$_login_url" 2>&1
}

# 执行完整登录流程
do_login() {
    _username="$1"
    _password="$2"
    _account_type="${3:-student}"

    log_step "开始认证流程..."

    # 获取认证页面
    log_step "获取认证页面..."
    _login_page_url=$(curl -s -L -m 10 "http://www.baidu.com" 2>&1 | grep -oE "http[^\"']+" | head -1)

    if [ -z "$_login_page_url" ]; then
        _login_page_url=$(curl -s -I -L -m 10 "http://www.baidu.com" 2>&1 | grep -i "location" | grep -oE "http[^\"']+" | head -1)
    fi

    if [ -z "$_login_page_url" ]; then
        log_error "无法获取认证页面，请检查网络连接！"
        return 1
    fi

    log_success "获取成功: $_login_page_url"

    # 构建登录URL
    _login_url="$(build_login_url "$_login_page_url")"
    if [ -z "$_login_url" ]; then
        log_error "无法构建登录URL"
        return 1
    fi

    log_info "认证URL: $_login_url"

    # 发送认证请求
    log_step "正在提交认证信息..."
    log_info "用户名: $_username"
    log_info "账号类型: $_account_type"

    _result=$(send_auth_request "$_login_url" "$_username" "$_password" "$_account_type")

    # 分析响应内容判断成功与否
    _error=""
    if echo "$_result" | grep -qi "password\|密码错误\|用户不存在"; then
        _error="用户名或密码错误"
    elif echo "$_result" | grep -qi "验证码"; then
        _error="需要输入验证码"
    elif echo "$_result" | grep -qi "locked\|锁定"; then
        _error="账号已被锁定"
    elif echo "$_result" | grep -qi "已认证\|成功"; then
        _error=""
    fi

    if [ -n "$_error" ]; then
        echo ""
        log_error "认证失败: $_error"
        echo ""
        return 1
    fi

    echo ""
    log_success "=========================================="
    log_success "  认证成功！"
    log_success "=========================================="
    echo ""
    return 0
}
