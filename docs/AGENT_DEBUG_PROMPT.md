# Ruijie Agent Debug Prompt

这份文档提供一套可直接复制给通用 agent 使用的排障 prompt，用来读取锐捷脚本的健康监听、运行环境和状态信息。

## 适用场景

- 守护进程没有自动重连
- 健康监听日志里出现 `auth_failed`、`network_error`
- 面板显示在线/离线状态和 CLI 认知不一致
- 需要让 agent 在不猜测环境的前提下做排障

## 使用前准备

建议先开启健康监听，再把下面的 prompt 发给 agent：

```bash
./ruijie.sh --health-enable 3d
```

如果你只想临时收集调试信息，也可以改成 `1d`；如果问题比较顽固，可以改成 `7d` 或 `permanent`。

## 精简 Prompt

适合大多数场景：

```text
你正在排查广东科学技术职业学院锐捷认证脚本的问题。不要先猜原因，先读取以下 JSON 信息，再基于结果给出判断：

1. ./ruijie.sh --status --json
2. ./ruijie.sh --health-status --json
3. ./ruijie.sh --runtime-status --json
4. ./ruijie.sh --health-log --lines 100 --json

请按下面格式输出：
- 当前状态摘要
- 最可能的 1 到 3 个原因
- 你判断这些原因的证据
- 下一步建议执行的命令

注意：
- 不要要求我重复提供已经能从 JSON 里读出的信息
- 不要忽略 runtime 信息里的平台、路径、后台工具和 daemon 状态
- 如果健康监听未开启，请先明确指出，再建议是否开启 1d/3d/7d
```

## 完整 Prompt

适合复杂问题、持续性断线或需要更严谨排障的时候：

```text
你是一个负责排查 shell 网络守护脚本问题的工程 agent。目标是定位广东科学技术职业学院锐捷认证脚本的真实故障点，而不是泛泛给建议。

先读取并分析以下命令输出：

1. ./ruijie.sh --status --json
2. ./ruijie.sh --health-status --json
3. ./ruijie.sh --runtime-status --json
4. ./ruijie.sh --health-log --lines 200 --json

分析要求：
- 先判断当前是否在线、daemon 是否在运行、健康监听是否开启、collector 是否活跃
- 再结合 runtime 判断运行环境：openwrt 还是普通 linux、shell、nohup backend、关键路径、面板是否已安装
- 再从 health log 里找出最近的 state_transition、auth_failed、network_error、daemon、monitor 事件
- 如果 status、health snapshot、health log 之间有冲突，要明确指出冲突点
- 如果问题更像环境问题、配置问题、网络问题或脚本 bug，请明确分类

输出格式固定为：
1. 当前状态
2. 异常信号
3. 根因判断
4. 证据
5. 下一步操作
6. 如果需要继续排查，还应该补采哪些信息

限制：
- 不要只说“检查账号密码是否正确”这种低信息量建议，除非日志确实支持
- 不要把健康监听日志中的空字段自动解释成脚本 bug，先结合 runtime 和 daemon 状态判断
- 如果健康监听没开，先说明这会降低可观测性
```

## 面板场景 Prompt

如果你是从 Web 面板里观察到问题，可以补充这一段：

```text
补充背景：
- Web 面板可读取 /ruijie-cgi/status、/health、/health-log、/runtime
- 如果面板状态和 CLI 状态不一致，请优先相信最新时间戳的 JSON 输出，并指出哪个接口落后
```

## 期望 Agent 重点关注什么

- `status.health.collector_active` 或 `health.collector_active`
- `runtime.nohup_backend`
- `runtime.script_dir`、`runtime.config_file`、`runtime.daemon_logfile`
- 健康日志里的 `auth_failed`、`network_error`、`state_transition`、`daemon`
- `snapshot` 和 `status` 中 `online` / `daemon_running` / `daemon_state` 是否一致

## 不建议的提问方式

下面这些 prompt 太弱，agent 往往会给出空泛建议：

- `帮我看看为什么上不了网`
- `这个脚本是不是坏了`
- `帮我分析下日志`

更好的方式是把上面的“精简 Prompt”或“完整 Prompt”直接发给 agent。
