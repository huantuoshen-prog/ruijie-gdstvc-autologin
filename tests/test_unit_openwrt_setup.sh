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

echo "========== 旧安装入口退役回归测试 =========="

if grep -q 'setup.sh has been retired in v4.0.0' "$SETUP_FILE"; then
    pass "旧入口明确指向 v4 固定发布包"
else
    fail "旧入口缺少迁移说明"
fi

if grep -q '\*/5 \* \* \* \* test -f /var/run/ruijie-daemon.pid' "$SETUP_FILE"; then
    fail "cron 看门狗会破坏停止语义，不能重新引入"
else
    pass "不再安装全天 cron 看门狗"
fi

if grep -q '\*/5 5-7 \* \* \* \$INSTALL_TARGET/ruijie\.sh >> /var/log/ruijie-login\.log 2>&1' "$SETUP_FILE"; then
    fail "仍保留旧的 5-7 点登录 cron"
else
    pass "已移除旧的 5-7 点登录 cron"
fi

if grep -q 'opkg\|systemctl\|crontab\|rc.local' "$SETUP_FILE"; then
    fail "旧入口仍尝试修改系统或安装依赖"
else
    pass "旧入口不修改系统、不自动认证"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
