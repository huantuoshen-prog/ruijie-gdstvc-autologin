# 仓库维护文档

## 仓库基本信息

| 项目 | 内容 |
|------|------|
| **仓库名称** | ruijie-gdstvc-autologin |
| **GitHub URL** | https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin |
| **描述** | 广东科学技术职业学院（珠海/广州校区）校园网锐捷 Web 认证自动登录工具 |
| **当前版本** | v3.1 (2026-04-07) |
| **维护者** | huantuoshen-prog |
| **编程语言** | Shell (Bash) |
| **许可证** | MIT |

---

## 功能概述

### 核心功能
- 自动完成广东科学技术职业学院校园网锐捷 Web 认证
- 支持**单电脑直连**和**OpenWrt 路由器**两种部署方式
- 后台守护进程运行，断线自动重连
- 状态机驱动，动态指数退避重试（30s→60s→120s→300s）
- 支持**电信/联通**双运营商

### 支持的账号类型
- 学生账号 (`--student`)
- 教师账号 (`--teacher`)

### 支持的运营商
| 宿舍楼 | 运营商 | 参数 |
|--------|--------|------|
| 9栋 - 22栋 | 联通 | `--operator LianTong` |
| 其他楼栋 | 电信 | `--operator DianXin`（默认）|

---

## 技术架构

### 项目结构
```
ruijie-gdstvc-autologin/
├── ruijie.sh              # 统一入口脚本
├── ruijie_student.sh      # 符号链接 -> ruijie.sh（学生模式）
├── ruijie_teacher.sh      # 符号链接 -> ruijie.sh（教师模式）
├── setup.sh               # 交互式安装脚本（含 opkg 源自动修复）
├── uninstall.sh           # 卸载脚本（--purge/--force）
├── lib/
│   ├── common.sh          # 颜色、日志、代理工具函数、常量定义
│   ├── config.sh          # 配置文件读写（~/.config/ruijie/ruijie.conf）
│   ├── network.sh         # 网络检测、认证请求、登录/下线
│   └── daemon.sh          # 守护进程状态机、后台启动/停止
├── systemd/               # systemd 服务文件（Linux PC 用）
├── tests/                 # 单元测试 + 集成测试
└── README.md
```

### 核心模块说明

#### lib/common.sh
- **版本常量**: `RUIJIE_VERSION`, `RUIJIE_BUILD_DATE`
- **退出码**: `EXIT_NETWORK_UNREACHABLE=10`, `EXIT_AUTH_FAILED=11`, `EXIT_CONFIG_MISSING=12`, `EXIT_DAEMON_ALREADY_RUNNING=13`, `EXIT_PERMISSION_DENIED=14`
- **日志函数**: `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_step()`
- **代理函数**: `curl_with_proxy()` - 支持 HTTP 代理、动态 no_proxy
- **配置文件路径**: `~/.config/ruijie/ruijie.conf` (权限 600)

#### lib/config.sh
- `load_config()` - 加载配置文件到环境变量
- `save_config()` - 安全保存配置（chmod 600）
- `is_configured()` - 检查是否已配置
- `interactive_config()` - 交互式配置向导
- `get_account_type()` - 获取账号类型

#### lib/network.sh
- `check_network()` - HTTP 204 检测在线状态（204=在线，000=超时，其他=异常）
- `do_login()` - 执行完整登录流程
- `do_logout()` - 执行下线操作
- `build_login_url()` - 从 portal URL 构建登录 URL
- `get_service_type()` - 获取服务类型（DianXin/LianTong/default）

#### lib/daemon.sh
- `daemon_start()` - 后台启动守护进程（支持 nohup/busybox nohup/setsid 回退）
- `daemon_stop()` - 停止守护进程
- `daemon_is_running()` - 检查守护进程是否运行
- `daemon_loop()` - 状态机主循环（ONLINE→CHECKING→RETRYING→WAIT_LONG）
- `show_status()` - 显示完整状态（网络、账号、守护进程）
- 状态文件: `/var/run/ruijie-daemon.state`, `/var/run/ruijie-daemon.backoff`
- PID 文件: `/var/run/ruijie-daemon.pid`
- 日志文件: `/var/log/ruijie-daemon.log`

### 认证流程
1. 访问 `http://www.google.cn/generate_204`
2. 服务器返回携带认证参数的 portal URL
3. 提取 `wlanuserip`, `nasip`, `mac` 等设备参数
4. 组装 POST 请求到 `InterFace.do?method=login`
5. 解析 JSON 响应判断认证结果
6. 再次检测 HTTP 204 确认网络已连通

---

## 安装与部署

### 方式一：电脑直连
```bash
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh
chmod +x ruijie.sh
./ruijie.sh --setup   # 交互式配置
./ruijie.sh --daemon  # 启动守护进程
```

### 方式二：路由器部署（OpenWrt / iStoreOS）
```bash
wget -O /tmp/setup.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
chmod +x /tmp/setup.sh && sh /tmp/setup.sh
cd /etc/ruijie && ./ruijie.sh --daemon
```

### 卸载
```bash
sh uninstall.sh           # 普通卸载（保留配置）
sh uninstall.sh --purge  # 彻底清除（配置+账号+日志）
sh uninstall.sh --force  # 无需确认直接卸载
```

---

## 命令行参数

| 参数 | 说明 |
|------|------|
| `--student` | 使用学生账号（默认） |
| `--teacher` | 使用教师账号 |
| `-u 用户名 -p 密码` | 直接指定账号密码 |
| `--operator DianXin\|LianTong` | 指定运营商 |
| `--daemon` | 启动后台守护进程 |
| `--stop` | 停止守护进程 |
| `--status` / `--info` | 查看网络和认证状态 |
| `--logout` | 下线（断开网络连接） |
| `--setup` | 交互式重新配置账号 |
| `-v` / `--verbose` | 开启调试模式 |
| `-V` / `--version` | 显示版本号 |

---

## CI/CD

### GitHub Actions 工作流
- **触发条件**:
  - push 到 `main` 或 `develop` 分支
  - PR 合并到 `main` 分支
- **检查项目**:
  1. ShellCheck lint（所有 `*.sh` 文件，错误级别）
  2. 单元测试 (`bash tests/run_tests.sh unit`)
  3. 集成测试 (`bash tests/run_tests.sh integration`)

### CI 环境要求
- **Runner**: Ubuntu Latest
- **依赖**: ShellCheck, Bash

### 测试文件
- `tests/run_tests.sh` - 测试入口
- `tests/test_unit_network.sh` - 网络模块单元测试
- `tests/test_unit_config.sh` - 配置模块单元测试
- `tests/test_unit_daemon.sh` - 守护进程单元测试
- `tests/mock_server.sh` - 模拟认证服务器
- `tests/test_data/` - 测试数据文件

---

## 版本历史

### v3.1 (2026-04-07)
- 新增 `--logout` 下线功能
- 新增 `--status` / `--info` 增强状态显示
- 守护进程升级为状态机驱动
- 新增多实例互斥锁机制
- 新增单元测试
- **兼容性增强**: 守护进程自动回退 nohup → busybox nohup → setsid
- **opkg 源自动修复**: 安装时自动检测固件版本，修复失效的 snapshot 源

### v3.0 (2026-03)
- 统一入口脚本 `ruijie.sh`
- 密码安全存储（配置文件权限 600）
- 后台守护进程模式
- systemd 服务支持

### v2.1 (2026-03)
- 支持 OpenWrt 路由器

### 更早版本
- v2.0, v1.x 等早期版本

---

## 相关项目

| 项目 | GitHub URL | 说明 |
|------|------------|------|
| **ruijie-web-panel** | https://github.com/huantuoshen-prog/ruijie-web-panel | Web 管理面板（可选） |
| Qclaw | https://github.com/qiuzhi2046/Qclaw | OpenClaw 桌面管家（非本仓库） |

---

## 常见问题排查

### 认证失败（账号密码错误）
1. 确认学号和密码输入正确
2. 确认账号没有欠费
3. 确认当前连接的是电信网络
4. 重新配置：`./ruijie.sh --setup`

### 守护进程启动失败
```bash
# 检查 nohup 是否可用
command -v nohup
opkg update && opkg install coreutils-nohup
```

### opkg 源全部失败
```bash
sed -i 's/19\.07-SNAPSHOT/19.07.10/g' /etc/opkg/distfeeds.conf && opkg update && opkg install coreutils-nohup
```

### 查看日志
```bash
tail -f /var/log/ruijie-daemon.log
```

---

## 配置文件格式

路径: `~/.config/ruijie/ruijie.conf`（权限 600）

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

---

## 开发指南

### 添加新的运营商支持
1. 在 `lib/network.sh` 的 `get_service_type()` 函数中添加新的运营商分支
2. 在 `setup.sh` 中添加对应的选择选项
3. 在 README 中更新运营商信息表格

### 添加新的 CLI 参数
1. 在 `ruijie.sh` 的 `parse_args()` 函数中添加参数解析
2. 在 `lib/common.sh` 的 `show_help()` 函数中添加帮助文档

### 编写测试
1. 在 `tests/` 目录创建新的测试脚本
2. 使用 `tests/run_tests.sh` 作为入口框架
3. 参考现有的 `test_unit_*.sh` 文件格式

---

## 联系方式

- **GitHub Issues**: https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/issues
- **原始作者**: error7904（已离校）
- **当前维护者**: huantuoshen-prog
