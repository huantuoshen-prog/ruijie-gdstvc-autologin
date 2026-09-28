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
CONFIG_DIR="${TMPDIR}/config"

echo "========== 状态展示辅助函数测试 =========="

last_auth="$(get_last_auth_time 2>/dev/null || true)"
if [ -z "$last_auth" ]; then
    pass "在线检测和刷新不能冒充认证成功"
else
    fail "在线检测被错误记录为认证: $last_auth"
fi

cat >> "$LOGFILE" <<'EOF'
[2026-04-24 17:31:00] 认证成功! 服务器消息: ok
[2026-04-24 17:31:02] 认证可能未成功，网络连接失败
[2026-04-24 17:32:00] [CHECKING→ONLINE] 网络已恢复（未发起认证）
EOF
[ -z "$(get_last_auth_time || true)" ] && pass "服务器接受但验网失败、外部恢复均不算成功" || fail "失败或外部恢复被误报"
printf '%s\n' '[2026-04-24 17:33:12] [RETRYING→ONLINE] 认证成功，网络已恢复' >> "$LOGFILE"
[ "$(get_last_auth_time)" = '2026-04-24 17:33:12' ] && pass "识别通过验网的认证时间" || fail "未识别真正认证时间"
mv "$LOGFILE" "${LOGFILE}.1"
printf '%s\n' '[2026-04-24 17:40:12] [ONLINE] 在线检测正常 (1/10)' > "$LOGFILE"
[ "$(get_last_auth_time)" = '2026-04-24 17:33:12' ] && pass "日志轮转后保留最后认证时间" || fail "轮转后丢失认证时间"

LOGIN_RESULT_KIND=authenticated
_record_auth_outcome
saved_auth="$(get_last_auth_time)"
rm -f "$LOGFILE" "${LOGFILE}.1"
LOGIN_RESULT_KIND=already_online
_record_auth_outcome
[ -n "$saved_auth" ] && [ "$(get_last_auth_time)" = "$saved_auth" ] && pass "重启丢失内存日志后仍保留真正认证时间" || fail "持久认证时间丢失"
grep -q 'already_online$' "${CONFIG_DIR}/auth-outcomes.log" && pass "外部恢复单独保存且不改写认证时间" || fail "未保存外部恢复"
for ((i=0; i<70; i++)); do _record_auth_outcome; done
[ "$(wc -l < "${CONFIG_DIR}/auth-outcomes.log")" -eq 64 ] && pass "持久记录最多64条" || fail "持久记录未限制长度"
[ "$(get_last_auth_time)" = "$saved_auth" ] && pass "归属记录轮转不丢失最后认证时间" || fail "归属记录轮转丢失认证时间"

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
