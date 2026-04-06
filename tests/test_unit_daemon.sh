#!/bin/bash
# ========================================
# 单元测试: 退避算法纯内存测试（不依赖网络）
# 用法: bash tests/test_unit_daemon.sh
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0 FAIL=0
pass() { echo "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }

TMPDIR=$(mktemp -d)
_DAEMON_BACKOFF_FILE="${TMPDIR}/backoff"
_DAEMON_INTERVAL_SHORT=30

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# 模拟 _get_backoff_count
_get_backoff_count() {
    [ -f "$_DAEMON_BACKOFF_FILE" ] && cat "$_DAEMON_BACKOFF_FILE" 2>/dev/null || echo "0"
}

# 模拟 _calc_backoff_sleep（使用临时文件）
_calc_backoff_sleep() {
    _count=$(_get_backoff_count)
    _count=$((_count + 1))
    case "$_count" in
        1) _sleep=$_DAEMON_INTERVAL_SHORT ;;
        2) _sleep=60 ;;
        3) _sleep=120 ;;
        *) _sleep=300; _count=4 ;;
    esac
    echo "$_sleep"
    echo "$_count" > "$_DAEMON_BACKOFF_FILE"
}

# 模拟 _reset_backoff
_reset_backoff() {
    rm -f "$_DAEMON_BACKOFF_FILE" 2>/dev/null || true
}

echo "========== 退避算法测试 =========="

# 测试序列: 30 → 60 → 120 → 300 → 300
_reset_backoff

s1=$(_calc_backoff_sleep)
[ "$s1" = "30" ] && pass "第1次退避: 30s" || fail "第1次退避: 期望30, 得到 $s1"

s2=$(_calc_backoff_sleep)
[ "$s2" = "60" ] && pass "第2次退避: 60s" || fail "第2次退避: 期望60, 得到 $s2"

s3=$(_calc_backoff_sleep)
[ "$s3" = "120" ] && pass "第3次退避: 120s" || fail "第3次退避: 期望120, 得到 $s3"

s4=$(_calc_backoff_sleep)
[ "$s4" = "300" ] && pass "第4次退避: 300s（上限）" || fail "第4次退避: 期望300, 得到 $s4"

s5=$(_calc_backoff_sleep)
[ "$s5" = "300" ] && pass "第5次退避: 300s（维持上限）" || fail "第5次退避: 期望300, 得到 $s5"

# 测试 reset 后计数归零
_reset_backoff
s_after_reset=$(_calc_backoff_sleep)
[ "$s_after_reset" = "30" ] && pass "reset后重置为30s" || fail "reset后: 期望30, 得到 $s_after_reset"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
