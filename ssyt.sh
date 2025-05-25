#!/bin/sh

set -e

# 协议列表（移除了WireGuard）
PROTOCOLS="shadowsocks v2ray naiveproxy"

# 配置目录
CONFIG_DIR="/etc/light-proxy"
mkdir -p $CONFIG_DIR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查Alpine系统
check_alpine() {
    if ! [ -f /etc/alpine-release ]; then
        echo -e "${RED}错误：此脚本仅适用于Alpine Linux系统${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}正在安装依赖包...${NC}"
    apk add --no-cache curl jq openssl bash qrencode
}

# 内存优化
optimize_memory() {
    echo -e "${YELLOW}正在进行内存优化...${NC}"
    sysctl -w vm.swappiness=10
    sysctl -w vm.vfs_cache_pressure=50
    rc-update del local default 2>/dev/null || true
}

# 生成随机端口
generate_random_port() {
    echo $(( $(od -An -N2 -i /dev/urandom) % 50000 + 10000 ))
}

# 生成随机字符串
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# Shadowsocks配置
configure_shadowsocks() {
    local port=${1:-$(generate_random_port)}
    local password=${2:-$(generate_random_string 16)}
    local method="chacha20-ietf-poly1305"
    local config_file="$CONFIG_DIR/shadowsocks.json"
    
    echo -e "${YELLOW}正在配置Shadowsocks (端口: $port)...${NC}"
    
    cat > $config_file <<EOF
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "method":"$method",
    "timeout":300,
    "fast_open":false,
    "mode":"tcp_and_udp"
}
EOF

    echo -e "${GREEN}Shadowsocks配置生成成功:${NC}"
    echo "配置文件: $config_file"
    echo "端口: $port"
    echo "密码: $password"
    echo "加密方式: $method"
    
    # 生成SS链接
    ss_url="ss://$(echo -n "$method:$password" | base64 -w 0)@$(curl -s ifconfig.me):$port#AlpineVPS"
    echo -e "\nShadowsocks链接: ${GREEN}$ss_url${NC}"
    echo "$ss_url" > $CONFIG_DIR/shadowsocks_url.txt
    
    # 生成二维码
    echo -e "\n二维码:"
    qrencode -t ANSIUTF8 "$ss_url"
}

# V2Ray配置
configure_v2ray() {
    local port=${1:-$(generate_random_port)}
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local config_file="/etc/v2ray/config.json"
    
    echo -e "${YELLOW}正在配置V2Ray (端口: $port)...${NC}"
    
    mkdir -p /etc/v2ray
    cat > $config_file <<EOF
{
    "inbounds": [{
        "port": $port,
        "protocol": "vmess",
        "settings": {
            "clients": [{
                "id": "$uuid",
                "alterId": 64
            }]
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {
                "path": "/alpine"
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}
EOF

    echo -e "${GREEN}V2Ray配置生成成功:${NC}"
    echo "配置文件: $config_file"
    echo "端口: $port"
    echo "UUID: $uuid"
    echo "AlterID: 64"
    echo "传输协议: WebSocket"
    echo "路径: /alpine"
    
    # 生成VMESS链接
    vmess_json=$(cat <<EOF
{
    "v": "2",
    "ps": "AlpineVPS",
    "add": "$(curl -s ifconfig.me)",
    "port": "$port",
    "id": "$uuid",
    "aid": "64",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "/alpine",
    "tls": ""
}
EOF
    )
    vmess_url="vmess://$(echo "$vmess_json" | base64 -w 0)"
    echo -e "\nV2Ray VMESS链接: ${GREEN}$vmess_url${NC}"
    echo "$vmess_url" > $CONFIG_DIR/v2ray_url.txt
    
    # 生成二维码
    echo -e "\n二维码:"
    qrencode -t ANSIUTF8 "$vmess_url"
}

# NaiveProxy配置
configure_naiveproxy() {
    local port=${1:-$(generate_random_port)}
    local username=${2:-user$(generate_random_string 4)}
    local password=${3:-$(generate_random_string 16)}
    local config_file="$CONFIG_DIR/naiveproxy.json"
    
    echo -e "${YELLOW}正在配置NaiveProxy (端口: $port)...${NC}"
    
    cat > $config_file <<EOF
{
    "listen": "http://0.0.0.0:$port",
    "padding": true,
    "probe_resistance": {},
    "insecure": false,
    "timeout": 300,
    "log": "",
    "users": {
        "$username": "$password"
    }
}
EOF

    echo -e "${GREEN}NaiveProxy配置生成成功:${NC}"
    echo "配置文件: $config_file"
    echo "端口: $port"
    echo "用户名: $username"
    echo "密码: $password"
    
    # 生成Caddy配置示例
    cat > $CONFIG_DIR/caddy_example.conf <<EOF
$(curl -s ifconfig.me) {
    route {
        forward_proxy {
            basic_auth $username $password
            hide_ip
            hide_via
            probe_resistance
        }
        file_server { root /var/www/html }
    }
}
EOF

    echo -e "\n${YELLOW}Caddy配置文件示例已保存到: $CONFIG_DIR/caddy_example.conf${NC}"
}

# 安装协议
install_protocol() {
    local protocol=$1
    local port=$2
    
    case $protocol in
        "shadowsocks")
            echo -e "${YELLOW}正在安装Shadowsocks-libev...${NC}"
            apk add --no-cache shadowsocks-libev
            configure_shadowsocks $port
            ;;
        "v2ray")
            echo -e "${YELLOW}正在安装V2Ray...${NC}"
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) \
                --version v4.45.2 --force
            configure_v2ray $port
            ;;
        "naiveproxy")
            echo -e "${YELLOW}正在安装NaiveProxy...${NC}"
            curl -sSL https://github.com/klzgrad/naiveproxy/releases/download/v109.0.5414.74-1/naiveproxy-v109.0.5414.74-1-linux-x64.tar.xz | \
                tar xJ -C /usr/local/bin --strip-components=1
            configure_naiveproxy $port
            ;;
        *)
            echo -e "${RED}未知协议: $protocol${NC}"
            exit 1
            ;;
    esac
    
    # 保存安装记录
    echo "$protocol" >> $CONFIG_DIR/installed_protocols
}

# 卸载协议
uninstall_protocol() {
    local protocol=$1
    
    case $protocol in
        "shadowsocks")
            echo -e "${YELLOW}正在卸载Shadowsocks-libev...${NC}"
            apk del shadowsocks-libev
            rm -rf /etc/shadowsocks-libev
            ;;
        "v2ray")
            echo -e "${YELLOW}正在卸载V2Ray...${NC}"
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            ;;
        "naiveproxy")
            echo -e "${YELLOW}正在卸载NaiveProxy...${NC}"
            rm -f /usr/local/bin/naive
            rm -f /usr/local/bin/naiveproxy
            ;;
        *)
            echo -e "${RED}未知协议: $protocol${NC}"
            exit 1
            ;;
    esac
    
    # 从安装记录中移除
    sed -i "/^$protocol$/d" $CONFIG_DIR/installed_protocols 2>/dev/null
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法: $0 [命令] [协议] [端口]${NC}"
    echo ""
    echo "命令列表:"
    echo "  install [协议] [端口]    安装并配置指定协议"
    echo "  uninstall [协议]        卸载指定协议"
    echo "  list                    查看可用协议"
    echo "  installed               查看已安装协议"
    echo ""
    echo "可用协议: $PROTOCOLS"
    echo "使用 'all' 可以安装/卸载所有协议"
    echo ""
    echo "示例:"
    echo "  $0 install shadowsocks 8388"
    echo "  $0 install v2ray"
    echo "  $0 uninstall naiveproxy"
}

# 主函数
main() {
    check_alpine
    
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：请使用root用户运行此脚本${NC}"
        exit 1
    fi

    case $1 in
        "install")
            install_dependencies
            optimize_memory
            
            if [ -z "$2" ]; then
                show_help
                exit 1
            fi
            
            if [ "$2" = "all" ]; then
                for proto in $PROTOCOLS; do
                    install_protocol $proto $3
                done
            else
                install_protocol "$2" "$3"
            fi
            ;;
        "uninstall")
            if [ -z "$2" ]; then
                show_help
                exit 1
            fi
            
            if [ "$2" = "all" ]; then
                for proto in $PROTOCOLS; do
                    uninstall_protocol $proto
                done
            else
                uninstall_protocol "$2"
            fi
            ;;
        "list")
            echo -e "${GREEN}可用协议: $PROTOCOLS${NC}"
            ;;
        "installed")
            echo -e "${GREEN}已安装协议:${NC}"
            cat $CONFIG_DIR/installed_protocols 2>/dev/null || echo "无"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
