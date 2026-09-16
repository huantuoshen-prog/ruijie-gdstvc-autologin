# 命令与配置

`/etc/ruijie/ruijiectl` 是配置、服务、认证、状态和日志的统一入口。所有 JSON 响应使用 schema `2`，包含 `success`、`code`、`message` 和 `data`。

## 状态与运行环境

```sh
/etc/ruijie/ruijiectl runtime
/etc/ruijie/ruijiectl status
/etc/ruijie/ruijiectl health status
/etc/ruijie/ruijiectl logs daemon 100
/etc/ruijie/ruijiectl logs health 100
```

## 服务控制

```sh
/etc/ruijie/ruijiectl service start
/etc/ruijie/ruijiectl service stop
/etc/ruijie/ruijiectl service restart
/etc/ruijie/ruijiectl service enable
/etc/ruijie/ruijiectl service disable
```

- `start`、`stop`、`restart` 控制本次自动重连进程。
- `enable`、`disable` 控制开机是否自动启动。
- `stop` 不会主动退出已经建立的校园网认证。

## 认证控制

```sh
/etc/ruijie/ruijiectl auth ensure
/etc/ruijie/ruijiectl auth reauth
/etc/ruijie/ruijiectl auth logout
```

- `ensure` 已在线时不重复认证。
- `reauth` 强制重新走认证流程。
- `logout` 主动断开认证，执行前应明确确认。
- 同一时间只允许一个认证或服务变更；已有操作运行时返回 `BUSY`。

每个网络阶段都有超时，单次认证总预算不超过 60 秒。只有上游返回成功且后续连通性验证通过，才算认证成功。

## 配置

```sh
/etc/ruijie/ruijiectl config get
```

返回内容会隐藏密码，并包含 `revision`。修改配置时，将完整 JSON 通过标准输入传入：

```sh
cat config-update.json | /etc/ruijie/ruijiectl config set
```

示例文件：

```json
{
  "username": "2023000000",
  "password": "请在本地填写，不要提交到仓库",
  "account_type": "student",
  "operator": "DianXin",
  "proxy_url": "",
  "proxy_url_https": "",
  "revision": "从 config get 复制"
}
```

账号类型支持 `student`、`teacher`；运营商支持 `DianXin`、`LianTong`，教师账号也可使用 `default`。密码保留首尾空格，但拒绝换行、NUL 等无法安全写入配置文件的控制字符。

配置文件位于 `/root/.config/ruijie/ruijie.conf`，权限为 `600`。核心使用独立写锁、同目录临时文件和原子替换；revision 过期会返回 `CONFLICT`。

## 兼容入口

旧的 `ruijie.sh` 常用参数仍保留，供既有自动化迁移。新脚本和 Web 面板应使用 `ruijiectl`，并通过标准输入传递敏感配置，避免密码出现在进程列表和日志中。
