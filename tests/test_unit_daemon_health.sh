#!/bin/bash
# ========================================
# 单元测试: daemon 健康事件采样
# 用法: bash tests/test_unit_daemon_health.sh
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

export HOME="${TMPDIR}/home"
mkdir -p "${HOME}/.config/ruijie"

. "${PROJECT_DIR}/lib/common.sh"
. "${PROJECT_DIR}/lib/config.sh"
. "${PROJECT_DIR}/lib/daemon.sh"
. "${PROJECT_DIR}/lib/health.sh"

CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
PIDFILE="${TMPDIR}/ruijie-daemon.pid"
LOGFILE="${TMPDIR}/ruijie-daemon.log"
HEALTH_CONFIG_FILE="${CONFIG_DIR}/health-monitor.conf"
HEALTH_LOGFILE="${TMPDIR}/ruijie-health.log"
HEALTH_STATUS_FILE="${TMPDIR}/ruijie-health.status.json"
RUNTIME_STATUS_FILE="${TMPDIR}/ruijie-runtime.status.json"
DAEMON_TEST_MAX_LOOPS=2

cat > "$CONFIG_FILE" <<'EOF'
USERNAME=student01
PASSWORD=student-pass
ACCOUNT_TYPE=student
OPERATOR=DianXin
DAEMON_INTERVAL=300
EOF

health_enable "1d" >/dev/null

check_network() { return 1; }
do_login() { return 1; }
sleep() { :; }

echo "========== daemon 健康采样测试 =========="

daemon_loop >/dev/null 2>&1 || true

if grep -q '"type":"network_error"' "$HEALTH_LOGFILE"; then
    pass "在线检测失败时写入 network_error 健康事件"
else
    fail "在线检测失败时未写入 network_error 健康事件"
fi

if grep -q '"type":"auth_failed"' "$HEALTH_LOGFILE"; then
    pass "认证失败时写入 auth_failed 健康事件"
else
    fail "认证失败时未写入 auth_failed 健康事件"
fi

if [ -f "$HEALTH_STATUS_FILE" ]; then
    pass "daemon 采样时会刷新健康状态快照"
else
    fail "daemon 采样时未刷新健康状态快照"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
