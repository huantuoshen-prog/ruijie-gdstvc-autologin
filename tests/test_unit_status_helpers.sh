#!/bin/bash
# ========================================
# 单元测试: 状态展示辅助函数
# 用法: bash tests/test_unit_status_helpers.sh
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

LOGFILE="${TMPDIR}/ruijie-daemon.log"
cat > "$LOGFILE" <<'EOF'
[2026-04-24 17:20:09] [ONLINE] 定期刷新 session...
[2026-04-24 17:30:12] [ONLINE] 在线检测正常 (1/10)
EOF

. "${PROJECT_DIR}/lib/common.sh"
. "${PROJECT_DIR}/lib/daemon.sh"

echo "========== 状态展示辅助函数测试 =========="

last_auth="$(get_last_auth_time 2>/dev/null || true)"
if [ "$last_auth" = "2026-04-24 17:30:12" ]; then
    pass "get_last_auth_time 保留日期与时间之间的空格"
else
    fail "get_last_auth_time 返回异常: ${last_auth:-<empty>}"
fi

mkdir -p "${TMPDIR}/proc/123"
cat > "${TMPDIR}/proc/uptime" <<'EOF'
1000.00 2000.00
EOF

{
    printf '123 (ruijie.sh) S'
    i=1
    while [ "$i" -le 18 ]; do
        printf ' 0'
        i=$((i + 1))
    done
    printf ' 5000'
    i=1
    while [ "$i" -le 30 ]; do
        printf ' 0'
        i=$((i + 1))
    done
    printf '\n'
} > "${TMPDIR}/proc/123/stat"

DAEMON_PROC_HZ=100
uptime_text="$(daemon_get_uptime 123 "${TMPDIR}/proc" 2>/dev/null || true)"
if [ "$uptime_text" = "15分钟50秒" ]; then
    pass "daemon_get_uptime 在 BusyBox ps 不支持时回退到 /proc"
else
    fail "daemon_get_uptime 回退结果异常: ${uptime_text:-<empty>}"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
