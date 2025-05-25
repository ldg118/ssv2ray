#!/bin/sh

set -e

# 协议列表
PROTOCOLS="wireguard shadowsocks v2ray naiveproxy"

# 默认配置目录
CONFIG_DIR="/etc/little-protocols"
mkdir -p $CONFIG_DIR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 系统检测
detect_os() {
    if [ -f /etc/alpine-release ]; then
        echo "alpine"
    elif [ -f /etc/debian_version ]; then
        if [ -f /etc/lsb-release ]; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    else
        echo "unknown"
    fi
}

# 依赖安装
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    case $(detect_os) in
        "alpine")
            apk add --no-cache curl jq openssl bash qrencode
            ;;
        "ubuntu"|"debian")
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                curl jq openssl bash qrencode
            ;;
        *)
            echo -e "${RED}Unsupported OS${NC}"
            exit 1
            ;;
    esac
}

# 内存优化
optimize_memory() {
    echo -e "${YELLOW}Optimizing system for low memory...${NC}"
    sysctl -w vm.swappiness=10
    sysctl -w vm.vfs_cache_pressure=50
    
    case $(detect_os) in
        "alpine")
            rc-update del local default 2>/dev/null || true
            ;;
        "ubuntu"|"debian")
            systemctl disable --now apt-daily.timer apt-daily-upgrade.timer
            ;;
    esac
}

# 生成随机端口
generate_random_port() {
    local min=10000
    local max=60000
    echo $(( $RANDOM % ($max - $min + 1) + $min ))
}

# 生成随机字符串
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# WireGuard配置
configure_wireguard() {
    local port=${1:-$(generate_random_port)}
    local config_file="$CONFIG_DIR/wg0.conf"
    
    echo -e "${YELLOW}Configuring WireGuard on port $port...${NC}"
    
    # 生成密钥
    umask 077
    wg genkey | tee $CONFIG_DIR/privatekey | wg pubkey > $CONFIG_DIR/publickey
    
    cat > $config_file <<EOF
[Interface]
PrivateKey = $(cat $CONFIG_DIR/privatekey)
Address = 10.8.0.1/24
ListenPort = $port
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $(cat $CONFIG_DIR/publickey)
AllowedIPs = 10.8.0.2/32
EOF

    echo -e "${GREEN}WireGuard configuration generated:${NC}"
    echo "Config file: $config_file"
    echo "Port: $port"
    echo "PrivateKey: $(cat $CONFIG_DIR/privatekey)"
    echo "PublicKey: $(cat $CONFIG_DIR/publickey)"
    
    # 生成客户端配置示例
    cat > $CONFIG_DIR/client.conf <<EOF
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.8.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat $CONFIG_DIR/publickey)
Endpoint = $(curl -s ifconfig.me):$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    echo -e "\n${YELLOW}Client config template saved to: $CONFIG_DIR/client.conf${NC}"
}

# Shadowsocks配置
configure_shadowsocks() {
    local port=${1:-$(generate_random_port)}
    local password=${2:-$(generate_random_string 16)}
    local method="chacha20-ietf-poly1305"
    local config_file="$CONFIG_DIR/shadowsocks.json"
    
    echo -e "${YELLOW}Configuring Shadowsocks on port $port...${NC}"
    
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

    echo -e "${GREEN}Shadowsocks configuration generated:${NC}"
    echo "Config file: $config_file"
    echo "Port: $port"
    echo "Password: $password"
    echo "Method: $method"
    
    # 生成SS链接
    ss_url="ss://$(echo -n "$method:$password" | base64 -w 0)@$(curl -s ifconfig.me):$port#LittleVPS"
    echo -e "\nShadowsocks URL: ${GREEN}$ss_url${NC}"
    echo "$ss_url" > $CONFIG_DIR/shadowsocks_url.txt
    
    # 生成二维码
    qrencode -t ANSIUTF8 "$ss_url"
}

# V2Ray配置
configure_v2ray() {
    local port=${1:-$(generate_random_port)}
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local config_file="/usr/local/etc/v2ray/config.json"
    
    echo -e "${YELLOW}Configuring V2Ray on port $port...${NC}"
    
    mkdir -p /usr/local/etc/v2ray
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
                "path": "/littlepath"
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}
EOF

    echo -e "${GREEN}V2Ray configuration generated:${NC}"
    echo "Config file: $config_file"
    echo "Port: $port"
    echo "UUID: $uuid"
    echo "AlterID: 64"
    echo "Transport: WebSocket"
    echo "Path: /littlepath"
    
    # 生成VMESS链接
    vmess_json=$(cat <<EOF
{
    "v": "2",
    "ps": "LittleVPS",
    "add": "$(curl -s ifconfig.me)",
    "port": "$port",
    "id": "$uuid",
    "aid": "64",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "/littlepath",
    "tls": ""
}
EOF
    )
    vmess_url="vmess://$(echo "$vmess_json" | base64 -w 0)"
    echo -e "\nV2Ray VMESS URL: ${GREEN}$vmess_url${NC}"
    echo "$vmess_url" > $CONFIG_DIR/v2ray_url.txt
    
    # 生成二维码
    qrencode -t ANSIUTF8 "$vmess_url"
}

# NaiveProxy配置
configure_naiveproxy() {
    local port=${1:-$(generate_random_port)}
    local username=${2:-user$(generate_random_string 4)}
    local password=${3:-$(generate_random_string 16)}
    local config_file="$CONFIG_DIR/naiveproxy.json"
    
    echo -e "${YELLOW}Configuring NaiveProxy on port $port...${NC}"
    
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

    echo -e "${GREEN}NaiveProxy configuration generated:${NC}"
    echo "Config file: $config_file"
    echo "Port: $port"
    echo "Username: $username"
    echo "Password: $password"
    
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

    echo -e "\n${YELLOW}Caddy config example saved to: $CONFIG_DIR/caddy_example.conf${NC}"
}

# 协议安装函数
install_protocol() {
    local protocol=$1
    local port=$2
    
    case $protocol in
        "wireguard")
            echo -e "${YELLOW}Installing WireGuard...${NC}"
            case $(detect_os) in
                "alpine")
                    apk add --no-cache wireguard-tools
                    ;;
                "ubuntu"|"debian")
                    apt-get install -y wireguard
                    ;;
            esac
            configure_wireguard $port
            ;;
        "shadowsocks")
            echo -e "${YELLOW}Installing Shadowsocks-libev...${NC}"
            case $(detect_os) in
                "alpine")
                    apk add --no-cache shadowsocks-libev
                    ;;
                "ubuntu"|"debian")
                    apt-get install -y shadowsocks-libev
                    ;;
            esac
            configure_shadowsocks $port
            ;;
        "v2ray")
            echo -e "${YELLOW}Installing V2Ray...${NC}"
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) \
                --version v4.45.2 --force
            configure_v2ray $port
            ;;
        "naiveproxy")
            echo -e "${YELLOW}Installing NaiveProxy...${NC}"
            curl -sSL https://github.com/klzgrad/naiveproxy/releases/download/v109.0.5414.74-1/naiveproxy-v109.0.5414.74-1-linux-x64.tar.xz | \
                tar xJ -C /usr/local/bin --strip-components=1
            configure_naiveproxy $port
            ;;
        *)
            echo -e "${RED}Unknown protocol: $protocol${NC}"
            exit 1
            ;;
    esac
    
    # 保存安装记录
    echo "$protocol" >> $CONFIG_DIR/installed_protocols
}

# 协议卸载函数
uninstall_protocol() {
    local protocol=$1
    
    case $protocol in
        "wireguard")
            echo -e "${YELLOW}Uninstalling WireGuard...${NC}"
            case $(detect_os) in
                "alpine")
                    apk del wireguard-tools
                    ;;
                "ubuntu"|"debian")
                    apt-get remove -y wireguard
                    ;;
            esac
            rm -rf /etc/wireguard
            ;;
        "shadowsocks")
            echo -e "${YELLOW}Uninstalling Shadowsocks-libev...${NC}"
            case $(detect_os) in
                "alpine")
                    apk del shadowsocks-libev
                    ;;
                "ubuntu"|"debian")
                    apt-get remove -y shadowsocks-libev
                    ;;
            esac
            rm -rf /etc/shadowsocks-libev
            ;;
        "v2ray")
            echo -e "${YELLOW}Uninstalling V2Ray...${NC}"
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            ;;
        "naiveproxy")
            echo -e "${YELLOW}Uninstalling NaiveProxy...${NC}"
            rm -f /usr/local/bin/naive
            rm -f /usr/local/bin/naiveproxy
            ;;
        *)
            echo -e "${RED}Unknown protocol: $protocol${NC}"
            exit 1
            ;;
    esac
    
    # 从安装记录中移除
    sed -i "/^$protocol$/d" $CONFIG_DIR/installed_protocols 2>/dev/null
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}Usage: $0 [command] [protocol] [port]${NC}"
    echo ""
    echo "Commands:"
    echo "  install [protocol] [port]    Install and configure protocol"
    echo "  uninstall [protocol]        Uninstall protocol"
    echo "  list                        List available protocols"
    echo "  installed                   List installed protocols"
    echo ""
    echo "Available protocols: $PROTOCOLS"
    echo "Use 'all' to install/uninstall all protocols"
    echo ""
    echo "Examples:"
    echo "  $0 install wireguard 51820"
    echo "  $0 install shadowsocks 8388"
    echo "  $0 uninstall v2ray"
}

# 主函数
main() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Please run as root${NC}"
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
            echo -e "${GREEN}Available protocols: $PROTOCOLS${NC}"
            ;;
        "installed")
            echo -e "${GREEN}Installed protocols:${NC}"
            cat $CONFIG_DIR/installed_protocols 2>/dev/null || echo "None"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
