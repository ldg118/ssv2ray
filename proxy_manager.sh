#!/bin/bash

# ============================================
# 高级代理协议管理脚本 v6.0
# 整合：https://github.com/ldg118/Proxy 最佳实践
# 功能：SS/VMess/VLESS/Trojan/Hysteria安装管理
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局配置
LOG_FILE="/var/log/proxy_manager.log"
CONFIG_DIR="/etc/proxy_manager"
CONFIG_FILE="$CONFIG_DIR/config.json"
BACKUP_DIR="$CONFIG_DIR/backups"
TEMP_DIR="/tmp/proxy_manager"

# 支持的协议
SUPPORTED_PROTOCOLS=("ss" "vmess" "vless" "trojan" "hysteria")

# 初始化日志系统
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "初始化日志系统完成" "$GREEN"
}

# 带颜色日志记录
log() {
    local msg="$1"
    local color="${2:-$NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${color}${msg}${NC}" | tee -a "$LOG_FILE"
}

# 绘制界面元素
draw_line() {
    echo -e "${PURPLE}============================================${NC}"
}

draw_header() {
    clear
    draw_line
    echo -e "${PURPLE}         高级代理协议管理脚本 v6.0         ${NC}"
    echo -e "${PURPLE}============================================${NC}"
}

# 系统检查
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "错误: 需要root权限运行!" "$RED"
        echo -e "${YELLOW}请使用 sudo bash $0 运行${NC}"
        exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/centos-release ]; then
        OS=centos
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi

    case "$OS" in
        ubuntu|debian|centos|alpine) ;;
        *)
            log "不支持的操作系统: $OS" "$RED"
            exit 1
            ;;
    esac

    log "检测到操作系统: $OS" "$GREEN"
    echo "$OS"
}

# 依赖管理
install_dependencies() {
    local os=$1
    log "安装系统依赖..." "$GREEN"

    case "$os" in
        ubuntu|debian)
            apt-get update >/dev/null 2>&1
            apt-get install -y curl wget jq qrencode openssl >/dev/null 2>&1
            ;;
        centos)
            yum install -y epel-release >/dev/null 2>&1
            yum install -y curl wget jq qrencode openssl >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache curl wget jq qrencode openssl >/dev/null 2>&1
            ;;
    esac

    # 验证关键依赖
    for cmd in curl wget jq; do
        if ! command -v "$cmd" &>/dev/null; then
            log "依赖安装失败: $cmd" "$RED"
            return 1
        fi
    done

    log "依赖安装完成" "$GREEN"
    return 0
}

# 配置管理
init_config() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$TEMP_DIR"
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
    fi
}

save_config() {
    local protocol=$1
    local config=$2
    
    if ! jq --arg proto "$protocol" --argjson conf "$config" \
       '. + {($proto): $conf}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"; then
        log "保存配置失败!" "$RED"
        return 1
    fi
    
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

backup_config() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$BACKUP_DIR/config_$timestamp.json"
    
    cp "$CONFIG_FILE" "$backup_file"
    log "配置已备份到: $backup_file" "$GREEN"
}

# 协议安装函数
install_ss() {
    log "开始安装Shadowsocks..." "$GREEN"
    
    local port=$(read_input "请输入端口" "8388")
    local password=$(read_input "请输入密码" "$(generate_password)")
    local method=$(read_input "请输入加密方法" "aes-256-gcm")
    local remark=$(read_input "请输入备注" "MySS")
    
    # 安装Shadowsocks
    if ! command -v ssserver &>/dev/null; then
        case "$OS" in
            ubuntu|debian)
                wget -qO- https://get.shadowsocks.org | bash
                ;;
            centos)
                yum install -y shadowsocks-libev
                ;;
            alpine)
                apk add --no-cache shadowsocks-libev
                ;;
        esac
        
        if ! command -v ssserver &>/dev/null; then
            log "Shadowsocks安装失败!" "$RED"
            return 1
        fi
    fi
    
    # 配置
    local config_path="/etc/shadowsocks-libev/config.json"
    mkdir -p "$(dirname "$config_path")"
    
    cat > "$config_path" <<EOF
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "method":"$method",
    "mode":"tcp_and_udp"
}
EOF
    
    # 服务管理
    systemctl enable shadowsocks-libev >/dev/null 2>&1
    systemctl restart shadowsocks-libev || {
        log "启动Shadowsocks服务失败!" "$RED"
        return 1
    }
    
    # 保存配置
    local public_ip=$(get_public_ip)
    local config_json=$(jq -n \
        --arg ip "$public_ip" \
        --arg port "$port" \
        --arg pass "$password" \
        --arg method "$method" \
        --arg remark "$remark" \
        '{ip: $ip, port: $port, password: $pass, method: $method, remark: $remark}')
    
    save_config "ss" "$config_json"
    
    # 显示信息
    show_config "ss" "$config_json"
    log "Shadowsocks安装完成" "$GREEN"
}

install_v2ray() {
    local protocol=$1  # vmess 或 vless
    log "开始安装V2Ray ($protocol)..." "$GREEN"
    
    local port=$(read_input "请输入端口" "10086")
    local uuid=$(generate_uuid)
    local alter_id=$(read_input "请输入alterId" "64")
    local remark=$(read_input "请输入备注" "MyV2Ray")
    
    # 安装V2Ray
    if ! command -v v2ray &>/dev/null; then
        bash <(curl -sL https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
        
        if ! command -v v2ray &>/dev/null; then
            log "V2Ray安装失败!" "$RED"
            return 1
        fi
    fi
    
    # 配置
    local config_path="/etc/v2ray/config.json"
    mkdir -p "$(dirname "$config_path")"
    
    if [ "$protocol" == "vmess" ]; then
        cat > "$config_path" <<EOF
{
    "inbounds": [{
        "port": $port,
        "protocol": "vmess",
        "settings": {
            "clients": [{
                "id": "$uuid",
                "alterId": $alter_id
            }]
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}
EOF
    else  # vless
        cat > "$config_path" <<EOF
{
    "inbounds": [{
        "port": $port,
        "protocol": "vless",
        "settings": {
            "clients": [{
                "id": "$uuid"
            }],
            "decryption": "none"
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}
EOF
    fi
    
    # 服务管理
    systemctl enable v2ray >/dev/null 2>&1
    systemctl restart v2ray || {
        log "启动V2Ray服务失败!" "$RED"
        return 1
    }
    
    # 保存配置
    local public_ip=$(get_public_ip)
    local config_json=$(jq -n \
        --arg ip "$public_ip" \
        --arg port "$port" \
        --arg uuid "$uuid" \
        --arg aid "$alter_id" \
        --arg remark "$remark" \
        '{ip: $ip, port: $port, uuid: $uuid, alterId: $aid, remark: $remark}')
    
    save_config "$protocol" "$config_json"
    
    # 显示信息
    show_config "$protocol" "$config_json"
    log "V2Ray ($protocol)安装完成" "$GREEN"
}

# [其他协议安装函数类似...]

# 实用函数
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 16
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

get_public_ip() {
    curl -s https://api.ipify.org || echo "127.0.0.1"
}

read_input() {
    local prompt=$1
    local default=$2
    local input
    
    while true; do
        read -p "$prompt [默认: $default]: " input
        input=${input:-$default}
        
        if [ -n "$input" ]; then
            echo "$input"
            return
        fi
    done
}

show_config() {
    local protocol=$1
    local config=$2
    
    draw_header
    echo -e "${GREEN}${protocol^^} 配置信息${NC}"
    echo -e "${BLUE}════════════════════════════════════${NC}"
    
    case "$protocol" in
        ss)
            echo -e "服务器: $(jq -r '.ip' <<< "$config")"
            echo -e "端口: $(jq -r '.port' <<< "$config")"
            echo -e "密码: $(jq -r '.password' <<< "$config")"
            echo -e "加密: $(jq -r '.method' <<< "$config")"
            ;;
        vmess|vless)
            echo -e "服务器: $(jq -r '.ip' <<< "$config")"
            echo -e "端口: $(jq -r '.port' <<< "$config")"
            echo -e "用户ID: $(jq -r '.uuid' <<< "$config")"
            [ "$protocol" == "vmess" ] && echo -e "alterId: $(jq -r '.alterId' <<< "$config")"
            ;;
    esac
    
    echo -e "备注: $(jq -r '.remark' <<< "$config")"
    echo -e "${BLUE}════════════════════════════════════${NC}"
    
    # 生成分享链接
    generate_share_link "$protocol" "$config"
}

generate_share_link() {
    local protocol=$1
    local config=$2
    
    case "$protocol" in
        ss)
            local ip=$(jq -r '.ip' <<< "$config")
            local port=$(jq -r '.port' <<< "$config")
            local password=$(jq -r '.password' <<< "$config")
            local method=$(jq -r '.method' <<< "$config")
            local remark=$(jq -r '.remark' <<< "$config")
            
            local ss_uri="ss://$(echo -n "${method}:${password}@${ip}:${port}" | base64 -w 0)#${remark}"
            echo -e "${CYAN}分享链接:${NC}"
            echo -e "$ss_uri"
            
            if command -v qrencode &>/dev/null; then
                echo -e "${YELLOW}二维码:${NC}"
                qrencode -t UTF8 "$ss_uri"
            fi
            ;;
        # [其他协议分享链接生成...]
    esac
}

# 主菜单
show_menu() {
    draw_header
    echo -e "${CYAN}1. 安装 Shadowsocks${NC}"
    echo -e "${CYAN}2. 安装 VMess${NC}"
    echo -e "${CYAN}3. 安装 VLESS${NC}"
    echo -e "${CYAN}4. 安装 Trojan${NC}"
    echo -e "${CYAN}5. 安装 Hysteria${NC}"
    echo -e "${CYAN}6. 查看所有配置${NC}"
    echo -e "${CYAN}7. 备份配置${NC}"
    echo -e "${RED}0. 退出${NC}"
    draw_line
}

# 主函数
main() {
    check_root
    init_log
    OS=$(check_os)
    
    if ! install_dependencies "$OS"; then
        log "依赖安装失败，请手动安装后重试" "$RED"
        exit 1
    fi
    
    init_config
    
    while true; do
        show_menu
        read -p "请输入选项: " choice
        
        case "$choice" in
            1) install_ss ;;
            2) install_v2ray "vmess" ;;
            3) install_v2ray "vless" ;;
            # [其他选项...]
            0)
                log "退出脚本" "$GREEN"
                exit 0
                ;;
            *)
                log "无效选项!" "$RED"
                ;;
        esac
        
        read -p "按Enter键继续..."
    done
}

# 启动脚本
main
