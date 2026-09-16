# 开发说明

核心运行入口是 `ruijiectl`。它是认证、配置、服务、健康与日志的唯一业务边界；CGI 不应 source `lib/`。

```text
ruijiectl config get|set
ruijiectl service start|stop|restart|enable|disable
ruijiectl auth ensure|reauth|logout
ruijiectl status|runtime|health|logs
```

所有新接口使用 schema `2`，返回 `success`、`code`、`message`、`data`。配置读取返回 revision，写入必须携带它；写入通过同目录临时文件、`flock` 和原子替换完成。

运行本地 shell 测试：

```sh
bash tests/run_tests.sh
```

构建固定发布包：

```sh
sh release.sh
```

发布验证应在至少一个旧版和一个新版 OpenWrt 环境中运行完整包安装、依赖缺失、校验失败和回滚测试。开发机的 Bash 测试不能替代 BusyBox/uhttpd 集成测试。
