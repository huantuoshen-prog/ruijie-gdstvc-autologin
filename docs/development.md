# 开发者文档

## 项目结构

```text
ruijie-gdstvc-autologin/
├── ruijie.sh
├── ruijie_student.sh
├── ruijie_teacher.sh
├── setup.sh
├── uninstall.sh
├── lib/
│   ├── common.sh
│   ├── config.sh
│   ├── network.sh
│   ├── daemon.sh
│   └── health.sh
├── systemd/
│   └── ruijie.service
├── tests/
└── docs/
```

## 模块说明

| 模块 | 说明 |
|------|------|
| `lib/common.sh` | 颜色、日志、通用常量 |
| `lib/config.sh` | 配置读写 |
| `lib/network.sh` | portal 参数解析、认证请求、联网检测 |
| `lib/daemon.sh` | daemon 状态机、锁、状态展示 |
| `lib/health.sh` | 健康监听、运行环境、JSON CLI |

## 测试

```bash
# 所有测试
bash tests/run_tests.sh all

# 仅单元测试
bash tests/run_tests.sh unit

# 仅集成测试
bash tests/run_tests.sh integration
```

## 添加新运营商

1. 修改 `lib/network.sh` 中的服务类型映射
2. 修改 `setup.sh` 的交互式选择
3. 更新 `docs/cli-and-config.md` 中的参数说明
4. 补充测试

## 文档维护规则

- README 只保留首页导航与高频入口
- 详细命令、配置、原理、FAQ 和开发说明写入 `docs/`
- 面向 Agent 的排障模板统一保存在 `docs/AGENT_DEBUG_PROMPT.md`
