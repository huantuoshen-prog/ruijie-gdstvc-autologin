# Ruijie Agent Install Prompt

这份文档提供一套可直接复制给通用 Agent 使用的安装 Prompt，用来协助安装 `ruijie-gdstvc-autologin`。

## 适用场景

- 第一次接触这个项目，不想自己整理安装步骤
- 想让 Agent 先判断当前是不是路由器终端，而不是误读本地电脑文件
- 想让 Agent 按仓库文档里的最短路径完成安装并做状态验证

默认应优先按“部署在路由器上”处理。只有我明确说明是单机直连，并且当前会话就是那台电脑本机终端时，才走本地安装路径。

## 使用前准备

开始前，最好已经具备这些条件：

- 能打开当前终端，或已经进入路由器 SSH / Web 终端
- 知道自己要走的是单机直连，还是路由器共享上网
- 已准备校园网账号和密码
- 如果是学生账号，最好知道运营商是 `DianXin` 还是 `LianTong`

如果这些信息不完整，Agent 也应该先自行判断环境，只在必要时提最少的问题。
如果 Agent 当前不在路由器终端，就不要直接读取本地电脑的 `/etc/openwrt_release`、`/etc/ruijie`、`/var/log/ruijie-daemon.log` 来推断路由器状态。

## 精简安装 Prompt

适合大多数场景：

```text
你正在帮助我安装广东科学技术职业学院锐捷认证脚本。

仓库：
https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin

安装文档：
https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/blob/main/docs/install.md

请先不要让我重复提供文档里已经写明的信息。先判断当前环境属于哪一种：

1. OpenWrt / iStoreOS / ImmortalWrt 路由器终端
2. Windows / Linux / macOS 单机终端（只有我明确说是单机直连时才使用）

执行要求：
- 默认把这次任务当作“部署在路由器上”处理
- 如果你当前不是路由器终端，不要拿本地 `/etc/*` 结果推断路由器状态；先让我切到路由器 SSH / TTYD 终端，或明确让我提供一个可用的 SSH 目标
- 优先使用仓库文档中的最短安装路径
- 如果缺少前置条件，只问最少的必要问题
- 如果脚本已经安装，先检查现状，不要盲目重复覆盖
- 安装完成后必须执行状态验证，而不是只停在“脚本已下载”

安装完成后请按下面格式告诉我：
- 当前环境判断
- 实际执行的命令
- 当前安装路径
- 状态验证结果
- 我下一步需要做什么
```

## 完整安装 Prompt

适合希望 Agent 更主动、更少猜测时使用：

```text
你是一个负责终端安装任务的工程 Agent。目标是帮我安装广东科学技术职业学院锐捷认证脚本，而不是只给出泛泛步骤。

先读取并遵循以下仓库信息：

- 仓库主页：https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin
- 安装文档：https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/blob/main/docs/install.md
- 命令与配置文档：https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/blob/main/docs/cli-and-config.md

工作要求：

1. 先判断这次任务是不是路由器部署；默认答案是“是”。
   - 如果当前会话就是路由器终端，并且能直接访问 `/etc/openwrt_release`、`/etc/ruijie` 等路径，则按路由器路径执行
   - 如果当前会话是本地电脑终端，不要读取本地 `/etc/*` 来推断路由器状态；先让我切到路由器 SSH / TTYD 终端，或要求我提供可用 SSH 目标（例如 `root@192.168.5.1`）
   - 只有我明确说明“就是这台电脑单机直连安装”，并且当前会话确实就是那台电脑本机终端时，才走 Windows / Linux / macOS 路径

2. 如果目标是路由器部署，但你当前不在路由器终端：
   - 停止直接检查本地文件
   - 优先引导我进入路由器 SSH / TTYD 终端
   - 如果你具备远程执行能力，再通过 SSH 在路由器上执行命令；否则不要假装已经读到了路由器文件

3. 如果当前已经是路由器终端安装：
   - 优先使用自动安装脚本：
     - `wget -O /tmp/setup.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/setup.sh`
     - `chmod +x /tmp/setup.sh && sh /tmp/setup.sh`
   - 安装完成后执行：
     - `/etc/ruijie/ruijie.sh --status`
     - `ps | grep '[r]uijie'`
     - `tail -n 20 /var/log/ruijie-daemon.log`

4. 只有在明确单机直连安装时：
   - 优先使用仓库 README / install.md 中的最短安装路径
   - Windows 默认按 Git Bash 环境处理
   - 使用以下路径之一下载脚本：
     - `curl -LO https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh`
     - 或 `wget -O ruijie.sh https://raw.githubusercontent.com/huantuoshen-prog/ruijie-gdstvc-autologin/main/ruijie.sh`
   - 然后执行：
     - `chmod +x ruijie.sh`
     - `./ruijie.sh --setup`
     - `./ruijie.sh --daemon`
     - `./ruijie.sh --status`

5. 提问规则：
   - 不要要求我重复提供文档里已有的信息
   - 只在账号、密码、运营商等真正无法从环境判断时提问
   - 如果你发现我当前不在路由器终端，不要假设已经进入路由器；先明确指出，并引导我进入正确终端或提供 SSH 目标

6. 输出要求：
   - 先给出环境判断
   - 再给出实际执行的命令
   - 再给出安装结果和验证结果
   - 如果安装已经完成但状态异常，请明确告诉我应该转去使用调试 Prompt，而不是继续猜
```

## 安装后验证 Prompt

如果 Agent 已经把安装做完，你想让它只做收尾验证，可以单独复制这一段：

```text
你已经完成锐捷脚本安装。现在不要继续泛泛解释，只做安装后验证。

如果目标是路由器部署，但你当前不在路由器终端：
- 不要直接读取本地电脑上的 `/etc/ruijie`、`/etc/openwrt_release`、`/var/log/ruijie-daemon.log`
- 先要求我切到路由器 SSH / TTYD 终端，或让我提供可用的 SSH 目标

如果当前是单机直连：
- 运行 `./ruijie.sh --status`
- 如果 daemon 已启动，再运行 `./ruijie.sh --status --json`

如果当前是路由器终端：
- 运行 `/etc/ruijie/ruijie.sh --status`
- 运行 `ps | grep '[r]uijie'`
- 运行 `tail -n 20 /var/log/ruijie-daemon.log`

请只输出：
1. 是否安装完成
2. 当前安装路径
3. daemon 是否在运行
4. 是否还需要我补账号/密码/运营商配置
5. 如果不是安装问题，而是运行问题，请明确建议我改用调试 Prompt
```

## Agent 应优先确认的环境信息

- 当前会话是不是直接运行在路由器上
- 如果不在路由器上，是否有可用 SSH 目标
- 这次任务是不是默认应按路由器部署处理
- 是否存在 `/etc/openwrt_release`
- 当前系统是 Windows / Linux / macOS 还是 OpenWrt
- 当前是否有 `wget` 或 `curl`
- Windows 下是否在 Git Bash 里执行
- 是否已经存在 `ruijie.sh` 或 `/etc/ruijie/ruijie.sh`

## 安装完成后下一步

如果已经安装成功，但运行状态不稳、daemon 不重连、健康监听或 JSON 状态有问题，请改用：
[AGENT_DEBUG_PROMPT.md](./AGENT_DEBUG_PROMPT.md)
