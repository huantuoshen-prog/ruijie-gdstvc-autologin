# Changelog - Ruijie-Auto-Login

## Unreleased

### Added
- 新增运行环境感知的健康监听与健康日志
- 新增 `--json`、`--health-status`、`--health-enable`、`--health-disable`、`--health-log`、`--runtime-status`
- 新增面向通用 Agent 的 [调试 Prompt 文档](./docs/AGENT_DEBUG_PROMPT.md)
- 新增状态展示辅助函数回归测试

### Changed
- README 调整为首页导航，详细文档拆分到 `docs/`
- 新增 `docs/install.md`、`docs/cli-and-config.md`、`docs/daemon-and-health.md`、`docs/troubleshooting.md`、`docs/development.md`
- `status` 输出在 BusyBox / OpenWrt 下支持 `/proc` 运行时间回退

### Fixed
- 修复 `last_auth` 时间字符串丢失日期与时间之间空格的问题
- 修复 BusyBox `ps` 不支持 `etime` 时 `daemon_uptime` 为空的问题

## v3.1 (2026-04-07)

### Added
- 新增 `--logout` 下线功能（`do_logout()` 函数）
- 新增 `--status` / `--info` 增强状态显示：在线状态、账号信息、守护进程 PID、最后认证时间、状态机当前状态
- 新增守护进程状态文件 `/var/run/ruijie-daemon.state`
- 新增 `install_cron_task()` 安全的 crontab 安装函数
- 新增扩展单元测试：`test_unit_network.sh`、`test_unit_config.sh`、`test_unit_daemon.sh`
- 新增 `RUIJIE_VERSION`、`RUIJIE_BUILD_DATE` 全局常量
- 新增退出码常量（`EXIT_AUTH_FAILED=11` 等）
- 新增 `get_last_auth_time()` / `format_relative_time()` 辅助函数

### Changed
- 守护进程从固定 300s 间隔升级为**状态机驱动**的动态间隔（在线 600s，离线退避 30→60→120→300s）
- `check_network()` 区分 http_code=000（超时）、204（在线）、其他（异常），不再静默吞掉错误
- `do_login()` 使用 `trap RETURN` 确保 `EXTRA_NO_PROXY` 在任何退出路径都被清理
- `parse_args()` 重构位置参数解析逻辑，修复 `--teacher` 等选项被错误处理的 BUG
- 移除全局 `set -e`，避免 `check_network()`（返回1=离线）等函数误退脚本
- `setup.sh` crontab 安装改用 mktemp 原子写入，不再误删其他 cron 条目
- `setup.sh` rc.local 配置前先检查标记，防止重复追加
- 单元测试修复 `CHECK_URLS` 未定义导致的测试失败
- stat 命令加 Windows Git Bash 兼容性处理

### Fixed
- setup.sh crontab 任务追加到 `/dev/null` 而非 crontab 的严重 bug
- setup.sh `grep -v "ruijie"` 误删所有含 ruijie 的 cron 条目
- `check_network()` 对网络不可达（000）情况无任何提示
- `parse_args()` 中 shift 后 `case "$1"` 判断已被消耗的值
- `do_login()` 中途 return 时 `EXTRA_NO_PROXY` 残留
- `set -e` 与 `check_network()` / `daemon_status()` 等函数返回值冲突

### Deprecated
- `daemon_status()` 降级为内部函数，对外使用 `show_status()`
- 旧配置文件中 `DAEMON_INTERVAL` 语义升级为"在线检测间隔"

---

## v3.0 (2026-03)
- 统一入口脚本 `ruijie.sh`（通过 `--student` / `--teacher` 区分）
- `ruijie_student.sh` / `ruijie_teacher.sh` 改为符号链接（向后兼容）
- 安全改进：密码存储在配置文件 (chmod 600)，不再写入 crontab
- 后台守护进程模式 (`-d/--daemon`)
- systemd 服务支持
- GitHub Actions CI (shellcheck + 测试)
- 模块化代码结构 (`lib/` 目录)

---

## v2.1 (2026-03)
- `setup.sh` 支持 OpenWrt 路由器（自动检测，安装到 `/etc/ruijie/`）
- OpenWrt 下自动配置 `/etc/rc.local` 开机同步脚本
- 修复 `setup.sh` 只复制 `ruijie.sh` 而忽略 `lib/` 目录的问题
- 定时任务在 OpenWrt 下输出日志到 `/var/log/ruijie-login.log`
- 跳过 systemd 服务安装（OpenWrt 不使用 systemd）

---
## v2.1 (2025-03)
- 新增一键配置脚本 (setup.sh)
- 交互式中文安装界面
- 自动配置定时任务
- README 优化排版

---

## v2.0 (2025-03)
- 实时日志输出
- 多环境适配
- 彩色终端输出
- 错误处理优化

---

## v1.x
- 原始版本
