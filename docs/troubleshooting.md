# 故障排除

## 安装被依赖检查阻止

先查看缺少的命令：

```sh
command -v bash curl jq flock sha256sum tar
test -x /sbin/procd
```

安装器不会修改 `opkg` 软件源。请先根据当前固件的官方软件源修复依赖，再重新运行固定发布包中的 `install.sh`。不要照抄其他固件版本的软件源地址。

## 检测到旧启动项或未知进程

这是迁移保护。安装器尚未修改文件，也不会杀死未知进程或触发认证。请在计划维护时段确认旧版的 PID、`/etc/rc.local` 和 `/etc/crontabs/root` 项目，再完成迁移。

## 只读查看状态

```sh
/etc/ruijie/ruijiectl runtime
/etc/ruijie/ruijiectl config get
/etc/ruijie/ruijiectl status
/etc/ruijie/ruijiectl logs daemon 100
```

`status` 中的 `desired_running` 表示用户是否希望自动重连运行，`process_running` 表示进程是否存在，`online` 表示最近一次连通性检查结果。状态还包含采集时间和过期标记。

## 自动重连没有运行

先看状态和日志：

```sh
/etc/ruijie/ruijiectl status
/etc/ruijie/ruijiectl logs daemon 100
```

确认配置正确后，才显式启动：

```sh
/etc/ruijie/ruijiectl service start
```

`service stop` 只暂停自动重连。`auth logout` 会主动断开校园网认证，两者含义不同。

## 配置保存冲突

`config get` 会返回 `revision`。保存时必须提交同一个 revision；若返回 `CONFLICT`，重新读取配置并合并修改，不能覆盖另一个页面刚保存的内容。

密码应通过标准输入中的 JSON 传给 `config set`，不要放入命令行、日志或 Issue。Web 面板已经按这种方式调用核心。

## 认证失败或超时

认证操作有 60 秒总预算，并会释放操作锁。先检查账号类型、运营商和校园网入口是否符合当前校区，再查看 daemon 与健康日志。需要 Agent 协助时使用 [AGENT_DEBUG_PROMPT.md](./AGENT_DEBUG_PROMPT.md)，提交前删除账号、密码、MAC、内网 IP、Cookie 和完整认证链接。

## 回滚

```sh
/etc/ruijie/rollback.sh
```

回滚恢复上一版代码与对应服务状态。账号配置位于 `/root/.config/ruijie`，升级前仍建议单独备份。

## 卸载

```sh
/etc/ruijie/uninstall.sh
```

是否清除账号配置请以卸载脚本的提示为准。卸载或主动下线前先确认其对当前网络的影响。
