#!/bin/sh
# ========================================
# Mock HTTP Server for Integration Tests
# 模拟锐捷 ePortal 认证页面
# 监听 localhost:8888
# ========================================

PORT="${1:-8888}"

# 返回 204 (已在线)
handle_online() {
    cat << RESPONSE
HTTP/1.1 204 No Content

RESPONSE
}

# 返回认证重定向
handle_redirect() {
    cat << RESPONSE
HTTP/1.1 302 Found
Location: http://172.16.16.16:8080/eportal/index.jsp?wlanuserip=b0ca4cc70a0e85576592b062fd3c8eee&wlanacname=18260f9e92a595cf175b8f228a013c28&ssid=a94b524f709e97ce5d5f6888c069bef5&nasip=2a7140b6682505806cff617bac715e9d&mac=3dc484a0996e1f0641f13bcafc288276

RESPONSE
}

# 返回认证页面
handle_login_page() {
    cat << RESPONSE
HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html>
<head><title>Ruijie Portal</title></head>
<body>
<form action="http://172.16.16.16:8080/eportal/InterFace.do?method=login" method="POST">
<input name="userId" />
<input name="password" type="password" />
<input name="service" value="DianXin" />
</form>
</body>
</html>
RESPONSE
}

# 返回认证成功
handle_auth_success() {
    cat << RESPONSE
HTTP/1.1 200 OK
Content-Type: text/html

{"success":true,"message":"认证成功"}
RESPONSE
}

# 简单路由
route() {
    _path="$1"

    case "$_path" in
        *generate_204*)
            handle_online
            ;;
        *baidu*)
            handle_redirect
            ;;
        */InterFace.do*)
            handle_auth_success
            ;;
        *)
            handle_login_page
            ;;
    esac
}

# 启动简单 socat/nc 风格的监听
# 使用 bash 内建 /dev/tcp (如果支持) 或 socat
start_server() {
    printf "Mock server starting on port %s...\n" "$PORT"

    # 方法1: 尝试 socat
    if command -v socat >/dev/null 2>&1; then
        while true; do
            socat -T 1 TCP-LISTEN:"$PORT",reuseaddr,fork \
                "EXEC:'cat tests/test_data/auth_success.txt',派阠"
        done
        return
    fi

    # 方法2: 使用 Python (最通用)
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import http.server, socketserver, sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if 'generate_204' in self.path:
            self.send_response(204)
            self.end_headers()
        else:
            self.send_response(302)
            self.send_header('Location', 'http://localhost:$PORT/eportal/')
            self.end_headers()

    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'{\"success\":true}')

PORT = $PORT
with socketserver.TCPServer(('', PORT), Handler) as httpd:
    print(f'Mock server listening on port {PORT}')
    httpd.serve_forever()
"
        return
    fi

    # 方法3: 使用 netcat
    if command -v nc >/dev/null 2>&1; then
        while true; do
            printf "HTTP/1.1 204 No Content\r\n\r\n" | nc -l -p "$PORT" -q 1 2>/dev/null
        done
        return
    fi

    echo "ERROR: No suitable server available (need python3, socat, or nc)"
    exit 1
}

start_server
