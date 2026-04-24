# 命令与配置说明

## 完整命令行参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--student` | 使用学生账号模式（默认） | `./ruijie.sh --student` |
| `--teacher` | 使用教师账号模式 | `./ruijie.sh --teacher` |
| `-u, --username 用户名` | 指定用户名 | `./ruijie.sh -u 2023000001 -p 密码` |
| `-p, --password 密码` | 指定密码 | `./ruijie.sh -u 2023000001 -p 123456` |
| `--operator DianXin\|LianTong` | 指定运营商 | `./ruijie.sh --operator LianTong` |
| `--proxy URL` | 设置 HTTP 代理 | `./ruijie.sh --proxy http://127.0.0.1:7890` |
| `-d, --daemon` | 后台守护进程模式 | `./ruijie.sh --daemon` |
| `--stop` | 停止守护进程 | `./ruijie.sh --stop` |
| `--status`, `--info` | 查看状态 | `./ruijie.sh --status` |
| `--json` | 以 JSON 输出状态 / 健康 / 运行环境信息 | `./ruijie.sh --status --json` |
| `--logout` | 主动下线 | `./ruijie.sh --logout` |
| `--setup` | 交互式配置 | `./ruijie.sh --setup` |
| `--health-status` | 查看健康监听状态 | `./ruijie.sh --health-status --json` |
| `--health-enable 时长` | 启用健康监听 | `./ruijie.sh --health-enable 3d` |
| `--health-disable` | 关闭健康监听 | `./ruijie.sh --health-disable` |
| `--health-log` | 查看健康日志 | `./ruijie.sh --health-log --lines 100 --json` |
| `--runtime-status` | 查看运行环境摘要 | `./ruijie.sh --runtime-status --json` |
| `--lines N` | 配合 `--health-log` 指定条数 | `./ruijie.sh --health-log --lines 50 --json` |
| `--level LEVEL` | 配合 `--health-log` 按级别过滤 | `./ruijie.sh --health-log --level ERROR --json` |
| `--type TYPE` | 配合 `--health-log` 按事件类型过滤 | `./ruijie.sh --health-log --type auth_failed --json` |
| `-v, --verbose` | 显示详细调试信息 | `./ruijie.sh -v` |
| `-h, --help` | 显示帮助 | `./ruijie.sh --help` |
| `-V, --version` | 显示版本 | `./ruijie.sh --version` |

## 位置参数

仍然支持旧式写法：

```bash
./ruijie.sh 2023000001 123456
```

等价于：

```bash
./ruijie.sh -u 2023000001 -p 123456
```

## 符号链接模式

脚本支持通过文件名自动切换账号类型：

| 链接名 | 模式 |
|------|------|
| `ruijie.sh` | 学生账号（默认） |
| `ruijie_student.sh` | 学生账号 |
| `ruijie_teacher.sh` | 教师账号 |

Linux 下可以这样创建：

```bash
ln -s ruijie.sh ruijie_student.sh
ln -s ruijie.sh ruijie_teacher.sh
```

## 退出码

| 退出码 | 常量名 | 说明 |
|--------|--------|------|
| 10 | `EXIT_NETWORK_UNREACHABLE` | 网络不可达 |
| 11 | `EXIT_AUTH_FAILED` | 认证失败 |
| 12 | `EXIT_CONFIG_MISSING` | 配置缺失 |
| 13 | `EXIT_DAEMON_ALREADY_RUNNING` | 守护进程已在运行 |
| 14 | `EXIT_PERMISSION_DENIED` | 权限不足 |

## 常见用法

```bash
# 交互式配置
./ruijie.sh --setup

# 学生账号登录
./ruijie.sh -u 2023000001 -p 123456

# 教师账号 + 联通
./ruijie.sh --teacher -u T00001 -p 123456 --operator LianTong

# 启动守护进程
./ruijie.sh --daemon

# 查看状态（人类可读）
./ruijie.sh --status

# 查看状态（JSON）
./ruijie.sh --status --json
```

## 配置文件

### 路径与权限

| 项目 | 说明 |
|------|------|
| 配置目录 | `~/.config/ruijie/` |
| 配置文件 | `~/.config/ruijie/ruijie.conf` |
| 权限要求 | `600` |

### 配置项

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `USERNAME` | 用户名（学号/工号） | - |
| `PASSWORD` | 密码 | - |
| `ACCOUNT_TYPE` | `student` / `teacher` | `student` |
| `OPERATOR` | `DianXin` / `LianTong` | `DianXin` |
| `DAEMON_INTERVAL` | 在线检测间隔（秒） | `300` |
| `PROXY_URL` | HTTP 代理 | 空 |
| `PROXY_URL_HTTPS` | HTTPS 代理 | 空 |
| `NO_PROXY_LIST` | 不走代理地址列表 | 见默认值 |

默认 `NO_PROXY_LIST`：

```text
www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com
```

### 配置示例

```bash
USERNAME=1720240564
PASSWORD=your_password
ACCOUNT_TYPE=student
OPERATOR=DianXin
DAEMON_INTERVAL=300
PROXY_URL=
PROXY_URL_HTTPS=
NO_PROXY_LIST=www.google.cn,www.google.com,connectivitycheck.gstatic.com,connectivitycheck.android.com
```

## 代理说明

适用场景：

- 需要通过代理访问外网
- 某些环境里不直连外部探测地址

```bash
./ruijie.sh -u 1720240564 -p 密码 --proxy http://127.0.0.1:7890
```

如果你想继续看 daemon、状态机和健康监听：
[daemon-and-health.md](./daemon-and-health.md)
