# Ruijie-Auto-Login 🔐

> 广东科学技术职业学院(广科/科干) 锐捷Web认证脚本

![GitHub](https://img.shields.io/github/license/17388749803/Ruijie-Auto-Login)
![GitHub stars](https://img.shields.io/github/stars/17388749803/Ruijie-Auto-Login)

---

## ⚠️ 重要提示

原作者（error7904）已离校，本仓库为**新维护版本**，继续为广科院同学提供支持。

---

## 📋 简介

本脚本用于广东科学技术职业学院（珠海校区/广州校区）的锐捷 ePortal 网页认证自动化。

---

## 🏢 校园网运营商信息

| 宿舍楼 | 运营商 |
|--------|--------|
| 9栋 - 22栋 | 联通 📶 |
| 其他楼栋 | 电信 📶 |

> 📌 **注意**: 联通网络用户如遇问题，请提交 [Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues) 反馈

---

## 📱 关于多设备检测

校园网会检测多设备同时上网，但解决方法很简单：

### NAT 原理

校园网通过 **MAC 地址** 识别设备。NAT (网络地址转换) 让校园网只识别到**一个 MAC 地址**。

### 解决方案

使用 **OpenWrt** 或其衍生版本（ImmortalWrt、PandoraBox 等）的路由器，默认已启用 NAT。

**操作步骤：**
1. 路由器 WAN 口连接校园网网口
2. 电脑/手机连接路由器 WiFi 或网线
3. 路由器自动完成 NAT 转换

---

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 📊 实时日志 | 每一步都有详细状态提示 |
| 🌐 多环境适配 | 自动检测多种网络环境 |
| 🎨 彩色输出 | 终端界面清晰直观 |
| 🔄 自动重试 | 智能检测网络状态 |
| ❌ 错误提示 | 详细中文错误信息 |
| ⚡ 一键配置 | setup.sh 互动式安装 |

---

## 🚀 快速开始

### 一键配置（推荐 ✅）

```bash
# 下载配置脚本
wget -O setup.sh https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/setup.sh

# 运行配置（需要 root 权限）
chmod +x setup.sh
sudo sh setup.sh
```

配置过程：
1. ✅ 自动检测系统环境
2. ✅ 自动下载认证脚本
3. ✅ **互动式中文界面**，输入账号密码
4. ✅ 自动测试认证
5. ✅ 自动配置定时任务

---

## 📖 手动安装

### 方式1：直接下载

```bash
wget https://raw.githubusercontent.com/17388749803/Ruijie-Auto-Login/main/ruijie_student.sh
chmod +x ruijie_student.sh
```

### 方式2：克隆仓库

```bash
git clone https://github.com/17388749803/Ruijie-Auto-Login.git
cd Ruijie-Auto-Login
```

---

## 💻 使用方法

### 基础命令

```bash
./ruijie_student.sh <用户名> <密码>

# 示例
./ruijie_student.sh 2023000001 123456
```

### 学生/教师账号

```bash
# 学生
./ruijie_student.sh 你的学号 你的密码

# 教师
./ruijie_teacher.sh 你的工号 你的密码
```

---

## 📝 输出示例

```
==========================================
  锐捷网络认证助手 v2.0
  广东科学技术职业学院专用
==========================================

[STEP] 检测网络连接状态...
[INFO] 尝试连接: http://www.google.cn/generate_204
[✓] 检测成功: HTTP 204
[✓] 网络已连接，无需认证！
```

---

## ⏰ 定时任务（自动登录）

使用 **一键配置** 时会自动设置：

| 项目 | 设置 |
|------|------|
| 时间 | 每天 5:00 - 7:00 |
| 间隔 | 每5分钟 |
| 日志 | `/var/log/ruijie-login.log` |

### 手动配置

```bash
# 编辑定时任务
crontab -e

# 添加任务
*/5 5-7 * * * /usr/local/bin/ruijie-login 用户名 密码 >> /var/log/ruijie-login.log 2>&1
```

---

## ❓ 常见问题

### Q: 提示"需要输入验证码"？
> 当前脚本不支持验证码识别，请在网页端手动认证后再使用脚本。

### Q: 认证失败？
> 1. 检查用户名和密码是否正确
> 2. 检查网络是否正常
> 3. 尝试更换检测地址

### Q: 路由器上运行失败？
> 确保已安装 curl：`opkg install curl`

### Q: 联通网络不能用？
> 请提交 [Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues) 反馈

---

## 🔧 网络维护说明

| 项目 | 负责范围 |
|------|----------|
| 🏢 学校 | 墙壁网口 |
| 👤 用户 | 路由器及之后 |

---

## 📜 更新日志

### v2.1 (2025-03)
- 新增一键配置脚本 (setup.sh)
- 互动式中文安装界面
- 自动配置定时任务
- README 优化排版

### v2.0 (2025-03)
- 实时日志输出
- 多环境适配
- 彩色终端输出
- 错误处理优化

### v1.x
- 原始版本

---

## 📄 许可证

[GPL-3.0](LICENSE)

---

## 🤝 致谢

- 原作者: [error7904](https://github.com/error7904)
- 参考: [RuijiePortalLoginShellScript](https://github.com/1203746884/RuijiePortalLoginShellScript)

---

## 📧 联系

- GitHub: https://github.com/17388749803/Ruijie-Auto-Login
- 问题反馈: [提交 Issue](https://github.com/17388749803/Ruijie-Auto-Login/issues)
