# 守护进程与健康监听

## 锐捷认证流程

脚本的基本工作顺序是：

1. 检查网络是否已经在线
2. 如果离线，获取 portal 登录页面 URL
3. 解析动态参数（`wlanuserip`、`nasip`、`mac` 等）
4. 按账号类型和运营商构造登录请求
5. 发送认证请求并解析结果
6. 再次检测网络，确认是否真正上线

这也是 `do_login()` 负责的主流程。

## 守护进程状态机

守护进程的状态机分为四个核心状态：

- `ONLINE`：在线检测中，默认按较长间隔巡检
- `CHECKING`：检测到离线后立即重试认证
- `RETRYING`：认证失败后按指数退避重试
- `WAIT_LONG`：达到退避上限后进入长等待

退避序列固定为：

```text
30s -> 60s -> 120s -> 300s -> 300s ...
```

## 后台运行方式

脚本会按以下顺序选择后台工具：

1. `nohup`
2. `busybox nohup`
3. `setsid`

如果这些工具都不可用，daemon 将不会启动。

## 状态文件

| 文件 | 说明 |
|------|------|
| `/var/run/ruijie-daemon.pid` | daemon PID |
| `/var/run/ruijie-daemon.state` | 当前状态机状态 |
| `/var/run/ruijie-daemon.backoff` | 当前退避计数 |
| `/var/run/ruijie-daemon.lock` | 多实例锁 |
| `/var/log/ruijie-daemon.log` | daemon 日志 |

## 健康监听

健康监听是这套脚本的调试与可观测性层，特点是：

- 首次安装主脚本后默认开启 3 天
- 后续升级不会自动重开
- 挂在现有 daemon loop 内，不新增第二个常驻进程
- 可以手动开启 `1d / 3d / 7d / permanent`
- 默认只隐藏密码、Cookie、Session、Token 等敏感值

### 常用命令

```bash
# 查看健康状态
./ruijie.sh --health-status

# 开启 3 天
./ruijie.sh --health-enable 3d

# 永久开启
./ruijie.sh --health-enable permanent

# 关闭
./ruijie.sh --health-disable

# 查看健康日志
./ruijie.sh --health-log --lines 100 --json

# 查看运行环境摘要
./ruijie.sh --runtime-status --json
```

### 健康相关文件

| 文件 | 说明 |
|------|------|
| `~/.config/ruijie/health-monitor.conf` | 健康监听配置 |
| `/var/log/ruijie-health.log` | 健康日志（JSONL） |
| `/var/run/ruijie-health.status.json` | 当前健康状态快照 |
| `/var/run/ruijie-runtime.status.json` | 当前运行环境快照 |

### 典型采集内容

- 认证成功 / 失败
- 状态机切换
- 在线检测异常
- daemon 启停
- 当前平台、shell、nohup backend、关键路径

## 日志与排障

```bash
# 实时看 daemon 日志
tail -f /var/log/ruijie-daemon.log

# 看最近健康日志
./ruijie.sh --health-log --lines 50 --json

# 看运行环境
./ruijie.sh --runtime-status --json
```

如果你要把这些信息交给通用 Agent：
[AGENT_DEBUG_PROMPT.md](./AGENT_DEBUG_PROMPT.md)
