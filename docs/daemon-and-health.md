# procd 自动重连与健康监控

## 认证流程

核心先进行连通性检测。需要认证时，它读取一份完整配置快照，获取门户参数，分别编码账号字段并调用锐捷登录接口。认证响应成功后还会再次验证连通性；任一步超时或失败都会返回明确错误。

`auth ensure` 在已在线时直接返回；`auth reauth` 不会因为当前在线而跳过；`auth logout` 才会主动下线。

## procd 服务

OpenWrt 的 `procd` 管理前台认证循环和异常重启。项目不再安装 systemd、`rc.local` 或 cron 看门狗，也不创建第二套后台启动链。

```sh
/etc/ruijie/ruijiectl service start
/etc/ruijie/ruijiectl service stop
/etc/ruijie/ruijiectl service enable
/etc/ruijie/ruijiectl service disable
```

停止后的期望状态会单独记录，因此不会被旧看门狗重新拉起。每轮操作前重新读取完整配置，不依赖健康日志刷新配置。

## 统一状态

```sh
/etc/ruijie/ruijiectl status
```

状态分别表达：

- `desired_running`：用户期望自动重连是否运行
- `process_running`：procd 管理的进程是否存在
- `online`：连通性结果
- `last_auth`：最近一次认证结果时间
- `observed_at`、`state_age_seconds`、`stale`：采集时间与是否过期

无法确认的状态应保持未知，不应强行解释成离线。查询状态不会重新认证或改写业务状态。

## 健康监控

```sh
/etc/ruijie/ruijiectl health status
/etc/ruijie/ruijiectl health enable 3d
/etc/ruijie/ruijiectl health enable permanent
/etc/ruijie/ruijiectl health disable
/etc/ruijie/ruijiectl logs health 100
```

健康监控可以独立开关；采集失败不会阻塞自动重连。普通日志和健康日志都限制大小并轮转，输出会隐藏密码、Cookie、Session、Token 等敏感内容。

主要文件：

| 文件 | 用途 |
|------|------|
| `/var/run/ruijie-daemon.pid` | 当前进程 PID |
| `/var/run/ruijie-daemon.state` | 自动重连状态 |
| `/var/run/ruijie.desired` | 用户期望运行状态 |
| `/var/log/ruijie-daemon.log` | 认证与自动重连日志 |
| `/var/log/ruijie-health.log` | 健康事件日志 |
| `/var/run/ruijie-health.status.json` | 健康快照 |
| `/var/run/ruijie-runtime.status.json` | 运行环境快照 |
