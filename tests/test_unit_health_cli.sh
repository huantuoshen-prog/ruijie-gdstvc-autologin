#!/bin/bash
# ========================================
# 单元测试: 健康监听 CLI JSON 契约
# 用法: bash tests/test_unit_health_cli.sh
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

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    PYTHON_BIN=""
fi

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

export HOME="${TMPDIR}/home"
mkdir -p "${HOME}/.config/ruijie"

cat > "${HOME}/.config/ruijie/ruijie.conf" <<'EOF'
USERNAME=student01
PASSWORD=student-pass
ACCOUNT_TYPE=student
OPERATOR=DianXin
DAEMON_INTERVAL=300
PROXY_URL=
PROXY_URL_HTTPS=
NO_PROXY_LIST=www.google.cn
EOF

HEALTH_ENV=(
    "CONFIG_DIR=${HOME}/.config/ruijie"
    "CONFIG_FILE=${HOME}/.config/ruijie/ruijie.conf"
    "HEALTH_CONFIG_FILE=${HOME}/.config/ruijie/health-monitor.conf"
    "HEALTH_LOGFILE=${TMPDIR}/ruijie-health.log"
    "HEALTH_STATUS_FILE=${TMPDIR}/ruijie-health.status.json"
    "RUNTIME_STATUS_FILE=${TMPDIR}/ruijie-runtime.status.json"
    "PIDFILE=${TMPDIR}/ruijie-daemon.pid"
    "LOGFILE=${TMPDIR}/ruijie-daemon.log"
)

run_cli() {
    env "${HEALTH_ENV[@]}" "${PROJECT_DIR}/ruijie.sh" "$@"
}

echo "========== 健康监听 CLI 测试 =========="

enable_json="$(run_cli --health-enable 3d --json 2>/dev/null || true)"
echo "$enable_json" | grep -q '"success":true' \
    && pass "health-enable JSON 返回 success=true" \
    || fail "health-enable JSON 未返回 success=true"
echo "$enable_json" | grep -q '"command":"health-enable"' \
    && pass "health-enable JSON 返回 command" \
    || fail "health-enable JSON 未返回 command"
echo "$enable_json" | grep -q '"mode":"timed"' \
    && pass "health-enable JSON 返回 timed 模式" \
    || fail "health-enable JSON 未返回 timed 模式"

status_json="$(run_cli --health-status --json 2>/dev/null || true)"
echo "$status_json" | grep -q '"command":"health-status"' \
    && pass "health-status JSON 返回 command" \
    || fail "health-status JSON 未返回 command"
echo "$status_json" | grep -q '"enabled":true' \
    && pass "health-status JSON 返回 enabled=true" \
    || fail "health-status JSON 未返回 enabled=true"
echo "$status_json" | grep -q '"remaining_seconds":' \
    && pass "health-status JSON 返回 remaining_seconds" \
    || fail "health-status JSON 未返回 remaining_seconds"
echo "$status_json" | grep -q '"runtime":{' \
    && pass "health-status JSON 内嵌 runtime 摘要" \
    || fail "health-status JSON 未内嵌 runtime 摘要"

runtime_json="$(run_cli --runtime-status --json 2>/dev/null || true)"
echo "$runtime_json" | grep -q '"command":"runtime-status"' \
    && pass "runtime-status JSON 返回 command" \
    || fail "runtime-status JSON 未返回 command"
echo "$runtime_json" | grep -q '"platform":"' \
    && pass "runtime-status JSON 返回 platform" \
    || fail "runtime-status JSON 未返回 platform"
echo "$runtime_json" | grep -q '"schema_version":' \
    && pass "runtime-status JSON 返回 schema_version" \
    || fail "runtime-status JSON 未返回 schema_version"
if [ -z "$PYTHON_BIN" ]; then
    pass "运行环境中无 Python，跳过 JSON 语法校验"
elif printf '%s' "$runtime_json" | "$PYTHON_BIN" -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    pass "runtime-status 返回合法 JSON"
else
    fail "runtime-status 未返回合法 JSON"
fi

disable_json="$(run_cli --health-disable --json 2>/dev/null || true)"
echo "$disable_json" | grep -q '"enabled":false' \
    && pass "health-disable JSON 返回 enabled=false" \
    || fail "health-disable JSON 未返回 enabled=false"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
