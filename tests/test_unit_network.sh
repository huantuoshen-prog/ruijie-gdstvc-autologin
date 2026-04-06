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
echo "========== get_service_type 测试 =========="

assert_equals "$(get_service_type teacher)" "default"
assert_equals "$(get_service_type student)" "DianXin"
assert_equals "$(get_service_type)" "DianXin"          # 默认值
assert_equals "$(get_service_type unknown)" "DianXin"   # 未知值

echo ""
echo "========== check_network 测试（不依赖网络）=========="

# check_network 依赖网络，只验证函数存在且可调用
assert_success check_network || true

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
