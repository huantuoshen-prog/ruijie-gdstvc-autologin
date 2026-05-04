#!/bin/bash
# ========================================
# 单元测试: daemon 后台入口脚本选择
# 用法: bash tests/test_unit_daemon_entrypoint.sh
# ========================================

set -e

PROJECT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"

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

mkdir -p "${TMPDIR}/app"
touch "${TMPDIR}/app/ruijie.sh"

echo "========== daemon 入口脚本测试 =========="

result_with_ruijie="$(bash -c '
SCRIPT_DIR="$1"
. "$2/lib/daemon.sh"
_daemon_entry_script
' daemon "${TMPDIR}/app" "${PROJECT_DIR}")"

[ "$result_with_ruijie" = "${TMPDIR}/app/ruijie.sh" ] \
    && pass "优先使用 SCRIPT_DIR/ruijie.sh 作为后台入口" \
    || fail "未优先使用 ruijie.sh: ${result_with_ruijie:-<empty>}"

result_fallback="$(bash -c '
SCRIPT_DIR="$1"
. "$2/lib/daemon.sh"
_daemon_entry_script
' daemon "${TMPDIR}/missing" "${PROJECT_DIR}")"

[ "$result_fallback" = "${TMPDIR}/missing/daemon" ] \
    && pass "缺少 ruijie.sh 时回退到当前脚本名" \
    || fail "回退入口错误: ${result_fallback:-<empty>}"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
