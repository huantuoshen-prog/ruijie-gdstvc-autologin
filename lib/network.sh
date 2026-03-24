#!/bin/bash
# ========================================
# 网络检测与认证模块
# 对齐已验证的工作脚本逻辑
# ========================================

# 构建认证URL (从 index.jsp 替换为 InterFace.do?method=login)
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

# 获取服务类型
get_service_type() {
    _account_type="${1:-student}"
    case "$_account_type" in
        teacher) echo "default" ;;
        *) echo "DianXin" ;;
    esac
}

# 检查网络是否已连接 (HTTP 204 = 已认证)
check_network() {
    _code=$(curl -s -I -m 10 -o /dev/null -w "%{http_code}" http://www.google.cn/generate_204 2>/dev/null)
    [ "$_code" = "204" ]
}

# 执行完整登录流程 (对齐工作脚本逻辑)
do_login() {
    _username="$1"
    _password="$2"
    _account_type="${3:-student}"

    # 检查是否已连接
    log_step "检查网络连接状态..."
    if check_network; then
        log_success "网络连接正常，无需认证"
        return 0
    fi

    log_warning "未检测到网络连接，开始认证流程..."

    # 获取登录页面URL (对齐工作脚本: curl generate_204 + awk 提取)
    log_step "获取登录页面URL..."
    _login_page_url=$(curl -s "http://www.google.cn/generate_204" | awk -F \' '{print $2}')

    if [ -z "$_login_page_url" ]; then
        log_error "无法获取登录页面URL"
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

    # 从 portal URL 动态提取参数，构建 queryString
    _wlanuserip=$(echo "$_login_page_url" | grep -oE "wlanuserip=[^&]+" | cut -d= -f2-)
    _wlanacname=$(echo "$_login_page_url" | grep -oE "wlanacname=[^&]+" | cut -d= -f2-)
    _nasip=$(echo "$_login_page_url" | grep -oE "nasip=[^&]+" | cut -d= -f2-)
    _mac=$(echo "$_login_page_url" | grep -oE "mac=[^&]+" | cut -d= -f2-)
    _nasid=$(echo "$_login_page_url" | grep -oE "nasid=[^&]+" | cut -d= -f2-)

    _queryString="wlanuserip=${_wlanuserip}&wlanacname=${_wlanacname}&ssid=&nasip=${_nasip}&snmpagentip=&mac=${_mac}&t=wireless-v2&url=&apmac=&nasid=${_nasid}&vid=&port=&nasportid="
    _queryString="${_queryString//&/%2526}"
    _queryString="${_queryString//=/%253D}"

    _service="$(get_service_type "$_account_type")"

    # 发送认证请求 (对齐工作脚本的 curl 参数)
    log_step "向认证服务器发送请求..."
    log_info "用户名: $_username"
    log_info "账号类型: $_account_type"

    authResult=$(curl -s -A "$USER_AGENT" \
        -e "${_login_page_url}" \
        -b "EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=; EPORTAL_COOKIE_OPERATORPWD=;" \
        -d "userId=${_username}&password=${_password}&service=${_service}&queryString=${_queryString}&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        "${_login_url}" 2>&1)

    # 解析认证结果 (对齐工作脚本: 检查 JSON result 字段)
    echo ""
    log_step "解析认证服务器响应..."

    if echo "$authResult" | grep -q '"result"'; then
        _result=$(echo "$authResult" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        _message=$(echo "$authResult" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "无详细信息")

        if [ "$_result" = "success" ]; then
            log_success "认证成功! 服务器消息: $_message"
        else
            log_error "认证失败! 错误信息: $_message"
            echo ""
            return 1
        fi
    else
        # 非JSON响应
        log_info "服务器响应: $authResult"
    fi

    echo ""

    # 验证认证结果 (对齐工作脚本: sleep 2 后检查 HTTP 204)
    log_step "验证网络连接状态..."
    sleep 2

    if check_network; then
        echo ""
        log_success "=========================================="
        log_success "  校园网认证成功，网络已连接!"
        log_success "=========================================="
        echo ""
        return 0
    else
        echo ""
        log_error "认证可能未成功，网络连接失败"
        log_warning "请检查用户名和密码是否正确"
        echo ""
        return 1
    fi
}
