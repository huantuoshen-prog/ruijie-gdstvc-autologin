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
# 显式区分: 204=在线, 000=超时/不可达, 其他=异常
check_network() {
    _code=$(curl_with_proxy -s -I -m 10 -o /dev/null -w "%{http_code}" http://www.google.cn/generate_204 2>&1)
    case "$_code" in
        204) return 0 ;;
        000) log_warning "网络不可达（连接超时或无网络）" ;;
        *)   log_warning "网络检测意外响应码: $_code" ;;
    esac
    return 1
}

# 执行完整登录流程 (对齐工作脚本逻辑)
do_login() {
    _username="$1"
    _password="$2"
    _account_type="${3:-student}"

    # 函数入口立即清理上次的 EXTRA_NO_PROXY，RETURN trap 确保任何退出路径都清理
    unset EXTRA_NO_PROXY 2>/dev/null
    trap 'unset EXTRA_NO_PROXY 2>/dev/null' RETURN

    # 检查是否已连接
    log_step "检查网络连接状态..."
    if check_network; then
        log_success "网络连接正常，无需认证"
        return 0
    fi

    log_warning "未检测到网络连接，开始认证流程..."

    # 获取登录页面URL (对齐工作脚本: curl generate_204 + awk 提取)
    log_step "获取登录页面URL..."
    _login_page_url=$(curl_with_proxy -s "http://www.google.cn/generate_204" | awk -F \' '{print $2}')

    if [ -z "$_login_page_url" ]; then
        log_error "无法获取登录页面URL"
        return 1
    fi

    log_success "获取成功: $_login_page_url"

    # verbose 模式输出调试信息
    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo "[VERBOSE] portal URL: $_login_page_url"
    fi

    # 动态提取 portal 域名，追加到当次 no_proxy（防御性措施）
    _portal_host="$(echo "$_login_page_url" | sed -E 's|^https?://([^/:]+).*$|\1|')"
    if [ -n "$_portal_host" ] && ! echo "$(get_no_proxy_list)" | grep -q "$_portal_host"; then
        export EXTRA_NO_PROXY="$_portal_host"
    fi

    # 构建登录URL
    _login_url="$(build_login_url "$_login_page_url")"
    if [ -z "$_login_url" ]; then
        log_error "无法构建登录URL"
        return 1
    fi

    log_info "认证URL: $_login_url"

    if [ "$VERBOSE" = "true" ]; then
        echo "[VERBOSE] queryString: $_queryString"
        echo "[VERBOSE] service: $_service"
    fi

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

    authResult=$(curl_with_proxy -s -A "$USER_AGENT" \
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
        if [ "$VERBOSE" = "true" ]; then
            echo "[VERBOSE] 原始响应: $authResult"
        fi
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

# 执行下线操作
# 用法: do_logout [username]
# 返回: 0=成功/已离线, 1=失败(网络仍在线)
do_logout() {
    _username="${1:-${USERNAME:-}}"

    if [ -z "$_username" ]; then
        log_error "下线需要提供用户名"
        return 1
    fi

    # 函数入口清理 EXTRA_NO_PROXY
    unset EXTRA_NO_PROXY 2>/dev/null
    trap 'unset EXTRA_NO_PROXY 2>/dev/null' RETURN

    log_step "正在发送下线请求..."

    # 获取 portal URL 以构建 logout 地址
    _login_page_url=$(curl_with_proxy -s "http://www.google.cn/generate_204" 2>&1 | awk -F \' '{print $2}')

    if [ -n "$_login_page_url" ]; then
        _logout_url="$(build_login_url "$_login_page_url" | sed 's/method=login/method=logout/')"
    else
        # fallback: 尝试直接构造
        _logout_url="http://172.16.16.16/eportal/InterFace.do?method=logout"
    fi

    log_info "下线URL: $_logout_url"

    _result=$(curl_with_proxy -s -A "$USER_AGENT" \
        -b "EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=; EPORTAL_COOKIE_OPERATORPWD=;" \
        -d "userId=${_username}" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        "${_logout_url}" 2>&1)

    # 解析响应：成功时 result=true 或包含 success
    if echo "$_result" | grep -qiE '"result"[[:space:]]*:[[:space:]]*true|result.*:.*success'; then
        log_success "下线成功"
        return 0
    fi

    # 非JSON或失败，验证是否真的离线了
    if check_network; then
        log_warning "下线请求可能失败（网络仍在线）"
        log_info "服务器响应: ${_result:-无响应}"
        return 1
    else
        log_success "已离线"
        return 0
    fi
}
