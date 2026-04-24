# 广东科学技术职业学院校园网锐捷认证工具

> 面向广东科学技术职业学院校园网的锐捷 Web 认证自动登录工具，支持单电脑直连和 OpenWrt 路由器部署。

[![CI](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions/workflows/ci.yml/badge.svg)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/actions)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-green)](https://github.com/koalaman/shellcheck)
[![版本](https://img.shields.io/badge/version-v3.1-blue)](https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin)

支持这些核心能力：

- 自动完成锐捷 Web 认证
- 守护进程后台运行，断线自动重连
- 学生账号 / 教师账号
- 电信 / 联通双运营商
- 健康监听、运行环境摘要和 Agent 友好 JSON CLI
- 可选的 [Web 管理面板](https://github.com/huantuoshen-prog/ruijie-web-panel)

## 快速入口

- [电脑直连快速开始](#电脑直连)
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

如果你只想让一台电脑上网，可以直接在本机运行 `ruijie.sh`。
如果你想让整宿舍设备共用一条校园网认证，可以把它装到 OpenWrt / iStoreOS / ImmortalWrt 路由器上长期运行。

推荐使用方式：

| 场景 | 推荐方式 | 说明 |
|------|------|------|
| 单台电脑直连 | 本机运行脚本 | 最快上手，适合没有路由器时 |
| 宿舍多设备共享 | 路由器部署 | 一次配置后自动保活 |
| 想要图形界面 | 搭配 `ruijie-web-panel` | 浏览器里管理账号、daemon 和日志 |
| 想让 Agent 排障 | 开启健康监听 | 用 `--json` 接口和健康日志定位问题 |

## 快速开始

### 电脑直连

适合只有一台电脑要上网、没有路由器的场景。

```bash
# Windows（先装 Git Bash）
curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

# Linux / macOS
wget -O ruijie.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh

chmod +x ruijie.sh
./ruijie.sh --setup
./ruijie.sh --daemon
./ruijie.sh --status
```

### 路由器部署

适合 OpenWrt / iStoreOS / ImmortalWrt 路由器，多台设备共享上网。

```bash
wget -O /tmp/setup.sh \
  https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh
chmod +x /tmp/setup.sh && sh /tmp/setup.sh

/etc/ruijie/ruijie.sh --status
```

如果你第一次接触这套脚本，建议直接看：
[docs/install.md](./docs/install.md)

如果你想让 Agent 按仓库文档协助安装，直接复制：
[docs/AGENT_INSTALL_PROMPT.md](./docs/AGENT_INSTALL_PROMPT.md)

## 常用命令

| 场景 | 命令 |
|------|------|
| 交互式配置 | `./ruijie.sh --setup` |
| 启动守护进程 | `./ruijie.sh --daemon` |
| 停止守护进程 | `./ruijie.sh --stop` |
| 查看当前状态 | `./ruijie.sh --status` |
| 机器可读状态 | `./ruijie.sh --status --json` |
| 开启 3 天健康监听 | `./ruijie.sh --health-enable 3d` |
| 查看健康监听状态 | `./ruijie.sh --health-status --json` |
| 查看运行环境摘要 | `./ruijie.sh --runtime-status --json` |
| 查看健康日志 | `./ruijie.sh --health-log --lines 100 --json` |

如果你想让 Agent 帮你安装，直接复制：
[docs/AGENT_INSTALL_PROMPT.md](./docs/AGENT_INSTALL_PROMPT.md)

如果你想把问题直接交给通用 Agent 排障，直接复制：
[docs/AGENT_DEBUG_PROMPT.md](./docs/AGENT_DEBUG_PROMPT.md)

## 深入阅读

| 文档 | 说明 |
|------|------|
| [docs/install.md](./docs/install.md) | Windows / Linux / OpenWrt 的详细安装与开机自启 |
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

## 许可证

本项目使用 MIT 许可证。
完整文本见 [LICENSE](./LICENSE)。
