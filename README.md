# Debian 12 VPC 初始化脚本

一键初始化 Debian 12 VPS/云服务器的自动化脚本，配置 SSH、防火墙和系统优化。

## 🌟 功能特性

- ✅ 安全的 SSH 多端口配置（22 + 22222）
- ✅ UFW 防火墙配置
- ✅ 系统时区优化（Asia/Shanghai）
- ✅ 内核参数调优
- ✅ 可选组件安装（Docker, Nginx, 监控工具）
- ✅ 完整的错误处理和备份机制

## 🚀 快速开始

### 方法一：一键安装（推荐）

```bash
# 使用 root 用户运行
bash <(curl -sL https://raw.githubusercontent.com/happy6310/debian12-vpc-init/main/install.sh)



SSH 配置
端口: 22 (默认) + 22222 (备用)

允许 Root 登录: 是

允许密码认证: 是

监听地址: 0.0.0.0


22/tcp      - SSH
22222/tcp   - SSH 备用端口
80/tcp      - HTTP
443/tcp     - HTTPS
8443/tcp    - 备用 HTTPS
54321/tcp   - 自定义端口
2096/tcp    - 自定义端口

