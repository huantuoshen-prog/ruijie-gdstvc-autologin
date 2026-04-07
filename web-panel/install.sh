#!/bin/sh
# ========================================
# Ruijie Web 管理面板 安装脚本
# 自动部署到 OpenWrt / iStoreOS 路由器
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
echo_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
echo_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  锐捷认证 Web 管理面板 安装程序"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ========================================
# 1. 检测运行环境
# ========================================
echo_info "检测路由器环境..."

if [ ! -f /etc/config/uhttpd ]; then
    echo_error "未检测到 uhttpd（Web 服务器），当前固件可能不支持"
    echo ""
    echo "  请确认你的路由器运行的是 OpenWrt、iStoreOS、ImmortalWrt 等衍生固件"
    echo "  或者手动安装：opkg update && opkg install uhttpd"
    exit 1
fi

echo_ok "uhttpd 已就绪"

# 检测持久化路径
if [ -d /overlay ]; then
    WEB_TARGET="/overlay/usr/www/ruijie-web"
    CGI_TARGET="/usr/ruijie-web/cgi"
    echo_ok "检测到 overlay 持久化存储"
elif [ -d /mnt/sda1 ]; then
    WEB_TARGET="/mnt/sda1/ruijie-web"
    CGI_TARGET="/mnt/sda1/ruijie-web/cgi"
    echo_warn "未检测到 overlay，使用 USB 存储路径: $WEB_TARGET"
else
    WEB_TARGET="/www/ruijie-web"
    CGI_TARGET="/usr/ruijie-web/cgi"
    echo_warn "未检测到 overlay 和 USB，使用临时路径（重启后需重新安装）"
fi

# 获取安装源目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ========================================
# 2. 复制文件
# ========================================
echo_info "安装 Web 文件到 $WEB_TARGET ..."

mkdir -p "$WEB_TARGET"
mkdir -p "$CGI_TARGET"

cp "${SCRIPT_DIR}/index.html" "$WEB_TARGET/"
cp "${SCRIPT_DIR}/api/"*.sh "$CGI_TARGET/"

chmod +x "$CGI_TARGET"/*.sh 2>/dev/null || true

echo_ok "文件已复制"

# ========================================
# 3. 配置 uhttpd 路由
# ========================================
echo_info "配置 uhttpd Web 路由..."

# 检查是否已有配置
if grep -q "ruijie-web" /etc/config/uhttpd 2>/dev/null; then
    echo_info "uhttpd 路由已配置，跳过"
else
    # 追加 CGI 解释器和路由
    uci set uhttpd.ruijie='uhttpd'
    uci set uhttpd.ruijie.listen_http='192.168.5.1:80'
    uci add_list uhttpd.ruijie.interpreter='.sh=/bin/sh'
    uci set uhttpd.ruijie.cgi_prefix='/ruijie-cgi'
    uci set uhttpd.ruijie.document_root="$WEB_TARGET"
    uci commit uhttpd
    echo_ok "uhttpd 路由已添加"
fi

# 重启 uhttpd
echo_info "重启 Web 服务..."
/etc/init.d/uhttpd restart 2>/dev/null || true

echo ""
echo_ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo_ok "  安装完成！"
echo_ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  访问地址：http://192.168.5.1/ruijie/"
echo ""
echo "  如果打不开，请检查："
echo "    1. 路由器 IP 是否为 192.168.5.1"
echo "    2. 电脑是否连接了路由器的 LAN 口或 WiFi"
echo ""
echo "  卸载：sh /usr/ruijie-web/cgi/uninstall.sh"
echo ""
