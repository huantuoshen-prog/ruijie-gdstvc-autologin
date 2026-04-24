#!/bin/bash
# ========================================
# 单元测试: 首次安装健康窗口初始化
# 用法: bash tests/test_unit_health_setup.sh
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

run_bootstrap_case() {
    local case_root="$1"
    local create_script="$2"
    local create_config="$3"

    mkdir -p "$case_root/home" "$case_root/install" "$case_root/config"

    export HOME="$case_root/home"

    . "${PROJECT_DIR}/lib/common.sh"
    . "${PROJECT_DIR}/lib/config.sh"
    . "${PROJECT_DIR}/lib/health.sh"

    CONFIG_DIR="$case_root/config"
    CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
    HEALTH_CONFIG_FILE="${CONFIG_DIR}/health-monitor.conf"

    if [ "$create_script" = "yes" ]; then
        mkdir -p "$case_root/install"
        : > "$case_root/install/ruijie.sh"
    fi

    if [ "$create_config" = "yes" ]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<'EOF'
USERNAME=existing
PASSWORD=existing
ACCOUNT_TYPE=student
OPERATOR=DianXin
EOF
    fi

    health_bootstrap_on_first_install "$case_root/install/ruijie.sh" "$CONFIG_FILE" >/dev/null
}

echo "========== 首次安装健康窗口测试 =========="

run_bootstrap_case "$TMPDIR/fresh" "no" "no"
if [ -f "$TMPDIR/fresh/config/health-monitor.conf" ]; then
    pass "首次安装会初始化健康监听配置"
else
    fail "首次安装未初始化健康监听配置"
fi
if grep -q '^HEALTH_MONITOR_MODE=timed$' "$TMPDIR/fresh/config/health-monitor.conf"; then
    pass "首次安装默认使用 timed 模式"
else
    fail "首次安装未写入 timed 模式"
fi

run_bootstrap_case "$TMPDIR/existing-script" "yes" "no"
if [ -f "$TMPDIR/existing-script/config/health-monitor.conf" ]; then
    fail "已存在脚本时不应重新初始化健康监听"
else
    pass "已存在脚本时不会重新初始化健康监听"
fi

run_bootstrap_case "$TMPDIR/existing-config" "no" "yes"
if [ -f "$TMPDIR/existing-config/config/health-monitor.conf" ]; then
    fail "已存在配置时不应重新初始化健康监听"
else
    pass "已存在配置时不会重新初始化健康监听"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
