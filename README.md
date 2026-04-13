# 广东科学技术职业学院校园网锐捷认证工具

> 广东科学技术职业学院（珠海/广州校区）校园网锐捷 Web 认证自动登录工具

[![CI](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions/workflows/ci.yml/badge.svg)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-green)](https://github.com/koalaman/shellcheck)
[![版本](https://img.shields.io/badge/version-v3.1-blue)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin)

支持**单电脑直连**和**路由器（OpenWrt）**两种部署方式，搭配可选的 [Web 管理面板](https://github.com/huantuoshen-prog/ruijie-web-panel) 可以在浏览器里管理所有功能。

---

## 目录

- [项目简介](#项目简介)
- [快速开始](#快速开始)
- [命令行参数](#命令行参数)
- [工作原理](#工作原理)
- [配置文件说明](#配置文件说明)
- [详细安装指南](#详细安装指南)
- [进阶用法](#进阶用法)
- [守护进程详解](#守护进程详解)
- [常见问题](#常见问题)
- [开发者指南](#开发者指南)
- [版本历史](#版本历史)
- [相关项目](#相关项目)
- [许可证](#许可证)

---

## 项目简介

### 什么是锐捷认证？

广东科学技术职业学院的校园网采用锐捷 Web 认证系统。宿舍墙上的网线插入设备后，需要在浏览器输入学号和密码完成认证才能上网。断开重连（路由器重启等）后需要重新认证。

### 本项目能做什么？

本脚本自动完成锐捷 Web 认证流程，支持：
- 自动登录校园网，无需手动认证
- 后台守护进程运行，断线自动重连
- 支持学生账号和教师账号
- 支持电信、联通双运营商
- 电脑直连或路由器部署两种方式

### 功能列表

| 功能 | 说明 |
|------|------|
| 自动登录 | 插上网线自动认证，无需手动操作 |
| 断线重连 | 守护进程自动检测并重连 |
| 多设备共享 | 路由器部署，全宿舍设备共享上网 |
| 双运营商 | 支持电信（默认）和联通网络 |
| 账号类型 | 支持学生账号和教师账号 |
| 代理支持 | 可配置 HTTP/HTTPS 代理 |
| Web 管理 | 可选配 Web 面板，浏览器管理 |
| 多平台 | 支持 Linux 电脑和 OpenWrt 路由器 |

### 快速概览

| 项目 | 说明 |
|------|------|
| 当前版本 | v3.1 (2026-04-07) |
| 编程语言 | Shell (Bash) |
| 支持平台 | Linux、macOS、Windows (Git Bash)、OpenWrt |
| 许可证 | MIT |
| GitHub | [ruijie-gdstvc-autologin](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin) |

---

## 快速开始

### 方式一：电脑直连（单设备）

**适用场景**：只有一台电脑需要上网，没有路由器。

**1. 下载脚本**

```bash
# Windows (需先安装 Git Bash: https://git-scm.com/download/win)
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

# Linux / macOS
wget -O ruijie.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh
```

**2. 配置并认证**

```bash
chmod +x ruijie.sh
./ruijie.sh --setup   # 交互式输入学号和密码
./ruijie.sh --daemon  # 启动后台守护进程，断线自动重连
```

**3. 查看状态**

```bash
./ruijie.sh --status
```

---

### 方式二：路由器部署（多设备，推荐）

**适用场景**：多台电脑/手机/游戏机同时上网，一台路由器搞定全宿舍。

> 前提：路由器已刷 OpenWrt / iStoreOS / ImmortalWrt 等衍生固件

**1. 进入路由器终端**

<details>
<summary><b>方式 A：通过路由器后台（图形界面）</b></summary>

1. 电脑/手机连接路由器 WiFi
2. 浏览器访问 `192.168.5.1`（iStoreOS）或 `192.168.1.1`（OpenWrt 默认）
3. 登录后找到「系统」→「TTYD 终端」或「系统工具」→「命令行终端」
</details>

<details>
<summary><b>方式 B：通过 SSH（进阶用户）</b></summary>

```bash
ssh root@192.168.1.1
# 或
ssh root@192.168.5.1
```
</details>

**2. 下载并安装**

```bash
wget -O /tmp/setup.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
chmod +x /tmp/setup.sh && sh /tmp/setup.sh
```

脚本会依次询问：学号 → 校园网密码 → 运营商（电信/联通）→ 是否配置代理。完成后自动测试认证是否成功。

**3. 验证**

```bash
./ruijie.sh --status
```

看到「运行中」或「已连接」即成功。

---

## 命令行参数

### 参数完整列表

| 参数 | 说明 | 示例 |
|------|------|------|
| `--student` | 使用学生账号（默认） | `./ruijie.sh --student` |
| `--teacher` | 使用教师账号 | `./ruijie.sh --teacher` |
| `-u, --username 用户名` | 指定用户名（非交互式） | `./ruijie.sh -u 2023000001 -p 密码` |
| `-p, --password 密码` | 指定密码（非交互式） | `./ruijie.sh -u 2023000001 -p 123456` |
| `--operator DianXin\|LianTong` | 指定运营商（默认电信） | `./ruijie.sh --operator LianTong` |
| `--proxy URL` | 设置 HTTP 代理地址 | `./ruijie.sh --proxy http://127.0.0.1:7890` |
| `-d, --daemon` | 以后台守护进程模式运行（推荐） | `./ruijie.sh --daemon` |
| `--stop` | 停止守护进程 | `./ruijie.sh --stop` |
| `--status, --info` | 查看网络与认证状态 | `./ruijie.sh --status` |
| `--logout` | 下线（断开认证，所有设备断网） | `./ruijie.sh --logout` |
| `--setup` | 交互式配置账号信息 | `./ruijie.sh --setup` |
| `-v, --verbose` | 显示详细调试信息 | `./ruijie.sh -v` |
| `-h, --help` | 显示帮助信息 | `./ruijie.sh --help` |
| `-V, --version` | 显示版本号 | `./ruijie.sh --version` |

### 位置参数（向后兼容）

除选项参数外，也支持位置参数方式：

```bash
./ruijie.sh 2023000001 123456
# 等价于
./ruijie.sh -u 2023000001 -p 123456
```

### 符号链接说明

脚本支持通过符号链接名自动选择账号类型：

| 链接名 | 账号类型 |
|--------|----------|
| `ruijie.sh` | 学生账号（默认）|
| `ruijie_student.sh` | 学生账号 |
| `ruijie_teacher.sh` | 教师账号 |

在 Linux 上可通过以下方式创建：
```bash
ln -s ruijie.sh ruijie_student.sh
ln -s ruijie.sh ruijie_teacher.sh
```

### 退出码

| 退出码 | 常量名 | 说明 |
|--------|--------|------|
| 10 | `EXIT_NETWORK_UNREACHABLE` | 网络不可达 |
| 11 | `EXIT_AUTH_FAILED` | 认证失败（账号密码错误）|
| 12 | `EXIT_CONFIG_MISSING` | 配置缺失（未运行 --setup）|
| 13 | `EXIT_DAEMON_ALREADY_RUNNING` | 守护进程已在运行 |
| 14 | `EXIT_PERMISSION_DENIED` | 权限不足（需要 root）|

### 使用示例

```bash
# 交互式配置
./ruijie.sh --setup

# 学生账号登录
./ruijie.sh -u 2023000001 -p 123456

# 教师账号 + 联通网络
./ruijie.sh --teacher -u T00001 -p 123456 --operator LianTong

# 启动守护进程（推荐）
./ruijie.sh --daemon

# 查看状态
./ruijie.sh --status

# 下线（断开网络）
./ruijie.sh --logout

# 调试模式查看详细信息
./ruijie.sh -v
```

---

## 工作原理

### 认证流程

```
┌──────────────────────────────────────────────────────────────────────┐
│                         锐捷 Web 认证流程                              │
└──────────────────────────────────────────────────────────────────────┘

Step 1: 检查网络连接
        │
        ├─ HTTP 204 ──→ 网络已在线，无需认证，直接返回 ✓
        │
        ├─ HTTP 000 ──→ 网络不可达，继续认证流程
        │
        └─ 其他响应 ──→ 网络异常

Step 2: 获取登录页面 URL
        │
        └─ curl http://www.google.cn/generate_204
           → 服务器返回重定向到 portal URL
           → 格式: http://172.16.16.16:8080/eportal/index.jsp?wlanuserip=...&nasip=...&mac=...

Step 3: 提取动态参数
        │
        ├─ wlanuserip  用户IP
        ├─ wlanacname  AC名称
        ├─ nasip       NAS设备IP
        ├─ mac         设备MAC地址
        ├─ nasid       NAS ID
        ├─ vid         VLAN ID
        └─ url         认证后跳转URL

Step 4: 构建认证 URL
        │
        └─ index.jsp → InterFace.do?method=login
           → queryString 中的 & = 字符进行 URL 编码

Step 5: 获取服务类型
        │
        ├─ 教师账号 → service=default
        ├─ 学生 + 电信 → service=DianXin
        └─ 学生 + 联通 → service=LianTong

Step 6: 发送认证请求
        │
        └─ POST /InterFace.do?method=login
           Headers: User-Agent, Accept, Content-Type
           Cookies: 清空所有 EPORTAL_COOKIE_*
           Referer: portal URL
           Body: userId, password, service, queryString, passwordEncrypt=false

Step 7: 解析响应
        │
        ├─ result=success → 认证成功 ✓
        └─ result!=success → 认证失败 ✗

Step 8: 验证网络
        │
        └─ sleep 2 秒后再次检测 HTTP 204
           → 204 → 认证成功，网络已连接 ✓
           → 其他 → 认证可能失败
```

### 守护进程状态机

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           守护进程状态机                                 │
└─────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │     ONLINE      │
                              │   在线检测中     │
                              └────────┬────────┘
                                       │
           ┌───────────────────────────┴───────────────────────────┐
           │ 网络检测失败                                              │
           ▼                                                        ▼
┌─────────────────────┐                              ┌─────────────────────┐
│      CHECKING       │                              │       ONLINE        │
│    立即重试认证      │                              │   (每600s检测一次)   │
└─────────┬───────────┘                              │  (每10次刷新session) │
          │ 认证成功                                          └─────────────────────┘
          ▼                                                        ▲
┌─────────────────────┐                                             │
│      ONLINE        │◄────────────────────────────────────────────┘
│   认证成功 ✓       │              认证成功
└─────────────────────┘
          │
          │ 认证失败
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           RETRYING                                   │
│                        指数退避重试中                                 │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  第1次: 30秒  →  第2次: 60秒  →  第3次: 120秒  →  第4次+: 300秒  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
          │
          │ 连续4次失败
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           WAIT_LONG                                  │
│                        长时间等待状态                                  │
│                      每 300 秒尝试一次                                │
└─────────────────────────────────────────────────────────────────────┘
```

### 网络检测机制

使用 HTTP 204 状态码判断网络是否已认证：

| 响应码 | 含义 | 处理 |
|--------|------|------|
| HTTP 204 | 网络已在线，已认证 | 无需认证，直接返回 |
| HTTP 000 | 连接超时/无网络 | 开始认证流程 |
| 其他响应 | 网络异常 | 记录警告，继续尝试 |

---

## 配置文件说明

### 配置路径和权限

| 项目 | 说明 |
|------|------|
| 配置目录 | `~/.config/ruijie/` |
| 配置文件 | `~/.config/ruijie/ruijie.conf` |
| 权限要求 | 600（仅本人可读写）|

### 完整配置项

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `USERNAME` | 用户名（学号/工号）| - |
| `PASSWORD` | 密码 | - |
| `ACCOUNT_TYPE` | 账号类型：`student` 或 `teacher` | `student` |
| `OPERATOR` | 运营商：`DianXin`（电信）或 `LianTong`（联通）| `DianXin` |
| `DAEMON_INTERVAL` | 在线检测间隔（秒）| `300` |
| `PROXY_URL` | HTTP 代理地址（空=不使用）| 空 |
| `PROXY_URL_HTTPS` | HTTPS 代理地址（空=同 HTTP）| 空 |
| `NO_PROXY_LIST` | 不走代理的地址（逗号分隔）| 见下方默认值 |

**NO_PROXY_LIST 默认值：**
```
www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com
```

### 配置示例

```bash
# Ruijie Auto-Login Configuration
# Generated 2026-04-07 12:00:00
USERNAME=1720240564
PASSWORD=your_password
ACCOUNT_TYPE=student
OPERATOR=DianXin
DAEMON_INTERVAL=300

# --- Proxy Settings ---
PROXY_URL=
PROXY_URL_HTTPS=
NO_PROXY_LIST=www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com
```

### 代理配置说明

本脚本支持通过 HTTP 代理访问网络，适用于以下场景：
- 需要翻墙才能访问校园网认证服务器
- 网络环境需要通过代理上网

```bash
# 使用代理登录
./ruijie.sh -u 1720240564 -p 密码 --proxy http://127.0.0.1:7890

# 配置持久化代理
# 编辑 ~/.config/ruijie/ruijie.conf
PROXY_URL=http://127.0.0.1:7890
PROXY_URL_HTTPS=http://127.0.0.1:7890
```

---

## 详细安装指南

### 方式一：电脑直连

#### Windows 系统

**前置要求：**
- 安装 [Git for Windows](https://git-scm.com/download/win)

**步骤：**

1. 打开 Git Bash

2. 下载脚本：
```bash
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh
```

3. 添加执行权限：
```bash
chmod +x ruijie.sh
```

4. 运行配置向导：
```bash
./ruijie.sh --setup
```
按提示输入学号、密码即可。

5. 启动守护进程：
```bash
./ruijie.sh --daemon
```

#### Linux / macOS

```bash
# 下载脚本
wget -O ruijie.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

# 或使用 curl
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

# 添加执行权限
chmod +x ruijie.sh

# 配置账号
./ruijie.sh --setup

# 启动守护进程
./ruijie.sh --daemon
```

---

### 方式二：路由器部署

#### 前置要求

- 路由器已刷 OpenWrt / iStoreOS / ImmortalWrt 等衍生固件
- 路由器 WAN 口已连接校园网（墙壁网线）
- 能够进入路由器终端

#### 进入路由器终端

<details>
<summary><b>方法 1：通过路由器后台（适合大多数用户）</b></summary>

1. 电脑/手机连接路由器 WiFi
2. 浏览器访问：
   - iStoreOS：`http://192.168.5.1`
   - OpenWrt 默认：`http://192.168.1.1`
   - 小米路由器：`http://192.168.31.1`
3. 输入管理员密码登录
4. 找到「系统」→「TTYD 终端」或「系统工具」→「命令行终端」
</details>

<details>
<summary><b>方法 2：通过 SSH（进阶用户）</b></summary>

```bash
ssh root@192.168.5.1
# 或
ssh root@192.168.1.1
```

> 如果 SSH 连接失败，可能需要先在路由器后台开启 SSH 服务。
</details>

#### 安装步骤

1. **下载安装脚本**

```bash
wget -O /tmp/setup.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
```

> 如果路由器没有 wget，使用 curl：
> ```bash
> curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
> ```

2. **运行安装**

```bash
chmod +x /tmp/setup.sh && sh /tmp/setup.sh
```

3. **按照提示完成配置**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  锐捷网络认证配置工具
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

请选择账号类型 [1]学生 [2]教师 (默认: 1): 1

请选择你宿舍的网络运营商:
  [1] 电信 (9栋以外的大部分楼栋，默认)
  [2] 联通 (9栋 - 22栋)
请选择 [1/2]: 1

请输入用户名 (学号/工号): 1720240564
请输入密码: （输入时隐藏）

是否配置 HTTP 代理？直接回车跳过（不使用代理）: （直接回车）
```

4. **安装程序会自动：**
   - 检测并修复 opkg 源（如果固件版本是 SNAPSHOT）
   - 安装必要工具（curl、nohup）
   - 复制脚本到 `/etc/ruijie/`
   - 配置开机自启
   - 测试认证

#### 安装验证

```bash
# 检查脚本是否安装成功
ls -la /etc/ruijie/

# 测试认证
/etc/ruijie/ruijie.sh --status

# 查看守护进程是否运行
ps | grep ruijie

# 查看日志
tail -f /var/log/ruijie-daemon.log
```

---

## 进阶用法

### 运营商切换

不同楼栋使用不同运营商，请根据宿舍楼选择：

| 宿舍楼 | 运营商 | 参数 |
|--------|--------|------|
| 9栋 - 22栋 | 联通 | `--operator LianTong` |
| 其他楼栋 | 电信 | `--operator DianXin`（默认）|

```bash
# 切换到联通网络
./ruijie.sh --operator LianTong -u 1720240564 -p 密码

# 切换到电信网络
./ruijie.sh --operator DianXin -u 1720240564 -p 密码
```

### 代理配置

适用于需要通过代理上网的环境：

```bash
# 命令行指定代理
./ruijie.sh -u 1720240564 -p 密码 --proxy http://127.0.0.1:7890

# 持久化代理配置
# 编辑 ~/.config/ruijie/ruijie.conf
PROXY_URL=http://127.0.0.1:7890
PROXY_URL_HTTPS=http://127.0.0.1:7890
```

### systemd 服务（Linux PC）

在普通 Linux 电脑上，可以安装 systemd 服务实现开机自启：

```bash
# 安装服务（setup.sh 会询问是否安装）
systemctl enable ruijie
systemctl start ruijie

# 查看状态
systemctl status ruijie

# 查看日志
journalctl -u ruijie -f
```

### 开机自启配置

#### OpenWrt 路由器

安装时已自动配置开机自启（通过 `/etc/rc.local`）。

手动配置：
```bash
# 编辑 /etc/rc.local
vi /etc/rc.local

# 添加以下内容（如果不存在）
[ -d /etc/ruijie ] && cp -r /etc/ruijie /root/ruijie
[ -f /root/ruijie/ruijie.sh ] && /root/ruijie/ruijie.sh --daemon
```

#### crontab 定时任务

```bash
# 编辑 crontab
crontab -e

# 添加定时检测（每5分钟）
*/5 * * * * /etc/ruijie/ruijie.sh >> /var/log/ruijie-login.log 2>&1
```

### 手动触发认证

不使用守护进程，手动单次认证：

```bash
./ruijie.sh -u 1720240564 -p 密码
```

### 查看状态机当前状态

```bash
# 查看守护进程当前状态
cat /var/run/ruijie-daemon.state

# 查看退避计数
cat /var/run/ruijie-daemon.backoff
```

---

## 守护进程详解

### 后台运行原理

守护进程通过以下方式后台运行（自动选择可用工具）：

1. **nohup**（coreutils）— 优先使用
2. **busybox nohup** — 备选
3. **setsid** — 最后 fallback

### 多实例互斥锁

守护进程使用文件锁防止多实例启动：

- 锁文件：`/var/run/ruijie-daemon.lock`
- PID 文件：`/var/run/ruijie-daemon.pid`

如果遇到"守护进程已在运行"错误，先停止再启动：
```bash
./ruijie.sh --stop
./ruijie.sh --daemon
```

### 状态文件说明

| 文件 | 说明 |
|------|------|
| `/var/run/ruijie-daemon.pid` | 进程 PID |
| `/var/run/ruijie-daemon.state` | 当前状态（ONLINE/CHECKING/RETRYING/WAIT_LONG）|
| `/var/run/ruijie-daemon.backoff` | 退避计数 |
| `/var/run/ruijie-daemon.lock` | 多实例互斥锁 |
| `/var/log/ruijie-daemon.log` | 守护进程日志 |

### 日志查看

```bash
# 实时查看日志
tail -f /var/log/ruijie-daemon.log

# 查看最近100行
tail -n 100 /var/log/ruijie-daemon.log

# 搜索认证成功记录
grep "认证成功" /var/log/ruijie-daemon.log

# 搜索错误记录
grep "ERROR" /var/log/ruijie-daemon.log
```

---

## 常见问题

### 安装问题

<details>
<summary><b>提示"curl 未安装"</b></summary>

```bash
# OpenWrt 安装 curl
opkg update && opkg install curl
```
</details>

<details>
<summary><b>提示"opkg 源失败，SNAPSHOT 不可用"</b></summary>

setup.sh 会自动修复此问题，重新运行：
```bash
sh /tmp/setup.sh
```

如果自动修复失败，手动修复：
```bash
sed -i 's/19\.07-SNAPSHOT/19.07.10/g' /etc/opkg/distfeeds.conf
opkg update && opkg install coreutils-nohup
```
</details>

<details>
<summary><b>提示"缺少后台运行工具 (nohup/setsid)"</b></summary>

```bash
# 安装 nohup
opkg update && opkg install coreutils-nohup

# 或安装 busybox（含 nohup）
opkg update && opkg install busybox
```
</details>

### 使用问题

<details>
<summary><b>认证失败：账号密码错误</b></summary>

1. 确认学号和密码输入正确（注意大小写）
2. 确认账号没有欠费
3. 确认当前连接的是电信网络（其他运营商可能不支持）
4. 重新配置：
```bash
./ruijie.sh --setup
```
</details>

<details>
<summary><b>联通网络无法认证</b></summary>

请确认使用 `--operator LianTong` 参数，并确认宿舍楼栋（9栋-22栋使用联通）：
```bash
./ruijie.sh --operator LianTong -u 1720240564 -p 密码
```
</details>

<details>
<summary><b>守护进程没有自动重连</b></summary>

```bash
# 1. 检查守护进程是否在运行
ps | grep ruijie

# 2. 查看守护进程状态
./ruijie.sh --status

# 3. 查看日志
tail -f /var/log/ruijie-daemon.log

# 4. 如果守护进程未运行，手动启动
./ruijie.sh --daemon
```
</details>

<details>
<summary><b>守护进程启动后立即退出</b></summary>

1. 检查配置文件是否存在：
```bash
cat ~/.config/ruijie/ruijie.conf
```

2. 检查配置文件权限：
```bash
chmod 600 ~/.config/ruijie/ruijie.conf
```

3. 用调试模式启动查看错误：
```bash
./ruijie.sh -v --daemon
```
</details>

### 其他问题

<details>
<summary><b>如何完全停止守护进程</b></summary>

```bash
# 停止守护进程
./ruijie.sh --stop

# 确认已停止
ps | grep ruijie
```
</details>

<details>
<summary><b>如何完全卸载</b></summary>

```bash
# 普通卸载（保留配置）
sh uninstall.sh

# 彻底清除（包含配置、账号、日志）
sh uninstall.sh --purge

# 无需确认直接卸载
sh uninstall.sh --force
```
</details>

---

## 开发者指南

### 项目结构

```
ruijie-gdstvc-autologin/
├── ruijie.sh              # 统一入口脚本
├── ruijie_student.sh      # 符号链接 -> ruijie.sh（学生模式）
├── ruijie_teacher.sh      # 符号链接 -> ruijie.sh（教师模式）
├── setup.sh               # 交互式安装脚本（含 opkg 源自动修复）
├── uninstall.sh           # 卸载脚本（--purge/--force）
├── lib/                   # 工具函数库
│   ├── common.sh          # 颜色、日志、代理工具函数
│   ├── config.sh          # 配置文件读写
│   ├── network.sh         # 网络检测、认证请求
│   └── daemon.sh          # 守护进程状态机
├── systemd/               # systemd 服务文件
│   └── ruijie.service     # Linux PC systemd 服务
├── tests/                 # 单元测试 + 集成测试
└── README.md
```

### 模块说明

| 模块 | 主要函数 | 说明 |
|------|----------|------|
| `lib/common.sh` | `log_info()`, `curl_with_proxy()` | 日志输出、代理封装 |
| `lib/config.sh` | `load_config()`, `save_config()` | 配置读写 |
| `lib/network.sh` | `do_login()`, `check_network()` | 认证流程、网络检测 |
| `lib/daemon.sh` | `daemon_start()`, `daemon_loop()` | 守护进程管理 |

### 测试方法

```bash
# 运行所有测试
bash tests/run_tests.sh all

# 仅运行单元测试
bash tests/run_tests.sh unit

# 仅运行集成测试
bash tests/run_tests.sh integration
```

### 添加新运营商

1. 在 `lib/network.sh` 的 `get_service_type()` 函数中添加：
```bash
# 例如添加"移动"运营商
if [ "$_operator" = "YiDong" ]; then
    echo "YiDong"
fi
```

2. 在 `setup.sh` 中添加选择选项

3. 更新 README 中的运营商表格

---

## 版本历史

### v3.1 (2026-04-07)

**新增功能：**
- 新增 `--logout` 下线功能
- 新增 `--status` / `--info` 增强状态显示
- 新增守护进程状态文件 `/var/run/ruijie-daemon.state`
- 新增 `install_cron_task()` 安全的 crontab 安装函数
- 新增扩展单元测试
- 新增 `RUIJIE_VERSION`、`RUIJIE_BUILD_DATE` 全局常量
- 新增退出码常量（`EXIT_AUTH_FAILED=11` 等）
- 新增 `get_last_auth_time()` / `format_relative_time()` 辅助函数

**功能改进：**
- 守护进程从固定 300s 间隔升级为**状态机驱动**的动态间隔
- `check_network()` 区分 http_code=000（超时）、204（在线）、其他（异常）
- `do_login()` 使用 `trap RETURN` 确保 `EXTRA_NO_PROXY` 在任何退出路径都被清理
- `parse_args()` 重构位置参数解析逻辑
- 移除全局 `set -e`，避免 `check_network()` 等函数返回值冲突

**兼容性增强：**
- 守护进程自动回退 nohup → busybox nohup → setsid
- opkg 源自动修复：安装时自动检测固件版本，修复失效的 snapshot 源

**Bug 修复：**
- 修复 setup.sh crontab 任务追加到 `/dev/null` 的严重 bug
- 修复 `grep -v "ruijie"` 误删所有含 ruijie 的 cron 条目
- 修复 `check_network()` 对网络不可达无提示的问题
- 修复 `do_login()` 中途 return 时 `EXTRA_NO_PROXY` 残留

### v3.0 (2026-03)

- 统一入口脚本 `ruijie.sh`
- 密码安全存储（配置文件权限 600）
- 后台守护进程模式
- systemd 服务支持
- GitHub Actions CI
- 模块化代码结构

### v2.1 (2026-03)

- 支持 OpenWrt 路由器
- 自动配置 `/etc/rc.local` 开机同步
- 定时任务输出日志到 `/var/log/ruijie-login.log`

### 更早版本

- v2.0, v1.x 等早期版本

---

## 相关项目

| 项目 | GitHub | 说明 |
|------|--------|------|
| **ruijie-web-panel** | [链接](https://github.com/huantuoshen-prog/ruijie-web-panel) | Web 管理面板，可在浏览器管理账号和守护进程 |
| Qclaw | [链接](https://github.com/qiuzhi2046/Qclaw) | OpenClaw 桌面管家（非本项目）|

---

## 许可证

MIT License

Copyright (c) 2026 huantuoshen-prog

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
