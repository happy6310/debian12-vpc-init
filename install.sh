#!/bin/bash
# 一键安装脚本
# 用法: bash <(curl -sL https://raw.githubusercontent.com/yourusername/debian12-vpc-init/main/install.sh)

set -e

REPO_URL="https://github.com/happy6310/debian12-vpc-init"
SCRIPT_URL="https://raw.githubusercontent.com/happy6310/debian12-vpc-init/main/init.sh"

echo "下载 Debian 12 VPC 初始化脚本..."
echo "仓库: $REPO_URL"

# 检查是否 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 权限运行或使用 sudo"
    echo "示例: sudo bash <(curl -sL $SCRIPT_URL)"
    exit 1
fi

# 下载并运行
echo "正在下载脚本..."
curl -sL "$SCRIPT_URL" -o /tmp/debian-init.sh

echo "设置执行权限..."
chmod +x /tmp/debian-init.sh

echo "开始执行初始化..."
echo "========================================"
bash /tmp/debian-init.sh