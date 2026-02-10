#!/bin/bash
# Debian 12 VPC 初始化脚本
# GitHub: https://github.com/yourusername/debian12-vpc-init
# 使用: bash <(curl -sL https://raw.githubusercontent.com/yourusername/debian12-vpc-init/main/init.sh)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    clear
    echo -e "${GREEN}"
    echo "========================================="
    echo "    Debian 12 VPC 初始化脚本 v1.0"
    echo "    GitHub: https://github.com/yourusername/debian12-vpc-init"
    echo "========================================="
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 用户运行此脚本"
        log_info "使用: sudo bash $0"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/debian_version ]; then
        log_error "此脚本仅适用于 Debian/Ubuntu 系统"
        exit 1
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version)
    log_info "检测到 Debian 版本: $DEBIAN_VERSION"
    
    if [[ ! $DEBIAN_VERSION =~ ^12 ]]; then
        log_warning "此脚本主要针对 Debian 12 测试，当前版本: $DEBIAN_VERSION"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_dependencies() {
    log_info "安装依赖包..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # 更新包列表
    apt-get update
    
    # 基础工具
    apt-get install -y curl wget sudo socat git vim unzip ufw \
        jq htop net-tools dnsutils gnupg lsb-release \
        ca-certificates apt-transport-https software-properties-common
    
    log_success "依赖包安装完成"
}

configure_ssh() {
    log_info "配置 SSH 服务..."
    
    # 备份原配置
    BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="/etc/ssh/backup_$BACKUP_TIME"
    mkdir -p "$BACKUP_DIR"
    cp /etc/ssh/sshd_config "$BACKUP_DIR/"
    log_info "SSH 配置已备份到: $BACKUP_DIR"
    
    # 下载 GitHub 上的配置文件（可选）
    if command -v curl &> /dev/null; then
        log_info "从 GitHub 下载 SSH 配置模板..."
        TEMPLATE_URL="https://raw.githubusercontent.com/yourusername/debian12-vpc-init/main/config/ssh/sshd_config"
        if curl -s --fail "$TEMPLATE_URL" -o /tmp/sshd_config_template 2>/dev/null; then
            log_info "使用 GitHub 模板配置"
            cp /tmp/sshd_config_template /etc/ssh/sshd_config
        else
            log_warning "无法下载模板，使用本地配置"
            configure_ssh_local
        fi
    else
        configure_ssh_local
    fi
    
    # 测试配置
    if sshd -t; then
        log_success "SSH 配置语法正确"
    else
        log_error "SSH 配置语法错误，恢复备份"
        cp "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config
        sshd -t || {
            log_error "备份配置也有错误，使用默认配置"
            cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config 2>/dev/null || true
        }
    fi
    
    # 重启服务
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
    
    # 检查端口
    sleep 2
    log_info "检查 SSH 端口状态:"
    
    local ports=(22 22222)
    for port in "${ports[@]}"; do
        if ss -lntp | grep -q ":$port "; then
            log_success "端口 $port 监听正常"
        else
            log_warning "端口 $port 未监听"
        fi
    done
    
    log_success "SSH 配置完成"
}

configure_ssh_local() {
    log_info "应用本地 SSH 配置..."
    
    cat > /etc/ssh/sshd_config << 'EOF'
# Debian 12 VPC SSH 配置
# GitHub: https://github.com/yourusername/debian12-vpc-init

Port 22
Port 22222
ListenAddress 0.0.0.0

# 认证配置
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no

# 安全配置
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60

# 协议配置
Protocol 2
UseDNS no
Compression no
X11Forwarding no

# 日志配置
SyslogFacility AUTH
LogLevel INFO

# 其他配置
PrintMotd yes
PrintLastLog yes
TCPKeepAlive yes
AllowTcpForwarding yes
EOF
}

configure_firewall() {
    log_info "配置防火墙..."
    
    # 停止并重置
    ufw --force disable 2>/dev/null || true
    ufw --force reset 2>/dev/null || true
    
    # 默认策略
    ufw default deny incoming
    ufw default allow outgoing
    
    # 开放端口
    declare -A PORTS=(
        ["22"]="SSH"
        ["22222"]="SSH Alt"
        ["80"]="HTTP"
        ["443"]="HTTPS"
        ["8443"]="Alt HTTPS"
        ["54321"]="Custom"
        ["2096"]="Custom"
    )
    
    for port in "${!PORTS[@]}"; do
        log_info "开放端口 $port (${PORTS[$port]})"
        ufw allow "$port/tcp"
    done
    
    # 启用防火墙
    ufw --force enable
    systemctl enable ufw
    ufw reload
    
    log_success "防火墙配置完成"
    log_info "当前防火墙规则:"
    ufw status numbered | head -20
}

configure_system() {
    log_info "系统优化配置..."
    
    # 时区设置
    timedatectl set-timezone Asia/Shanghai
    timedatectl set-ntp true
    
    # 语言设置
    update-locale LANG=en_US.UTF-8 2>/dev/null || true
    
    # 内核优化
    cat >> /etc/sysctl.conf << 'EOF'
# Network optimization
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1

# Memory
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
    
    sysctl -p
    
    log_success "系统优化完成"
}

install_optional_tools() {
    log_info "安装可选工具..."
    
    read -p "是否安装 Docker？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 安装 Docker
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        usermod -aG docker $SUDO_USER 2>/dev/null || true
        log_success "Docker 安装完成"
    fi
    
    read -p "是否安装 Nginx？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get install -y nginx
        systemctl enable nginx
        log_success "Nginx 安装完成"
    fi
    
    read -p "是否安装监控工具？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get install -y glances nmon iftop iotop
        log_success "监控工具安装完成"
    fi
}

show_summary() {
    log_success "=== 初始化完成 ==="
    echo ""
    echo "系统信息:"
    echo "  - 主机名: $(hostname)"
    echo "  - IP地址: $(hostname -I | cut -d' ' -f1)"
    echo "  - 系统版本: $(lsb_release -ds 2>/dev/null || cat /etc/debian_version)"
    echo "  - 时区: $(timedatectl show --property=Timezone --value)"
    echo ""
    echo "服务状态:"
    echo "  - SSH端口: 22, 22222"
    echo "  - 防火墙: $(systemctl is-active ufw)"
    echo ""
    echo "测试命令:"
    echo "  ssh -p 22222 root@$(hostname -I | cut -d' ' -f1)"
    echo ""
    echo "配置备份:"
    find /etc/ssh/backup_* -maxdepth 0 -type d 2>/dev/null | head -3
    echo ""
    log_warning "重要提醒: 请立即测试 SSH 连接！"
}

main() {
    print_banner
    check_root
    check_os
    
    # 执行步骤
    local steps=(
        "install_dependencies:安装依赖包"
        "configure_ssh:配置SSH服务"
        "configure_firewall:配置防火墙"
        "configure_system:系统优化"
        "install_optional_tools:可选工具安装"
    )
    
    for step in "${steps[@]}"; do
        local func="${step%%:*}"
        local desc="${step#*:}"
        
        log_info "正在执行: $desc"
        if $func; then
            log_success "$desc 完成"
        else
            log_error "$desc 失败"
            read -p "是否继续？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        echo ""
    done
    
    show_summary
}

# 异常处理
trap 'log_error "脚本在行 $LINENO 处中断"; exit 1' ERR

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi