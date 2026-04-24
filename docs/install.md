# 安装指南

这份文档是 `ruijie-gdstvc-autologin` 的详细安装入口，按运行环境拆成三类：

- 单电脑直连
- OpenWrt / iStoreOS / ImmortalWrt 路由器部署
- 开机自启与持久运行

## 电脑直连

### Windows

前置要求：

- 安装 [Git for Windows](https://git-scm.com/download/win)
- 使用 Git Bash 运行脚本

安装步骤：

```bash
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh
chmod +x ruijie.sh
./ruijie.sh --setup
./ruijie.sh --daemon
```

### Linux / macOS

```bash
wget -O ruijie.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

# 或 curl
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

chmod +x ruijie.sh
./ruijie.sh --setup
./ruijie.sh --daemon
```

## 路由器部署

适用前提：

- 路由器已刷 OpenWrt / iStoreOS / ImmortalWrt 等衍生固件
- WAN 口已连接校园网（墙壁网线）
- 可以进入路由器终端

### 如何进入路由器终端

#### 方式一：图形后台进入

1. 连接路由器 WiFi
2. 浏览器打开：
   - `http://192.168.5.1`（常见于 iStoreOS）
   - `http://192.168.1.1`（OpenWrt 默认）
3. 找到「系统」→「TTYD 终端」或「系统工具」→「命令行终端」

#### 方式二：SSH

```bash
ssh root@192.168.5.1
# 或
ssh root@192.168.1.1
```

### 安装步骤

```bash
wget -O /tmp/setup.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
chmod +x /tmp/setup.sh && sh /tmp/setup.sh
```

安装脚本会依次询问：

- 账号类型（学生 / 教师）
- 用户名
- 校园网密码
- 学生账号运营商（电信 / 联通）
- 是否配置代理

### 安装完成后验证

```bash
# 检查脚本目录
ls -la /etc/ruijie/

# 查看状态
/etc/ruijie/ruijie.sh --status

# 查看守护进程
ps | grep ruijie

# 查看日志
tail -f /var/log/ruijie-daemon.log
```

## 开机自启

### OpenWrt 路由器

安装脚本会自动配置开机自启。

如果你需要手动检查，可查看：

```bash
cat /etc/rc.local
```

### Linux systemd

普通 Linux 电脑上可启用 systemd：

```bash
systemctl enable ruijie
systemctl start ruijie
systemctl status ruijie
```

## 卸载

```bash
sh uninstall.sh
```

如果你希望彻底清除配置：

```bash
sh uninstall.sh --purge
```

## 下一步阅读

- 想看全部命令： [cli-and-config.md](./cli-and-config.md)
- 想了解 daemon 和健康监听： [daemon-and-health.md](./daemon-and-health.md)
- 安装中遇到问题： [troubleshooting.md](./troubleshooting.md)
