# 广东科学技术职业学院校园网锐捷认证：OpenWrt 自动登录脚本

> 面向广东科学技术职业学院（广科院、GDSTVC）新生与宿舍路由器用户的锐捷校园网自动认证工具。支持 OpenWrt、iStoreOS、ImmortalWrt，适用于校园网、锐捷认证、断线自动重连和电信/联通线路。

[![CI](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions/workflows/ci.yml/badge.svg)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-green)](https://github.com/koalaman/shellcheck)
[![版本](https://img.shields.io/badge/version-v4.0.0-blue)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases)

## 第一次使用？复制这一行

请在路由器的 SSH / TTYD 终端中执行。它会下载固定的 v4.0.0 完整包、校验文件、安装核心，并且不会主动认证或退出校园网：

```sh
T="$(mktemp -d /tmp/ruijie-core.XXXXXX)" && cd "$T" && curl -fsSLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/ruijie-core-4.0.0.tar.gz && curl -fsSLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/SHA256SUMS && grep ' ruijie-core-4.0.0.tar.gz$' SHA256SUMS | sha256sum -c - && tar -xzf ruijie-core-4.0.0.tar.gz && cd ruijie-core && sha256sum -c manifest.sha256 && sh install.sh
```

安装后只想使用网页管理，请下载 [Web 面板的一体组合包](https://github.com/huantuoshen-prog/ruijie-web-panel/releases/tag/v4.0.0)，里面已经包含匹配的核心和面板。完整步骤与回滚方法见 [安装文档](./docs/install.md)。

这套工具只支持 OpenWrt、iStoreOS、ImmortalWrt 等 OpenWrt 系路由器；不支持 Windows、macOS 或普通 Linux 桌面直接安装。

支持这些核心能力：

- 自动完成锐捷 Web 认证
- 守护进程后台运行，断线自动重连
- 学生账号 / 教师账号
- 电信 / 联通双运营商
- 健康监听、运行环境摘要和 Agent 友好 JSON CLI
- 可选的 [Web 管理面板](https://github.com/huantuoshen-prog/ruijie-web-panel)

## 这是做什么的？

如果你的宿舍路由器已连接广东科学技术职业学院校园网，本项目会让路由器完成锐捷 Web 认证，并在网络中断后按节奏尝试恢复认证。它适合希望让手机、电脑、平板等设备通过同一台 OpenWrt 路由器稳定上网的同学。

它不是学校官方软件，也不会替代学校网络规定；账号和密码仍由你本人保管。

## 适用范围

- 学校：广东科学技术职业学院 / 广科院 / GDSTVC
- 路由器系统：OpenWrt、iStoreOS、ImmortalWrt
- 认证类型：锐捷 Web 认证、ePortal / captive portal
- 线路：校园电信、校园联通
- 使用方式：命令行认证核心，或搭配 Web 管理面板

## 给 Agent 安装 / 排障

- 让 Agent 帮你安装（默认按路由器部署）： [docs/AGENT_INSTALL_PROMPT.md](./docs/AGENT_INSTALL_PROMPT.md)
- 已安装后让 Agent 排障： [docs/AGENT_DEBUG_PROMPT.md](./docs/AGENT_DEBUG_PROMPT.md)

## 你可能要看的内容

- [路由器部署快速开始](#路由器部署)
- [详细安装文档](./docs/install.md)
- [Agent 安装 Prompt](./docs/AGENT_INSTALL_PROMPT.md)
- [完整命令与配置说明](./docs/cli-and-config.md)
- [守护进程与健康监听](./docs/daemon-and-health.md)
- [故障排除](./docs/troubleshooting.md)
- [Agent 调试 Prompt](./docs/AGENT_DEBUG_PROMPT.md)
- [开发者文档](./docs/development.md)
- [更新记录](./CHANGELOG.md)

## 项目简介

本项目只支持 OpenWrt 系路由器。如果你想让整宿舍设备共用一条校园网认证，可以把它部署到 OpenWrt / iStoreOS / ImmortalWrt 路由器上长期运行。

推荐使用方式：

| 场景 | 推荐方式 | 说明 |
|------|------|------|
| 宿舍多设备共享 | 路由器部署 | 一次配置后自动保活 |
| 想要图形界面 | 搭配 `ruijie-web-panel` | 浏览器里管理账号、daemon 和日志 |
| 想让 Agent 排障 | 开启健康监听 | 用 `--json` 接口和健康日志定位问题 |

## 详细安装（给想了解过程的人）

### 路由器部署

适合 OpenWrt / iStoreOS / ImmortalWrt 路由器，多台设备共享上网。大多数人直接使用上面的“一行命令”即可。

```sh
cd /tmp
curl -fLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/ruijie-core-4.0.0.tar.gz
curl -fLO https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/download/v4.0.0/SHA256SUMS
grep ' ruijie-core-4.0.0.tar.gz$' SHA256SUMS | sha256sum -c -
mkdir -p /tmp/ruijie-core
tar -xzf ruijie-core-4.0.0.tar.gz -C /tmp/ruijie-core
cd /tmp/ruijie-core/ruijie-core
sha256sum -c manifest.sha256
sh install.sh

/etc/ruijie/ruijiectl runtime
```

安装不会触发校园网认证。配置账号、启动自动重连和主动下线都是分开的显式操作。

如果你第一次接触这套脚本，建议直接看：
[docs/install.md](./docs/install.md)

## 常用命令

| 场景 | 命令 |
|------|------|
| 查看运行环境 | `/etc/ruijie/ruijiectl runtime` |
| 查看统一状态 | `/etc/ruijie/ruijiectl status` |
| 启动自动重连 | `/etc/ruijie/ruijiectl service start` |
| 暂停自动重连 | `/etc/ruijie/ruijiectl service stop` |
| 确保当前在线 | `/etc/ruijie/ruijiectl auth ensure` |
| 强制重新认证 | `/etc/ruijie/ruijiectl auth reauth` |
| 主动断开认证 | `/etc/ruijie/ruijiectl auth logout` |
| 查看脱敏配置 | `/etc/ruijie/ruijiectl config get` |

## 深入阅读

| 文档 | 说明 |
|------|------|
| [docs/install.md](./docs/install.md) | OpenWrt 固定发布包安装、升级与回滚 |
| [docs/AGENT_INSTALL_PROMPT.md](./docs/AGENT_INSTALL_PROMPT.md) | 给通用 Agent 的现成安装 Prompt |
| [docs/cli-and-config.md](./docs/cli-and-config.md) | 完整参数表、配置文件、代理、退出码 |
| [docs/daemon-and-health.md](./docs/daemon-and-health.md) | 认证流程、状态机、健康监听、日志与状态文件 |
| [docs/troubleshooting.md](./docs/troubleshooting.md) | 常见安装问题、认证问题、daemon 问题与卸载 |
| [docs/development.md](./docs/development.md) | 项目结构、模块说明、测试与扩展方法 |
| [docs/AGENT_DEBUG_PROMPT.md](./docs/AGENT_DEBUG_PROMPT.md) | 给通用 Agent 的现成调试 Prompt |
| [CHANGELOG.md](./CHANGELOG.md) | 版本历史与最近改动 |

## 相关项目

| 项目 | GitHub | 说明 |
|------|--------|------|
| **ruijie-web-panel** | [链接](https://github.com/huantuoshen-prog/ruijie-web-panel) | Web 管理面板，可在浏览器管理账号和守护进程 |
| Qclaw | [链接](https://github.com/qiuzhi2046/Qclaw) | OpenClaw 桌面管家（非本项目） |

## 一起完善它

欢迎提交 issue：新生安装体验、不同宿舍楼的认证差异、OpenWrt 固件兼容性和文档错字都很有价值。提交时请不要附上账号、密码、MAC 地址、内网 IP 或完整认证链接。

## 许可证

本项目使用 MIT 许可证。
完整文本见 [LICENSE](./LICENSE)。
