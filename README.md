# ruijie-gdstvc-autologin

> 广东科学技术职业学院（珠海/广州校区）校园网锐捷 Web 认证自动登录工具

支持**单电脑直连**和**路由器（OpenWrt）**两种部署方式，搭配可选的 [Web 管理面板](#web-管理面板) 可以在浏览器里管理所有功能。

---

## 工作原理

宿舍墙上网线插入设备后，浏览器会弹出锐捷认证页面，输入学号和密码才能上网。断开重连（路由器重启等）需要重新认证。

本脚本自动完成这个认证步骤，支持后台守护进程，断线自动重连。

---

## 架构一览

```
┌─────────────────────────────────────────────────┐
│                  校园网（锐捷认证服务器）              │
│              根据 MAC 地址识别上网设备               │
└──────────────────────────┬──────────────────────┘
                           │ 墙壁网线
           ┌───────────────┴───────────────┐
           │                               │
┌──────────▼──────────┐       ┌────────────▼───────────┐
│  方式一：电脑直连     │       │  方式二：OpenWrt 路由器  │
│  脚本在电脑上运行     │       │  脚本在路由器上运行      │
│  仅单台设备上网       │       │  全宿舍设备共享上网      │
└─────────────────────┘       │  ┌──────────────────┐  │
                               │  │ 锐捷认证脚本      │  │
                               │  │ ruijie.sh        │  │
                               │  └────────┬─────────┘  │
                               │           │            │
                               │  ┌────────▼─────────┐  │
                               │  │ Web 管理面板(可选)│  │
                               │  │ 浏览器管理界面    │  │
                               │  └─────────────────┘  │
                               └──────────────────────┘
```

---

## 快速开始

### 方式一：电脑直连（单设备）

**适用场景：** 只有一台电脑需要上网，没有路由器。

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

**适用场景：** 多台电脑/手机/游戏机同时上网，一台路由器搞定全宿舍。

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

**3. 启动守护进程**

```bash
cd /etc/ruijie
./ruijie.sh --daemon   # 后台运行，断线自动重连
```

**4. 验证**

```bash
./ruijie.sh --status
```

看到「运行中」或「已连接」即成功。

---

## 命令行参数

| 参数 | 说明 |
|------|------|
| `--student` | 使用学生账号（默认） |
| `--teacher` | 使用教师账号 |
| `-u 用户名 -p 密码` | 直接指定账号密码（非交互式） |
| `--operator DianXin\|LianTong` | 指定运营商（默认电信） |
| `--daemon` | 启动后台守护进程（推荐使用） |
| `--stop` | 停止守护进程 |
| `--status` / `--info` | 查看网络和认证状态 |
| `--logout` | 下线（断开网络连接） |
| `--setup` | 交互式重新配置账号 |
| `-v` / `--verbose` | 开启调试模式，显示详细日志 |
| `-h` / `--help` | 显示帮助信息 |
| `-V` / `--version` | 显示版本号 |

---

## 卸载与重装

### 卸载脚本

```bash
sh uninstall.sh          # 普通卸载（保留配置文件和账号）
sh uninstall.sh --purge  # 彻底清除（包含配置文件、账号信息、日志）
sh uninstall.sh --force  # 无需确认直接卸载
```

> 更换版本前建议先执行 `sh uninstall.sh --purge`，确保旧配置不影响新版本。

### 重装

```bash
# 1. 卸载旧版本
sh uninstall.sh --purge

# 2. 重新安装
sh /tmp/setup.sh
```

---

## Web 管理面板

如果你的路由器是 OpenWrt / iStoreOS，可以安装 Web 管理界面，在浏览器里管理脚本所有功能，无需敲命令。

```
http://192.168.5.1:8080/
```

**安装方法：**（前提：先完成上面的锐捷脚本安装）

```bash
wget -O /tmp/panel-install.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-web-panel/main/install.sh
chmod +x /tmp/panel-install.sh && sh /tmp/panel-install.sh
```

面板功能：状态监控 · 账号管理 · 守护进程控制 · 电信/联通切换 · 日志查看 · 代理设置

详情请查看 [ruijie-web-panel](https://github.com/huantuoshen-prog/ruijie-web-panel) 仓库。

---

## 常见问题

**认证失败（账号密码错误）**

```
1. 确认学号和密码输入正确（注意大小写）
2. 确认账号没有欠费
3. 确认当前连接的是电信网络（其他运营商可能不支持）
4. 重新配置：./ruijie.sh --setup
```

**提示"curl 未安装"（OpenWrt）**

```bash
opkg update && opkg install curl
```

**守护进程启动失败 / opkg 源全部失败**

> 这是因为路由器的 opkg 源指向 `19.07-SNAPSHOT`（快照版），腾讯云镜像站已下线该目录。setup.sh 会**自动修复**，只需重新运行安装脚本：

```bash
sh /tmp/setup.sh
```

若自动修复仍失败，手动一行命令搞定：

```bash
sed -i 's/19\.07-SNAPSHOT/19.07.10/g' /etc/opkg/distfeeds.conf && opkg update && opkg install coreutils-nohup
cd /etc/ruijie && ./ruijie.sh --daemon
```

**守护进程没有自动重连**

```bash
# 查看日志
tail -f /var/log/ruijie-daemon.log
# 按 Ctrl+C 退出
```

**联通网络无法认证**

请到 [Issues](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/issues) 反馈，说明具体宿舍楼。

---

## 运营商信息

| 宿舍楼 | 运营商 | 参数 |
|--------|--------|------|
| 9栋 - 22栋 | 联通 | `--operator LianTong` |
| 其他楼栋 | 电信 | `--operator DianXin`（默认）|

---

## 技术说明

本脚本模拟浏览器完成锐捷 Web 认证流程：

1. 访问 `http://www.google.cn/generate_204`，服务器返回携带认证参数的登录页面 URL
2. 从 URL 中提取 `wlanuserip`、`nasip`、`mac` 等设备参数
3. 用学号、密码组装 POST 请求，发送到认证接口
4. 解析服务器返回的 JSON，判断认证是否成功
5. 再次访问 `generate_204` 确认网络已连通

认证完成后，所有通过路由器上网的设备共享同一个认证身份（NAT 转换）。

---

## 项目结构

```
ruijie-gdstvc-autologin/
├── ruijie.sh              # 统一入口脚本
├── ruijie_student.sh      # 符号链接 -> ruijie.sh（学生模式）
├── ruijie_teacher.sh      # 符号链接 -> ruijie.sh（教师模式）
├── setup.sh               # 交互式安装脚本（含 opkg 源自动修复）
├── uninstall.sh           # 卸载脚本（--purge/--force）
├── lib/
│   ├── common.sh          # 颜色、日志、代理工具函数
│   ├── config.sh          # 配置文件读写
│   ├── network.sh         # 网络检测、认证请求
│   └── daemon.sh          # 守护进程状态机（支持 busybox fallback）
├── systemd/               # systemd 服务文件（Linux PC 用）
├── tests/                 # 单元测试
└── README.md
```

---

## 更新日志

### v3.1 (2026-04)

- 新增 `--logout` 下线功能
- 新增 `--status` / `--info` 增强状态显示
- 守护进程升级为状态机：在线检测间隔 600s，离线指数退避 30→60→120→300s
- 新增多实例互斥锁机制
- 新增单元测试
- 重构代码，消除大量重复逻辑
- **兼容性增强**：守护进程自动回退 nohup → busybox nohup → setsid
- **opkg 源自动修复**：安装时自动检测固件版本，修复失效的 snapshot 源为 release 源
- **卸载功能完善**：新增 `--purge`（彻底清除配置）、`--force`（无需确认），自动清理 rc.local 和 crontab

### v3.0 (2026-03)

- 统一入口脚本 `ruijie.sh`
- 密码安全存储（配置文件权限 600）
- 后台守护进程模式
- systemd 服务支持

---

> ⚠️ 原作者（error7904）已离校，本仓库为新维护版本，继续为广科院同学提供支持。
