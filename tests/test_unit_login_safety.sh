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
            printf '%s\n' "$@" > "$AUTH_ARGS_FILE"
            printf '{"result":"success","message":"ok"}'
            ;;
        *)
            printf '{}'
            ;;
    esac
}

if do_login "user" "pass" "student" "DianXin" >/tmp/ruijie-login-timeout.out 2>&1; then
    if awk '
        previous == "--connect-timeout" && $0 == "10" { connect_timeout = 1 }
        previous == "--max-time" && $0 == "30" { max_time = 1 }
        { previous = $0 }
        END { exit !(connect_timeout && max_time) }
    ' "$AUTH_ARGS_FILE"; then
        pass "登录 curl 请求包含连接与总超时"
    else
        fail "登录 curl 请求缺少连接或总超时: $(cat "$AUTH_ARGS_FILE" 2>/dev/null)"
    fi
    if grep -q -- '%2526ssid%253Dcampus' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526snmpagentip%253Dagent' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526apmac%253Dap' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526mac%253Dmac%2526t%253Dwireless-v2' "$AUTH_ARGS_FILE" \
        && grep -q -- '%2526port%253Dport-id%2526nasportid%253Dnas-port-id' "$AUTH_ARGS_FILE"; then
        pass "登录请求保留门户返回的设备定位参数"
    else
        fail "登录请求丢失门户设备定位参数: $(cat "$AUTH_ARGS_FILE" 2>/dev/null)"
    fi
    if awk '
        previous == "--data" && /^queryString=/ { raw = 1 }
        previous == "--data-urlencode" && /^queryString=/ { extra_encoded = 1 }
        { previous = $0 }
        END { exit !(raw && !extra_encoded) }
    ' "$AUTH_ARGS_FILE"; then
        pass "queryString 保持锐捷协议要求的编码层数"
    else
        fail "queryString 被 curl 额外编码或未作为原始表单字段发送"
    fi
else
    fail "mock 登录流程应成功"
fi

# Exercise real do_login control flow with synthetic responses and credentials.
# No network call or installed router configuration is used.
curl_with_proxy() {
    case "$*" in
        *" -I "*)
            _count="$(cat "$CHECK_COUNT_FILE")"
            printf '%s' "$((_count + 1))" > "$CHECK_COUNT_FILE"
            if [ "$_count" -eq 0 ]; then printf '%s' "$INITIAL_CODE"; else printf '%s' "$POST_CODE"; fi
            ;;
        *generate_204*)
            printf '%s\r\n\r\n' 'HTTP/1.1 302 Found
Location: http://172.16.16.16/eportal/index.jsp?wlanuserip=ip&wlanacname=ac&nasip=nas&mac=mac&nasid=nasid&vid=vid'
            ;;
        *InterFace.do*)
            printf 'posted\n' >> "$AUTH_ARGS_FILE"
            printf '%s' "$MOCK_RESPONSE"
            return "$TRANSPORT_RC"
            ;;
        *) return 99 ;;
    esac
}
login_case() {
    local label="$1" expected_rc="$2" expected_kind="$3" actual_rc=0
    printf '0' > "$CHECK_COUNT_FILE"
    : > "$AUTH_ARGS_FILE"
    if do_login user pass student DianXin > "${TMPDIR}/case.out" 2>&1; then actual_rc=0; else actual_rc=$?; fi
    if [ "$actual_rc" -eq "$expected_rc" ] && [ "$LOGIN_RESULT_KIND" = "$expected_kind" ]; then
        pass "$label"
    else
        fail "$label: rc=$actual_rc kind=$LOGIN_RESULT_KIND"
    fi
}
INITIAL_CODE=302 POST_CODE=204 TRANSPORT_RC=0
MOCK_RESPONSE=$'{\n  "result": "success",\n  "message": "ok"\n}'
login_case "格式化JSON成功响应可正常认证" 0 authenticated
POST_CODE=302
login_case "服务器成功但验网失败不能算认证成功" 1 failed
! grep -q '认证成功' "${TMPDIR}/case.out" && pass "验网失败前不输出成功日志" || fail "过早输出成功日志"
POST_CODE=204
MOCK_RESPONSE='{"result": "fail", "message": "denied"}'
login_case "明确拒绝不能被外部网络恢复掩盖" 1 failed
for MOCK_RESPONSE in '<html>error</html>' '{}' '{invalid' '{"result":"success"}{"result":"fail"}'; do
    login_case "无效响应不得归因为自动认证" 1 failed
done
MOCK_RESPONSE='{"result":"success"}' TRANSPORT_RC=28
login_case "传输超时即使携带成功片段也不能算成功" 1 failed
TRANSPORT_RC=0 INITIAL_CODE=204
login_case "原已在线明确归为非本次认证" 0 already_online
[ ! -s "$AUTH_ARGS_FILE" ] && pass "已在线时没有提交认证请求" || fail "已在线仍提交了认证"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
