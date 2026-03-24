# Ruijie-Auto-Login 🔐

> 广东科学技术职业学院(广科/科干) 锐捷Web认证脚本 v3.0

![GitHub](https://img.shields.io/github/license/17388749803/Ruijie-Auto-Login)
![GitHub stars](https://img.shields.io/github/stars/17388749803/Ruijie-Auto-Login)

---

## ⚠️ 重要提示

原作者（error7904）已离校，本仓库为**新维护版本**，继续为广科院同学提供支持。

---

## 📋 简介

本脚本用于广东科学技术职业学院（珠海校区/广州校区）的锐捷 ePortal 网页认证自动化。

---

## 🏢 校园网运营商信息

| 宿舍楼 | 运营商 |
|--------|--------|
| 9栋 - 22栋 | 联通 📶 |
| 其他楼栋 | 电信 📶 |

> 📌 **注意**: 联通网络用户如遇问题，请提交 [Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues) 反馈

---

## 📱 关于多设备检测

校园网会检测多设备同时上网，但解决方法很简单：

### NAT 原理

校园网通过 **MAC 地址** 识别设备。NAT (网络地址转换) 让校园网只识别到**一个 MAC 地址**。

### 解决方案

使用 **OpenWrt** 或其衍生版本（ImmortalWrt、PandoraBox 等）的路由器，默认已启用 NAT。

**操作步骤：**
1. 路由器 WAN 口连接校园网网口
2. 电脑/手机连接路由器 WiFi 或网线
3. 路由器自动完成 NAT 转换

---

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 📊 实时日志 | 每一步都有详细状态提示 |
| 🌐 多环境适配 | 自动检测多种网络环境 |
| 🎨 彩色输出 | 终端界面清晰直观 |
| 🔄 自动重试 | 智能检测网络状态 |
| ❌ 错误提示 | 详细中文错误信息 |
| ⚡ 一键配置 | setup.sh 互动式安装 |
| 🛡️ 安全存储 | 密码不再写入 crontab |
| 🔄 后台守护 | 断线自动重连 |
| 📦 systemd | Linux 原生服务管理 |
| 🧪 CI/CD | GitHub Actions 自动检查 |

---

## 🚀 快速开始

### 一键配置（推荐 ✅）

```bash
# 下载配置脚本
wget -O setup.sh https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/setup.sh

# 运行配置（需要 root 权限）
chmod +x setup.sh
sudo sh setup.sh
```

支持普通 Linux 和 **OpenWrt 路由器**（自动检测）。

配置过程：
1. ✅ 自动检测系统环境
2. ✅ 自动下载认证脚本
3. ✅ **互动式中文界面**，输入账号密码
4. ✅ 自动测试认证
5. ✅ 自动配置定时任务
6. ✅ OpenWrt 自动配置开机自启

---

## 📖 手动安装

### 方式1：克隆仓库 (推荐)

```bash
git clone https://github.com/17388749803/Ruijie-Auto-Login.git
cd Ruijie-Auto-Login
chmod +x ruijie.sh lib/*.sh
```

### 方式2：直接下载

```bash
wget https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/ruijie.sh
chmod +x ruijie.sh
```

---

## 💻 使用方法

### 统一入口 (推荐)

```bash
# 学生登录
./ruijie.sh --student -u 你的学号 -p 你的密码

# 教师登录
./ruijie.sh --teacher -u 你的工号 -p 你的密码

# 兼容旧方式 (自动识别学生/教师)
./ruijie_student.sh 你的学号 你的密码
./ruijie_teacher.sh 你的工号 你的密码

# 交互式配置 (存储到安全配置文件)
./ruijie.sh --setup
```

### 后台守护进程

```bash
# 启动守护进程 (后台运行，断线自动重连)
./ruijie.sh --daemon

# 查看守护进程状态
./ruijie.sh --status

# 停止守护进程
./ruijie.sh --stop
```

### systemd 服务

```bash
# 安装服务
sudo cp systemd/ruijie.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ruijie

# 启动/停止
sudo systemctl start ruijie
sudo systemctl stop ruijie
sudo systemctl status ruijie

# 查看日志
journalctl -u ruijie -f
```

### 命令行参数

```
--student            使用学生账号模式 (默认)
--teacher            使用教师账号模式
-u, --username 用户名  指定用户名
-p, --password 密码   指定密码
-d, --daemon          以后台守护进程模式运行
--stop               停止守护进程
--status             查看守护进程状态
--setup              交互式配置账号信息
-h, --help           显示帮助信息
```

---

## 🔒 安全说明

### 凭据存储

密码不再存储在 crontab 中（之前版本的明文安全隐患），改用安全配置文件：

```
~/.config/ruijie/ruijie.conf   (权限 600)
```

配置文件格式：
```bash
# Ruijie Auto-Login Configuration
USERNAME=你的学号
PASSWORD=你的密码
ACCOUNT_TYPE=student
DAEMON_INTERVAL=300
```

### 查看/修改配置

```bash
# 查看当前配置
cat ~/.config/ruijie/ruijie.conf

# 修改配置 (重新运行安装脚本)
sudo sh setup.sh

# 手动编辑
vim ~/.config/ruijie/ruijie.conf
chmod 600 ~/.config/ruijie/ruijie.conf
```

---

## 🗑️ 卸载

```bash
# 下载卸载脚本
wget -O uninstall.sh https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/uninstall.sh

# 运行卸载（需要 root 权限）
chmod +x uninstall.sh
sudo sh uninstall.sh
```

卸载内容：守护进程、systemd 服务、脚本文件、配置文件、日志文件。

---

## 📝 输出示例

```
==========================================
  锐捷网络认证助手 v3.0
  广东科学技术职业学院专用
==========================================

[STEP] 检测网络连接状态...
[WARN] 未检测到网络连接，开始认证流程...
```

---

## 📁 项目结构

```
Ruijie-Auto-Login/
├── ruijie.sh              # 统一入口脚本
├── ruijie_student.sh      # 符号链接 -> ruijie.sh (向后兼容)
├── ruijie_teacher.sh      # 符号链接 -> ruijie.sh (向后兼容)
├── setup.sh               # 一键安装配置脚本
├── uninstall.sh           # 卸载脚本
├── lib/
│   ├── common.sh          # 颜色、日志函数、常量
│   ├── config.sh          # 配置文件读写 (chmod 600)
│   ├── network.sh         # 网络检测、认证请求
│   └── daemon.sh          # 守护进程管理
├── systemd/
│   └── ruijie.service     # systemd 服务文件
├── tests/
│   ├── run_tests.sh       # 测试入口
│   ├── mock_server.sh     # Mock HTTP 服务器
│   └── test_data/         # 测试数据
├── .github/
│   └── workflows/
│       └── ci.yml         # GitHub Actions CI
├── README.md
└── LICENSE
```

---

## ⏰ 定时任务（自动登录）

使用 **一键配置** 时会自动设置：

| 项目 | 设置 |
|------|------|
| 时间 | 每天 5:00 - 7:00 |
| 间隔 | 每5分钟 |
| 日志 | `/var/log/ruijie-login.log` |
| 密码 | 存储在 `~/.config/ruijie/ruijie.conf` (安全) |

### 手动配置

```bash
# 编辑定时任务
crontab -e

# 添加任务 (密码自动从配置文件读取)
*/5 5-7 * * * /usr/local/bin/ruijie-login
```

> **安全提示**: 新版本不再把密码写入 crontab，密码通过安全配置文件 (chmod 600) 自动读取。

---

## ❓ 常见问题

### Q: 提示"需要输入验证码"？
> 当前脚本不支持验证码识别，请在网页端手动认证后再使用脚本。

### Q: 认证失败？
> 1. 检查用户名和密码是否正确
> 2. 检查网络是否正常
> 3. 尝试更换检测地址

### Q: 路由器上运行失败？
> 确保已安装 curl：`opkg install curl`

### Q: 联通网络不能用？
> 请提交 [Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues) 反馈

---

## 🔧 网络维护说明

| 项目 | 负责范围 |
|------|----------|
| 🏢 学校 | 墙壁网口 |
| 👤 用户 | 路由器及之后 |

---

## 📜 更新日志

### v2.1 (2026-03)
- `setup.sh` 支持 OpenWrt 路由器（自动检测，安装到 `/etc/ruijie/`）
- OpenWrt 下自动配置 `/etc/rc.local` 开机同步脚本
- 修复 `setup.sh` 只复制 `ruijie.sh` 而忽略 `lib/` 目录的问题
- 定时任务在 OpenWrt 下输出日志到 `/var/log/ruijie-login.log`
- 跳过 systemd 服务安装（OpenWrt 不使用 systemd）

### v3.0 (2026-03)
- 统一入口脚本 `ruijie.sh`（通过 `--student` / `--teacher` 区分）
- `ruijie_student.sh` / `ruijie_teacher.sh` 改为符号链接（向后兼容）
- 安全改进：密码存储在配置文件 (chmod 600)，不再写入 crontab
- 后台守护进程模式 (`-d/--daemon`)
- systemd 服务支持
- GitHub Actions CI (shellcheck + 测试)
- 模块化代码结构 (`lib/` 目录)

### v2.1 (2025-03)
- 新增一键配置脚本 (setup.sh)
- 互动式中文安装界面
- 自动配置定时任务
- README 优化排版

### v2.0 (2025-03)
- 实时日志输出
- 多环境适配
- 彩色终端输出
- 错误处理优化

### v1.x
- 原始版本

---

## 📄 许可证

[GPL-3.0](LICENSE)

---

## 🤝 致谢

- 原作者: [error7904](https://github.com/error7904)
- 参考: [RuijiePortalLoginShellScript](https://github.com/1203746884/RuijiePortalLoginShellScript)

---

## 📧 联系

- GitHub: https://github.com/17388749803/Ruijie-Auto-Login
- 问题反馈: [提交 Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues)
