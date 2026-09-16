# 仓库维护说明

## 产品边界

- 仅支持 OpenWrt、iStoreOS、ImmortalWrt 等使用 procd 的 OpenWrt 系固件。
- `ruijiectl` 是配置、服务、认证、状态、健康和日志的唯一业务入口。
- `ruijie.sh` 与学生、教师包装脚本只承担旧命令兼容。
- Web CGI 只能调用 `ruijiectl`，不能直接 source 核心业务库。
- 安装、升级和只读状态查询不得触发真实认证或下线。

## 主要结构

```text
ruijiectl                 统一 schema 2 JSON 入口
ruijie.sh                 旧 CLI 兼容入口
ruijie_student.sh         学生模式包装脚本
ruijie_teacher.sh         教师模式包装脚本
lib/config.sh             校验、revision、锁和原子配置写入
lib/network.sh            有界超时的连通性与认证流程
lib/daemon.sh             procd 前台自动重连循环与日志轮转
lib/health.sh             健康监控、脱敏日志和原子快照
init.d/ruijie             OpenWrt procd 服务
install.sh                校验、暂存、切换和失败恢复
rollback.sh               恢复上一完整版本与服务状态
release.sh                构建固定核心包和 manifest
tests/                    Bash 与 OpenWrt 发布包测试
```

`setup.sh` 只保留安全迁移提示，不再安装文件、依赖或启动项。

## 修改规则

1. stdout 的机器接口只能输出一个 JSON 文档，诊断写 stderr。
2. 密码不得出现在新接口命令行或日志中；配置修改从标准输入读取 JSON。
3. 配置写入必须持有独立锁，检查 revision，写同目录临时文件后原子替换。
4. 认证与服务变更使用非阻塞操作锁；冲突返回 `BUSY`。
5. 网络阶段必须有超时，整次认证预算不得超过 60 秒。
6. 连通性必须保留 `online`、`offline`、`unknown`，探测超时不能伪装成离线。
7. `service stop`、`service disable`、`auth logout` 的含义必须保持独立。
8. 普通日志、健康日志限制大小；运行状态快照使用原子替换。

## 本地验证

```sh
bash -n ruijiectl ruijie.sh install.sh rollback.sh release.sh lib/*.sh tests/*.sh
bash tests/run_tests.sh
bash tests/test_release_config.sh
bash tests/test_status_connectivity.sh
```

本地 Bash 不能代替 OpenWrt 验证。Pull Request CI 必须让完整发布包在官方 OpenWrt 19.07.10 与 24.10.8 rootfs 中完成新装、停止状态升级、健康失败恢复、校验失败和手动回滚。

## 发布

```sh
BUILD_TIME=2026-09-16T00:00:00Z sh release.sh
sha256sum dist/ruijie-core-4.0.0.tar.gz > SHA256SUMS
```

发布前检查：

- 工作树干净，CI 全绿。
- `build-info.conf` 的版本、提交 SHA、构建时间和 API schema 正确。
- 包内 `manifest.sha256` 全部通过。
- GitHub Release 附带核心包与外层 `SHA256SUMS`。
- 面板的 `compatibility.conf` 固定到这个准确核心提交。
- 发布说明列出已经验证和没有在真实校园网执行的项目。

不从变化中的 `main` 分支逐文件安装，不自动修改固件软件源，也不笼统承诺所有 OpenWrt 版本。
