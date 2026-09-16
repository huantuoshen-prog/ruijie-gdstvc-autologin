# OpenWrt 安装与回滚

本版本仅支持 OpenWrt、iStoreOS、ImmortalWrt 及使用 `procd` 的衍生固件。不会修改 `opkg` 软件源，也不会在安装阶段发起校园网认证。

先确认能力：

```sh
command -v bash curl jq flock sha256sum tar
test -x /sbin/procd || echo '此固件不支持 procd'
```

## 最简单的一行安装

如果你只是想完成首次安装，请在路由器 SSH / TTYD 终端复制这一行。它固定下载 v4.0.0、自动校验完整包，安装阶段不会主动认证或退出校园网：

```sh
T="$(mktemp -d /tmp/ruijie-core.XXXXXX)" && cd "$T" && curl -fsSLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/ruijie-core-4.0.0.tar.gz && curl -fsSLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/SHA256SUMS && grep ' ruijie-core-4.0.0.tar.gz$' SHA256SUMS | sha256sum -c - && tar -xzf ruijie-core-4.0.0.tar.gz && cd ruijie-core && sha256sum -c manifest.sha256 && sh install.sh
```

命令需要在路由器上以管理员身份运行，并要求 `curl`、`sha256sum`、`tar` 已存在。依赖缺失时不要跳过校验，先按固件自己的软件源安装依赖。

从固定 GitHub Release 下载完整 `ruijie-core-<version>.tar.gz`，并解压；不要执行来自 `main` 的单文件下载。进入解压目录后运行：

```sh
sh install.sh
```

安装器不会调用认证下线接口。但若它发现旧守护进程仍在运行，或发现旧的 `rc.local` / cron 启动项，会直接拒绝安装，不修改文件、不停止服务也不触碰网络。先在计划维护时段完成旧服务迁移，再重新运行安装器；这避免新旧自动重连体系同时接管连接。

安装器会校验 `manifest.sha256`，暂存并切换 `/etc/ruijie`，保留上一个完整版本到 `/etc/ruijie.rollback`，并只在核心运行环境检查通过后完成安装。账号配置位于 `/root/.config/ruijie`，不会被代码升级覆盖。

安装完成后，显式配置账号或使用现有配置，然后再认证：

```sh
/etc/ruijie/ruijiectl config get
/etc/ruijie/ruijiectl auth ensure
/etc/ruijie/ruijiectl service start
/etc/ruijie/ruijiectl status
```

`service stop` 只停止自动重连；`auth logout` 会主动断开校园网认证。服务的开机自启使用 `service enable` / `service disable` 管理。

若升级后健康检查或人工验收失败，运行：

```sh
/etc/ruijie/rollback.sh
```

回滚会恢复上一个完整代码版本和对应服务。配置格式发生变更时，应先备份 `/root/.config/ruijie`，并只使用同一 Release 附带的回滚工具。

面板必须安装与核心版本兼容的固定 Release。面板包内的 `compatibility.conf` 当前要求核心 `4.0.0`、接口 schema `2`。
