#!/bin/sh

# ========================================
# 广东科学技术职业学院 锐捷Web认证脚本
# 作者: 17388749803 (新维护者)
# 基于原error7904版本修改
# ========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

# 检查参数
if [ "${#}" -lt "2" ]; then
    echo "=========================================="
    echo "  广东科学技术职业学院 锐捷Web认证脚本"
    echo "=========================================="
    echo ""
    echo "用法: $0 <用户名> <密码>"
    echo ""
    echo "示例: $0 2023000001 123456"
    echo ""
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

echo ""
log_info "=========================================="
log_info "  锐捷网络认证助手 v2.0"
log_info "  广东科学技术职业学院专用"
log_info "=========================================="
echo ""

# 检测网络状态
log_step "检测网络连接状态..."

# 尝试多个检测地址
CHECK_URLS="http://www.google.cn/generate_204 http://www.baidu.com http://www.qq.com"
ONLINE=0

for url in $CHECK_URLS; do
    log_info "尝试连接: $url"
    response=$(curl -s -I -m 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$response" = "204" ] || [ "$response" = "200" ]; then
        ONLINE=1
        log_success "检测成功: $url (HTTP $response)"
        break
    fi
done

if [ "$ONLINE" = "1" ]; then
    log_success "网络已连接，无需认证！"
    exit 0
fi

log_warning "未检测到网络连接，开始认证流程..."

# 获取认证页面URL
log_step "获取认证页面..."
loginPageURL=$(curl -s -L -m 10 "http://www.google.cn/generate_204" 2>&1 | grep -oP "http[^'\"]+" | head -1)

if [ -z "$loginPageURL" ]; then
    # 尝试备用方法
    loginPageURL=$(curl -s -I -L -m 10 "http://www.baidu.com" 2>&1 | grep -i "location" | grep -oP "http[^'\"]+" | head -1)
fi

if [ -z "$loginPageURL" ]; then
    log_error "无法获取认证页面，请检查网络连接！"
    exit 1
fi

log_success "获取成功: $loginPageURL"

# 提取基础URL
loginURL=$(echo "$loginPageURL" | awk -F'?' '{print $1}')
if echo "$loginURL" | grep -q "index.jsp"; then
    loginURL="${loginURL/index.jsp/InterFace.do?method=login}"
fi

log_info "认证URL: $loginURL"

# 构建认证参数
log_step "构建认证参数..."

# 获取必要的参数
wlanuserip=$(echo "$loginPageURL" | grep -oP "wlanuserip=[^&]+" | head -1)
wlanacname=$(echo "$loginPageURL" | grep -oP "wlanacname=[^&]+" | head -1)
nasip=$(echo "$loginPageURL" | grep -oP "nasip=[^&]+" | head -1)
mac=$(echo "$loginPageURL" | grep -oP "mac=[^&]+" | head -1)
nasid=$(echo "$loginPageURL" | grep -oP "nasid=[^&]+" | head -1)

# 构建queryString
queryString="wlanuserip=$(echo $wlanuserip | cut -d= -f2)&wlanacname=$(echo $wlanacname | cut -d= -f2)&ssid=&nasip=$(echo $nasip | cut -d= -f2)&snmpagentip=&mac=$(echo $mac | cut -d= -f2)&t=wireless-v2&url=&apmac=&nasid=$(echo $nasid | cut -d= -f2)&vid=&port=&nasportid="

# URL编码
queryString="${queryString//&/%2526}"
queryString="${queryString//=/%253D}"

service="DianXin"

log_success "参数构建完成"

# 发送认证请求
log_step "正在提交认证信息..."
log_info "用户名: $USERNAME"

# 模拟浏览器
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 发送认证请求
authResult=$(curl -s -L -m 30 \
    -A "$USER_AGENT" \
    -e "$loginPageURL" \
    -b "EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=; EPORTAL_COOKIE_OPERATORPWD=;" \
    -d "userId=${USERNAME}&password=${PASSWORD}&service=${service}&queryString=${queryString}&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    "$loginURL" 2>&1)

# 检查结果
log_step "验证认证结果..."

# 再次检测网络
sleep 2
CHECK_URLS="http://www.google.cn/generate_204 http://www.baidu.com"
SUCCESS=0

for url in $CHECK_URLS; do
    response=$(curl -s -I -m 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$response" = "204" ] || [ "$response" = "200" ]; then
        SUCCESS=1
        break
    fi
done

if [ "$SUCCESS" = "1" ]; then
    echo ""
    log_success "=========================================="
    log_success "  认证成功！🎉"
    log_success "  现在可以正常上网了"
    log_success "=========================================="
    echo ""
    exit 0
else
    # 检查错误信息
    if echo "$authResult" | grep -qi "password"; then
        log_error "认证失败: 用户名或密码错误！"
    elif echo "$authResult" | grep -qi "验证码"; then
        log_error "认证失败: 需要输入验证码"
        log_info "当前脚本不支持验证码识别，请使用网页手动认证"
    elif echo "$authResult" | grep -qi "locked\|锁定"; then
        log_error "账号已被锁定，请稍后再试或联系网络管理员"
    else
        log_warning "认证结果未知，请检查"
        log_info "返回信息: $authResult"
    fi
    echo ""
    exit 1
fi
