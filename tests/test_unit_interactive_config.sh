#!/bin/bash
# ========================================
# 单元测试: interactive_config 交互式配置
# 用法: bash tests/test_unit_interactive_config.sh
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

run_interactive_config() {
    local config_root="$1"
    local answers="$2"

    mkdir -p "$config_root"

    (
        export HOME="$config_root/home"
        mkdir -p "$HOME"
        . "$PROJECT_DIR/lib/common.sh"
        . "$PROJECT_DIR/lib/config.sh"
        CONFIG_DIR="$config_root/config"
        CONFIG_FILE="$CONFIG_DIR/ruijie.conf"
        interactive_config >/tmp/ruijie-interactive-config.out <<EOF
$answers
EOF
        cat "$CONFIG_FILE"
    )
}

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "========== interactive_config 测试 =========="

teacher_cfg="$(run_interactive_config "$TMPDIR/teacher" $'2\nteacher01\nsecret-pass\n\n')"
if echo "$teacher_cfg" | grep -q '^ACCOUNT_TYPE=teacher$'; then
    pass "教师账号配置保留 teacher 类型"
else
    fail "教师账号类型未正确写入"
fi
if echo "$teacher_cfg" | grep -q '^OPERATOR=default$'; then
    pass "教师账号默认运营商写入 default"
else
    fail "教师账号默认运营商未写入 default"
fi

lian_tong_cfg="$(run_interactive_config "$TMPDIR/lian-tong" $'1\n2\nstudent02\npass-456\n\n')"
if echo "$lian_tong_cfg" | grep -q '^OPERATOR=LianTong$'; then
    pass "交互式配置支持写入联通运营商"
else
    fail "交互式配置未写入联通运营商"
fi

student_cfg="$(run_interactive_config "$TMPDIR/student" $'1\n\nstudent01\npass-123\n\n')"
if echo "$student_cfg" | grep -q '^ACCOUNT_TYPE=student$'; then
    pass "学生账号配置保留 student 类型"
else
    fail "学生账号类型未正确写入"
fi
if echo "$student_cfg" | grep -q '^OPERATOR=DianXin$'; then
    pass "学生账号默认运营商为电信"
else
    fail "学生账号默认运营商未写入电信"
fi

echo ""
echo "=========================================="
echo "  结果: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=========================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
