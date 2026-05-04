#!/bin/bash
# ========================================
# 单元测试: OpenWrt 安装脚本关键回归检查
# 用法: bash tests/test_unit_openwrt_setup.sh
# ========================================

set -e

PROJECT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
SETUP_FILE="${PROJECT_DIR}/setup.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }

echo "========== OpenWrt 安装脚本回归测试 =========="

if grep -q 'ruijie\.sh --daemon >> /var/log/ruijie-daemon\.log 2>&1' "$SETUP_FILE"; then
    pass "rc.local/cron 使用 ruijie.sh --daemon 作为守护进程入口"
else
    fail "未找到 ruijie.sh --daemon 守护进程入口"
fi

if grep -q '\*/5 \* \* \* \* test -f /var/run/ruijie-daemon.pid' "$SETUP_FILE"; then
    pass "OpenWrt cron 已改为全天 watchdog"
else
    fail "OpenWrt cron 仍不是全天 watchdog"
fi

if grep -q '\*/5 5-7 \* \* \* \$INSTALL_TARGET/ruijie\.sh >> /var/log/ruijie-login\.log 2>&1' "$SETUP_FILE"; then
    fail "仍保留旧的 5-7 点登录 cron"
else
    pass "已移除旧的 5-7 点登录 cron"
fi

if grep -q 'OPENWRT_ACTIVE_DIR="/root/ruijie"\|cp -r /etc/ruijie /root/ruijie' "$SETUP_FILE"; then
    fail "setup.sh 仍依赖 /root/ruijie 同步路径"
else
    pass "setup.sh 不再依赖 /root/ruijie 同步路径"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
