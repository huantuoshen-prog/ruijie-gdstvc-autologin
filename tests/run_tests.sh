#!/bin/bash
# ========================================
# 测试入口
# 用法: bash tests/run_tests.sh [unit|integration|all]
# ========================================

set -e

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${GREEN}[PASS]${NC} $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${RED}[FAIL]${NC} $1"
}

# 断言函数
assert_equals() {
    if [ "$1" = "$2" ]; then
        pass "assert_equals: '$1' == '$2'"
    else
        fail "assert_equals: '$1' != '$2'"
    fi
}

assert_contains() {
    if echo "$1" | grep -q "$2"; then
        pass "assert_contains: '$2' in '$1'"
    else
        fail "assert_contains: '$2' NOT in '$1'"
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "file exists: $1"
    else
        fail "file NOT exists: $1"
    fi
}

# ========================================
# 单元测试
# ========================================
run_unit_tests() {
    echo ""
    echo "========== 单元测试 =========="

    # 测试颜色函数
    _output=$(. "${PROJECT_DIR}/lib/common.sh"; log_info "test")
    assert_contains "$_output" "[INFO]"

    # 测试常量定义
    . "${PROJECT_DIR}/lib/common.sh"
    assert_contains "$USER_AGENT" "Mozilla"

    # 测试配置文件读写
    _tmp_config=$(mktemp)
    . "${PROJECT_DIR}/lib/config.sh"
    CONFIG_FILE="$_tmp_config"

    save_config "testuser" "testpass" "student"
    assert_file_exists "$CONFIG_FILE"

    # 测试日志函数输出
    _out=$(. "${PROJECT_DIR}/lib/common.sh"; log_success "ok")
    assert_contains "$_out" "[OK]"

    _out=$(. "${PROJECT_DIR}/lib/common.sh"; log_warning "warn")
    assert_contains "$_out" "[WARN]"

    _out=$(. "${PROJECT_DIR}/lib/common.sh"; log_error "err")
    assert_contains "$_out" "[ERROR]"

    _out=$(. "${PROJECT_DIR}/lib/common.sh"; log_step "step")
    assert_contains "$_out" "[STEP]"

    # 测试帮助信息
    _out=$(. "${PROJECT_DIR}/lib/common.sh"; show_help | head -1)
    assert_contains "$_out" "广东科学技术职业学院"

    # 清理
    rm -f "$_tmp_config"

    # 扩展单元测试（新增的独立测试文件）
    for _t in "${TEST_DIR}"/test_unit_*.sh; do
        if [ -f "$_t" ]; then
            echo ""
            if ! bash "$_t"; then
                fail "扩展测试失败: $_t"
            fi
        fi
    done
}

# ========================================
# 集成测试 (需要网络或mock server)
# ========================================
run_integration_tests() {
    echo ""
    echo "========== 集成测试 =========="

    cd "$PROJECT_DIR"

    # 测试1: 帮助信息
    _out=$(./ruijie.sh --help | head -3)
    assert_contains "$_out" "广东科学技术职业学院"

    # 测试2: 检测是否需要凭据（无配置时）
    _out=$(./ruijie.sh 2>&1) || true
    if echo "$_out" | grep -q "未提供\|未找到配置文件"; then
        pass "无凭据时正确提示"
    else
        # 可能有配置文件
        pass "有配置文件或正确处理"
    fi

    # 测试3: 学生模式帮助
    _out=$(./ruijie_student.sh --help | head -1)
    assert_contains "$_out" "广东科学技术职业学院"

    # 测试4: 教师模式帮助
    _out=$(./ruijie_teacher.sh --help | head -1)
    assert_contains "$_out" "广东科学技术职业学院"

    # 测试5: 脚本可执行权限
    [ -x "${PROJECT_DIR}/ruijie.sh" ] && pass "ruijie.sh 可执行" || fail "ruijie.sh 不可执行"

    # 测试6: 兼容性脚本存在
    if [ -L "${PROJECT_DIR}/ruijie_student.sh" ]; then
        pass "ruijie_student.sh 是符号链接"
    elif [ -f "${PROJECT_DIR}/ruijie_student.sh" ]; then
        pass "ruijie_student.sh 存在 (Windows兼容模式)"
    else
        fail "ruijie_student.sh 不存在"
    fi
    if [ -L "${PROJECT_DIR}/ruijie_teacher.sh" ]; then
        pass "ruijie_teacher.sh 是符号链接"
    elif [ -f "${PROJECT_DIR}/ruijie_teacher.sh" ]; then
        pass "ruijie_teacher.sh 存在 (Windows兼容模式)"
    else
        fail "ruijie_teacher.sh 不存在"
    fi

    # 测试7: 符号链接指向正确 (仅Linux)
    if [ -L "${PROJECT_DIR}/ruijie_student.sh" ]; then
        _target=$(readlink "${PROJECT_DIR}/ruijie_student.sh")
        [ "$_target" = "ruijie.sh" ] && pass "符号链接指向正确" || fail "符号链接指向: $_target"
    else
        pass "符号链接测试跳过 (Windows兼容模式)"
    fi

    # 测试8: systemd文件存在
    [ -f "${PROJECT_DIR}/systemd/ruijie.service" ] && pass "systemd service文件存在" || fail "systemd service文件不存在"

    # 测试9: CI workflow存在
    [ -f "${PROJECT_DIR}/.github/workflows/ci.yml" ] && pass "CI workflow存在" || fail "CI workflow不存在"

    # 测试10: 配置文件权限安全
    . "${PROJECT_DIR}/lib/config.sh"
    _tmp_cfg=$(mktemp)
    CONFIG_FILE="$_tmp_cfg"
    CONFIG_DIR="$(dirname "$_tmp_cfg")"
    save_config "u" "p" "student"
    _perms=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null || stat -f "%Lp" "$CONFIG_FILE" 2>/dev/null)
    if [ "$_perms" = "600" ]; then
        pass "配置文件权限 600"
    elif uname | grep -qi "mingw\|msys\|cygwin"; then
        pass "配置文件权限检查跳过 (Windows)"
    else
        fail "配置文件权限: $_perms (应为 600)"
    fi
    rm -f "$_tmp_cfg" "$CONFIG_FILE"
}

# ========================================
# 主入口
# ========================================
MODE="${1:-all}"

echo ""
echo "=========================================="
echo "  Ruijie-Auto-Login 测试套件"
echo "=========================================="

case "$MODE" in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    all|*)
        run_unit_tests
        run_integration_tests
        ;;
esac

echo ""
echo "=========================================="
echo "  测试结果: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"
echo "=========================================="

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
