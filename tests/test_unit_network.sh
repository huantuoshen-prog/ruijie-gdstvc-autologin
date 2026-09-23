#!/bin/bash
# ========================================
# 单元测试: lib/network.sh 核心函数
# 用法: bash tests/test_unit_network.sh
# ========================================

set -e

PROJECT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
. "${PROJECT_DIR}/lib/common.sh"
. "${PROJECT_DIR}/lib/network.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0 FAIL=0

pass() { echo "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }

assert_equals() {
    if [ "$1" = "$2" ]; then
        pass "assert_equals: '$1' == '$2'"
    else
        fail "assert_equals: '$1' != '$2'"
    fi
}

assert_success() {
    if "$@" >/dev/null 2>&1; then
        pass "函数成功: $*"
    else
        fail "函数失败: $*"
    fi
}

assert_fail() {
    if "$@" >/dev/null 2>&1; then
        fail "期望失败但成功了: $*"
    else
        pass "正确失败: $*"
    fi
}

echo "========== build_login_url 测试 =========="

# 有 index.jsp 时替换
result=$(build_login_url "http://172.16.16.16/eportal/index.jsp?foo=bar")
assert_equals "$result" "http://172.16.16.16/eportal/InterFace.do?method=login"

# 没有 index.jsp 时只取路径部分（awk -F'?' 取第一段）
result=$(build_login_url "http://10.0.0.1/login.jsp?foo=bar")
assert_equals "$result" "http://10.0.0.1/login.jsp"

# 空输入应返回错误
assert_fail build_login_url ""
assert_fail build_login_url

# 保留查询参数部分（awk -F'?' 取第一段）
result=$(build_login_url "http://172.16.16.16:8080/eportal/index.jsp?wlanuserip=abc&nasip=xyz")
assert_equals "$result" "http://172.16.16.16:8080/eportal/InterFace.do?method=login"

echo ""
echo "========== get_portal_param 测试 =========="

portal_url='http://portal/eportal/index.jsp?mac=client-mac&apmac=access-point&port=port-id&nasportid=nas-port-id&ssid='
assert_equals "$(get_portal_param "$portal_url" mac)" "client-mac"
assert_equals "$(get_portal_param "$portal_url" apmac)" "access-point"
assert_equals "$(get_portal_param "$portal_url" port)" "port-id"
assert_equals "$(get_portal_param "$portal_url" nasportid)" "nas-port-id"
assert_equals "$(get_portal_param "$portal_url" ssid)" ""
assert_equals "$(get_portal_param "$portal_url" missing)" ""

echo ""
echo "========== get_service_type 测试 =========="

assert_equals "$(get_service_type teacher)" "default"
assert_equals "$(get_service_type student)" "DianXin"
assert_equals "$(get_service_type)" "DianXin"          # 默认值
assert_equals "$(get_service_type unknown)" "DianXin"   # 未知值

echo ""
echo "========== check_network 测试（mock）=========="

_orig_curl_with_proxy="$(declare -f curl_with_proxy)"

# 门户跳转可能来自 HTTP Location 头，不能只从响应正文找。
curl_with_proxy() {
    printf 'HTTP/1.1 302 Found\r\nLocation: http://portal.example/eportal/index.jsp?x=1\r\nContent-Length: 0\r\n\r\n'
}
result="$(get_login_page_url)"
assert_equals "$result" "http://portal.example/eportal/index.jsp?x=1"

# 保留旧网关用页面脚本输出门户地址的兼容方式。
curl_with_proxy() {
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\nlocation=\047http://portal.example/eportal/index.jsp?x=1\047;'
}
result="$(get_login_page_url)"
assert_equals "$result" "http://portal.example/eportal/index.jsp?x=1"

eval "$_orig_curl_with_proxy"

# mock: 返回 204（已在线）
curl_with_proxy() { echo "204"; }
assert_success check_network

# mock: 返回 000（网络不可达）
curl_with_proxy() { echo "000"; }
assert_fail check_network

# mock: 返回其他状态码（异常）
curl_with_proxy() { echo "302"; }
assert_fail check_network

# 还原原始函数，避免污染后续环境
eval "$_orig_curl_with_proxy"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
