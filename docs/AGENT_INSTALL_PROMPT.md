# Ruijie OpenWrt Agent 安装 Prompt

这份 Prompt 用于让通用 Agent 在 OpenWrt、iStoreOS 或 ImmortalWrt 路由器上安装认证核心。项目不再支持 Windows、macOS 或普通 Linux 桌面部署。

## 可直接复制的 Prompt

```text
你正在帮助我在 OpenWrt 系路由器上安装广东科学技术职业学院锐捷认证核心。

仓库：
https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin

安装文档：
https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/blob/main/docs/install.md

执行要求：
1. 先确认当前会话直接位于 OpenWrt、iStoreOS、ImmortalWrt 路由器，或已有明确的 SSH 目标。不要用本地电脑的 /etc 目录推断路由器状态。
2. 只使用 GitHub Release v4.0.0 中的完整 ruijie-core-4.0.0.tar.gz 和 SHA256SUMS。禁止从 main 分支逐个下载文件，禁止运行旧 setup.sh。
3. 在修改前检查 bash、curl、jq、flock、sha256sum、tar、procd 是否存在。不要自动改写 opkg 软件源；依赖缺失时给出明确诊断。
4. 校验外层 SHA256SUMS，解压后再校验 manifest.sha256，然后运行包内 install.sh。
5. 如果安装器报告未知旧守护进程、rc.local 或 cron 条目，停止并说明需要计划维护。不要强杀未知进程。
6. 安装本身不得调用 auth ensure、auth reauth 或 auth logout，不得触发真实校园网认证或下线。
7. 安装后只运行 /etc/ruijie/ruijiectl runtime 和 config get 做只读验证。除非我明确授权，不要启动服务或改账号。

请输出：
- 路由器环境与依赖检查结果
- 下载的固定版本和校验结果
- 安装或被安全阻止的结果
- 核心版本、提交 SHA、接口版本
- 尚未进行的真实认证验证
```

## 安装后只读验证 Prompt

```text
只检查已经安装的锐捷核心，不要重启服务，不要修改配置，不要重新认证，不要退出认证。

如果当前不在路由器终端，先要求明确的 SSH 目标。然后运行：
- /etc/ruijie/ruijiectl runtime
- /etc/ruijie/ruijiectl config get
- /etc/ruijie/ruijiectl status

请说明版本、接口 schema、配置是否存在、期望运行状态、进程状态、连通性和状态采集时间。未知值保持未知，不要当作离线。不得调用 auth ensure、auth reauth、auth logout、service start、service stop 或 service restart。
```

运行异常时改用 [AGENT_DEBUG_PROMPT.md](./AGENT_DEBUG_PROMPT.md)。Web 面板应使用与核心准确提交匹配的固定组合发布包。
