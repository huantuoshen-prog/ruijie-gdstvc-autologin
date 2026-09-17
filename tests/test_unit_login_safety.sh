#!/bin/bash
# ========================================
# 单元测试: do_login 安全回归
# 用法: bash tests/test_unit_login_safety.sh
# ========================================

set -e

PROJECT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
. "${PROJECT_DIR}/lib/common.sh"
. "${PROJECT_DIR}/lib/network.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# 避免 do_login 末尾验证前 sleep 2 拖慢测试。
sleep() { :; }

echo "========== do_login 安全回归测试 =========="

# 参数缺失过多时必须失败，不再使用硬编码 fallback queryString。
curl_with_proxy() {
    case "$*" in
        *" -I "*) printf '000' ;;
        *generate_204*) printf "location='http://172.16.16.16/eportal/index.jsp?wlanuserip=only-one'" ;;
        *) printf '{}' ;;
    esac
}

if do_login "user" "pass" "student" "DianXin" >/tmp/ruijie-login-missing.out 2>&1; then
    fail "关键参数缺失时 do_login 不应成功"
else
    if grep -q "缺少关键认证参数" /tmp/ruijie-login-missing.out; then
        pass "关键参数缺失时 do_login 明确失败且不使用 fallback"
    else
        fail "关键参数缺失时未输出明确错误"
    fi
fi

# 登录请求必须有连接和总超时，避免认证服务器无响应时永久阻塞。
CHECK_COUNT_FILE="${TMPDIR}/check-count"
printf '0' > "$CHECK_COUNT_FILE"
AUTH_ARGS_FILE="${TMPDIR}/auth_args.txt"
curl_with_proxy() {
    case "$*" in
        *" -I "*)
            _count="$(cat "$CHECK_COUNT_FILE" 2>/dev/null || echo 0)"
            _count=$((_count + 1))
            printf '%s' "$_count" > "$CHECK_COUNT_FILE"
            if [ "$_count" -eq 1 ]; then
                printf '000'
            else
                printf '204'
            fi
            ;;
        *generate_204*)
            printf "location='http://172.16.16.16/eportal/index.jsp?wlanuserip=ip&wlanacname=ac&ssid=campus&nasip=nas&snmpagentip=agent&mac=mac&t=wireless-v2&url=url&apmac=ap&nasid=nasid&vid=vid&port=port-id&nasportid=nas-port-id'"
            ;;
        *InterFace.do*)
            printf '%s' "$*" > "$AUTH_ARGS_FILE"
            printf '{"result":"success","message":"ok"}'
            ;;
        *)
            printf '{}'
            ;;
    esac
}

if do_login "user" "pass" "student" "DianXin" >/tmp/ruijie-login-timeout.out 2>&1; then
    if grep -q -- ' --connect-timeout 10 ' "$AUTH_ARGS_FILE" && grep -q -- ' --max-time 30 ' "$AUTH_ARGS_FILE"; then
        pass "登录 curl 请求包含连接与总超时"
    else
        fail "登录 curl 请求缺少连接或总超时: $(cat "$AUTH_ARGS_FILE" 2>/dev/null)"
    fi
    if grep -q -- '%2526ssid%253Dcampus' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526snmpagentip%253Dagent' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526apmac%253Dap' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526port%253Dport-id%2526nasportid%253Dnas-port-id' "$AUTH_ARGS_FILE"; then
        pass "登录请求保留门户返回的设备定位参数"
    else
        fail "登录请求丢失门户设备定位参数: $(cat "$AUTH_ARGS_FILE" 2>/dev/null)"
    fi
else
    fail "mock 登录流程应成功"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
