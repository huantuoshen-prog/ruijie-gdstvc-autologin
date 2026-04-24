# 故障排除

## 安装问题

### 提示 `curl` 未安装

```bash
opkg update && opkg install curl
```

### 提示 `opkg` 源失效或 SNAPSHOT 不可用

先重跑安装脚本：

```bash
sh /tmp/setup.sh
```

如果还不行，再手动修复：

```bash
sed -i 's/19\.07-SNAPSHOT/19.07.10/g' /etc/opkg/distfeeds.conf
opkg update && opkg install coreutils-nohup
```

### 提示缺少后台运行工具

```bash
opkg update && opkg install coreutils-nohup
```

或者安装 BusyBox 版本的 `nohup`。

## 认证问题

### 账号密码错误

1. 确认学号 / 工号无误
2. 确认校园网密码无误
3. 学生账号确认运营商是否正确
4. 重新跑一次：

```bash
./ruijie.sh --setup
```

### 联通网络无法认证

确认你所在楼栋是否使用联通，并使用：

```bash
./ruijie.sh --operator LianTong -u 用户名 -p 密码
```

## daemon 问题

### 守护进程没有自动重连

```bash
ps | grep ruijie
./ruijie.sh --status
tail -f /var/log/ruijie-daemon.log
```

如果 daemon 未运行：

```bash
./ruijie.sh --daemon
```

### 守护进程启动后立即退出

优先检查：

```bash
cat ~/.config/ruijie/ruijie.conf
chmod 600 ~/.config/ruijie/ruijie.conf
./ruijie.sh -v --daemon
```

### 守护进程提示已在运行

先正常停止：

```bash
./ruijie.sh --stop
```

再重新启动：

```bash
./ruijie.sh --daemon
```

## 健康监听问题

### 健康日志为空

先看监听是否真的开启：

```bash
./ruijie.sh --health-status --json
```

如果刚开启，可能要等下一次基线采样或状态变化才会看到新日志。

### 想让 Agent 直接排障

直接使用：
[AGENT_DEBUG_PROMPT.md](./AGENT_DEBUG_PROMPT.md)

## 完全卸载

普通卸载：

```bash
sh uninstall.sh
```

彻底清除配置：

```bash
sh uninstall.sh --purge
```
