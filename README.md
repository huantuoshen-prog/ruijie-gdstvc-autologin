# Ruijie-Auto-Login

广东科学技术职业学院 锐捷Web认证脚本

> ⚠️ **重要提示**: 原作者（error7904）已离校长时间未更新，本仓库为新维护版本，继续为广科院同学提供支持。

## 简介

本脚本用于广东科学技术职业学院（珠海校区/广州校区）的锐捷 ePortal 网页认证自动化。

仅适用于广东科学技术职业学院使用，其他学校请自测。

## 功能特点

- ✅ **实时日志输出** - 每一步都有详细的状态提示
- ✅ **多环境适配** - 自动检测多种网络环境
- ✅ **美化输出** - 彩色日志，更清晰直观
- ✅ **自动重试** - 智能检测网络状态
- ✅ **错误提示** - 详细的中文错误信息

## 环境要求

- Linux / macOS / Windows (WSL)
- OpenWrt 路由器
- curl 工具

## 安装

### 方法1: 直接下载

```bash
wget https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/ruijie_student.sh
chmod +x ruijie_student.sh
```

### 方法2: 克隆仓库

```bash
git clone https://github.com/17388749803/Ruijie-Auto-Login.git
cd Ruijie-Auto-Login
```

## 使用方法

### 基础用法

```bash
./ruijie_student.sh <用户名> <密码>

# 示例
./ruijie_student.sh 2023000001 123456
```

### 学生账号

```bash
./ruijie_student.sh 你的学号 你的密码
```

### 教师账号

```bash
./ruijie_teacher.sh 你的工号 你的密码
```

## 输出示例

```
==========================================
  锐捷网络认证助手 v2.0
  广东科学技术职业学院专用
==========================================

[STEP] 检测网络连接状态...
[INFO] 尝试连接: http://www.google.cn/generate_204
[✓] 检测成功: http://www.google.cn/generate_204 (HTTP 204)
[✓] 网络已连接，无需认证！
```

或认证时：

```
[STEP] 检测网络连接状态...
[⚠] 未检测到网络连接，开始认证流程...
[STEP] 获取认证页面...
[✓] 获取成功: http://10.x.x.x/...
[STEP] 构建认证参数...
[✓] 参数构建完成
[STEP] 正在提交认证信息...
[STEP] 验证认证结果...
==========================================
  认证成功！🎉
  现在可以正常上网了
==========================================
```

## OpenWrt 路由器定时任务

配合 OpenWrt 路由器实现自动认证：

### 1. 安装 curl

```bash
opkg update
opkg install curl
```

### 2. 设置定时任务

```bash
# 编辑定时任务
crontab -e

# 添加以下行（每5分钟检查一次）
*/5 * * * * /path/to/ruijie_student.sh 你的学号 你的密码 >> /var/log/ruijie.log 2>&1
```

### 3. 查看日志

```bash
tail -f /var/log/ruijie.log
```

## 常见问题

### Q: 提示"需要输入验证码"怎么办？
A: 当前脚本不支持验证码识别，建议在网页端手动认证一次后，再使用脚本。

### Q: 认证失败怎么办？
A: 
1. 检查用户名和密码是否正确
2. 检查网络是否正常
3. 尝试更换检测地址

### Q: 路由器上运行有问题？
A: 确保路由器已安装 curl：`opkg install curl`

## 致谢

- 原始作者: [error7904](https://github.com/error7904)
- 参考项目: [RuijiePortalLoginShellScript](https://github.com/1203746884/RuijiePortalLoginShellScript)

## 许可证

GPL-3.0

## 更新日志

### v2.0 (2025-03)
- 新增实时日志输出
- 优化多环境适配
- 添加彩色终端输出
- 改进错误处理

### v1.x
- 原始版本
- 基本认证功能

---

🌐 GitHub: https://github.com/17388749803/Ruijie-Auto-Login
📧 问题反馈: 请提交 Issue
