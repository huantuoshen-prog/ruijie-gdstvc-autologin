# 锐捷认证 Web 管理面板

> 锐捷认证脚本的 Web 管理界面，在浏览器里管理账号、守护进程和查看日志，无需敲命令。

---

## 效果预览

```
┌─────────────────────────────────────────────────┐
│  锐捷认证 · Web 管理面板                    v3.1 │
├─────────────────────────────────────────────────┤
│  [状态] [账号] [守护进程] [日志] [设置]            │
├─────────────────────────────────────────────────┤
│                                                  │
│  网络状态              守护进程                   │
│  ┌──────────────┐     ┌──────────────┐           │
│  │ ● 已连接     │     │ ● 运行中     │           │
│  │  4h 23m     │     │  PID 1234    │           │
│  └──────────────┘     └──────────────┘           │
│                                                  │
│  账号: 1720240564   运营商: 电信                  │
│  状态机: ONLINE     最后认证: 2 分钟前            │
│                                                  │
│  [▶ 启动] [■ 停止] [↻ 重启]  [刷新状态]           │
└─────────────────────────────────────────────────┘
```

---

## 功能

- **状态监控**：在线/离线、守护进程状态、最后认证时间
- **账号管理**：修改用户名、密码、运营商
- **守护进程控制**：一键启动/停止/重启
- **网络模式切换**：电信/联通一键切换，自动重连
- **实时日志**：带级别过滤的日志查看器
- **代理设置**：HTTP/HTTPS 代理配置

---

## 安装（路由器终端运行）

### 第一步：下载安装脚本

```bash
wget -O /tmp/web-panel-install.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/web-panel/install.sh
```

### 第二步：赋予执行权限并运行

```bash
chmod +x /tmp/web-panel-install.sh
sh /tmp/web-panel-install.sh
```

### 第三步：访问

```
http://192.168.5.1/ruijie/
```

> 如果你的路由器 IP 不是 192.168.5.1，请替换为你路由器的实际 IP。

---

## 系统要求

- OpenWrt / iStoreOS / ImmortalWrt / 潘多拉等衍生固件
- 已安装锐捷认证脚本（请先运行 `setup.sh` 完成账号配置）
- 固件需包含 uhttpd（大多数固件默认自带）

---

## 卸载

```bash
# 删除 Web 文件
rm -rf /overlay/usr/www/ruijie-web
rm -rf /usr/ruijie-web

# 恢复 uhttpd 配置（可选）
uci del uhttpd.ruijie
uci commit uhttpd
/etc/init.d/uhttpd restart
```

---

## 安全提示

- **请设置 LuCI（路由器后台）访问密码**，否则同局域网任何人都可以访问管理面板
- 修改 LuCI 密码：系统 → 管理权 → 修改密码

---

## 故障排查

**Web 页面打不开**

```bash
# 检查 uhttpd 是否运行
/etc/init.d/uhttpd status

# 重启 uhttpd
/etc/init.d/uhttpd restart

# 检查文件是否在正确位置
ls /overlay/usr/www/ruijie-web/
```

**显示"锐捷脚本未安装"**

请先运行账号安装脚本：

```bash
cd /etc/ruijie && sh setup.sh
```

---

## 技术说明

- 后端：Shell CGI，每个 API 是一个独立脚本，返回 JSON
- 前端：纯 HTML + Vanilla JS，无依赖，单文件可直接部署
- 部署路径：`/overlay/usr/www/ruijie-web/`（持久化，重启不丢失）
- CGI 路径：`/ruijie-cgi/`（通过 uhttpd 配置路由）

---

## 项目地址

https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin
