#!/bin/bash
# ========================================
# 单元测试: 健康监听配置与窗口逻辑
# 用法: bash tests/test_unit_health.sh
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
mkdir -p "$HOME"

. "${PROJECT_DIR}/lib/common.sh"
. "${PROJECT_DIR}/lib/config.sh"
. "${PROJECT_DIR}/lib/health.sh"

CONFIG_DIR="${HOME}/.config/ruijie"
CONFIG_FILE="${CONFIG_DIR}/ruijie.conf"
HEALTH_CONFIG_FILE="${CONFIG_DIR}/health-monitor.conf"
HEALTH_LOGFILE="${TMPDIR}/ruijie-health.log"
HEALTH_STATUS_FILE="${TMPDIR}/ruijie-health.status.json"
RUNTIME_STATUS_FILE="${TMPDIR}/ruijie-runtime.status.json"
HEALTH_LOG_ROTATE_BYTES=256

echo "========== 健康监听配置测试 =========="

health_enable "3d" >/dev/null
if [ -f "$HEALTH_CONFIG_FILE" ]; then
    pass "启用健康监听后写入健康配置文件"
else
    fail "启用健康监听后未写入健康配置文件"
fi

health_load_config
[ "${HEALTH_MONITOR_ENABLED:-}" = "true" ] \
    && pass "health_enable 写入 enabled=true" \
    || fail "health_enable 未写入 enabled=true"
[ "${HEALTH_MONITOR_MODE:-}" = "timed" ] \
    && pass "3d 模式写入 timed" \
    || fail "3d 模式未写入 timed"
[ "${HEALTH_MONITOR_BASELINE_INTERVAL:-}" = "900" ] \
    && pass "默认基线采样间隔为 900 秒" \
    || fail "默认基线采样间隔错误: ${HEALTH_MONITOR_BASELINE_INTERVAL:-<empty>}"
[ "${HEALTH_MONITOR_REDACTION:-}" = "mask_password_and_session_only" ] \
    && pass "默认脱敏策略正确" \
    || fail "默认脱敏策略错误: ${HEALTH_MONITOR_REDACTION:-<empty>}"
[ -n "${HEALTH_MONITOR_UNTIL:-}" ] \
    && pass "timed 模式写入截止时间" \
    || fail "timed 模式未写入截止时间"

health_disable >/dev/null
health_load_config
[ "${HEALTH_MONITOR_ENABLED:-}" = "false" ] \
    && pass "health_disable 写入 enabled=false" \
    || fail "health_disable 未写入 enabled=false"
[ -z "${HEALTH_MONITOR_UNTIL:-}" ] \
    && pass "禁用后清空截止时间" \
    || fail "禁用后未清空截止时间"

health_enable "1d" >/dev/null
health_load_config
HEALTH_MONITOR_UNTIL=$((HEALTH_MONITOR_CREATED_AT - 1))
health_save_config
health_expire_if_needed >/dev/null
health_load_config
[ "${HEALTH_MONITOR_ENABLED:-}" = "false" ] \
    && pass "过期窗口会自动禁用健康监听" \
    || fail "过期窗口未自动禁用健康监听"

echo ""
echo "========== 健康日志与运行环境测试 =========="

health_log_event "ERROR" "auth_failed" "密码错误: secret-pass" '{"password":"secret-pass","cookie":"abc123"}' >/dev/null
if grep -q 'secret-pass' "$HEALTH_LOGFILE"; then
    fail "健康日志未正确脱敏密码"
else
    pass "健康日志会脱敏密码"
fi
if grep -q 'abc123' "$HEALTH_LOGFILE"; then
    fail "健康日志未正确脱敏会话类字段"
else
    pass "健康日志会脱敏会话类字段"
fi

health_log_event "INFO" "baseline" "first" "{}" >/dev/null
health_log_event "INFO" "baseline" "second" "{}" >/dev/null
health_log_event "INFO" "baseline" "third" "{}" >/dev/null
if [ -f "${HEALTH_LOGFILE}.1" ]; then
    pass "健康日志超过阈值后会轮转"
else
    fail "健康日志超过阈值后未轮转"
fi
if [ -f "$HEALTH_LOGFILE" ]; then
    pass "日志轮转后仍保留当前日志文件"
else
    fail "日志轮转后未保留当前日志文件"
fi

runtime_json="$(health_runtime_json)"
echo "$runtime_json" | grep -q '"platform":"' \
    && pass "运行环境 JSON 包含 platform" \
    || fail "运行环境 JSON 缺少 platform"
echo "$runtime_json" | grep -q '"health_logfile":"' \
    && pass "运行环境 JSON 包含 health_logfile" \
    || fail "运行环境 JSON 缺少 health_logfile"

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
