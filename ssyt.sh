#!/bin/sh

set -e

# 协议列表
PROTOCOLS="shadowsocks v2ray naiveproxy"

# 配置目录
CONFIG_DIR="/etc/light-proxy"
mkdir -p $CONFIG_DIR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查Alpine系统
check_alpine() {
    if ! [ -f /etc/alpine-release ]; then
        echo -e "${RED}错误：此脚本仅适用于Alpine Linux系统${NC}"
        exit 1
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}      Alpine Linux 轻量级代理管理脚本       ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${GREEN}1. 安装代理协议${NC}"
    echo -e "${GREEN}2. 卸载代理协议${NC}"
    echo -e "${GREEN}3. 查看已安装协议${NC}"
    echo -e "${GREEN}4. 查看配置信息${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    echo -e "${BLUE}==============================================${NC}"
    read -p "请输入选项 [0-4]: " option
    case $option in
        1) install_menu ;;
        2) uninstall_menu ;;
        3) show_installed ;;
        4) show_configs ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1; show_menu ;;
    esac
}

# 安装子菜单
install_menu() {
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}           安装代理协议            ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${GREEN}1. 安装Shadowsocks${NC}"
    echo -e "${GREEN}2. 安装V2Ray${NC}"
    echo -e "${GREEN}3. 安装NaiveProxy${NC}"
    echo -e "${GREEN}4. 一键安装所有协议${NC}"
    echo -e "${YELLOW}0. 返回主菜单${NC}"
    echo -e "${BLUE}==============================================${NC}"
    read -p "请输入选项 [0-4]: " option
    
    case $option in
        1) install_protocol "shadowsocks" $(get_port "Shadowsocks");;
        2) install_protocol "v2ray" $(get_port "V2Ray");;
        3) install_protocol "naiveproxy" $(get_port "NaiveProxy");;
        4) install_all_protocols ;;
        0) show_menu ;;
        *) echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1; install_menu ;;
    esac
}

# 卸载子菜单
uninstall_menu() {
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}           卸载代理协议            ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${GREEN}1. 卸载Shadowsocks${NC}"
    echo -e "${GREEN}2. 卸载V2Ray${NC}"
    echo -e "${GREEN}3. 卸载NaiveProxy${NC}"
    echo -e "${GREEN}4. 一键卸载所有协议${NC}"
    echo -e "${YELLOW}0. 返回主菜单${NC}"
    echo -e "${BLUE}==============================================${NC}"
    read -p "请输入选项 [0-4]: " option
    
    case $option in
        1) uninstall_protocol "shadowsocks";;
        2) uninstall_protocol "v2ray";;
        3) uninstall_protocol "naiveproxy";;
        4) uninstall_all_protocols ;;
        0) show_menu ;;
        *) echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1; uninstall_menu ;;
    esac
}

# 获取端口号
get_port() {
    local protocol=$1
    read -p "请输入${protocol}端口号(留空使用随机端口): " port
    if [ -z "$port" ]; then
        port=$(generate_random_port)
    fi
    echo $port
}

# 显示已安装协议
show_installed() {
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}           已安装的代理协议          ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    
    if [ ! -f "$CONFIG_DIR/installed_protocols" ] || [ ! -s "$CONFIG_DIR/installed_protocols" ]; then
        echo -e "${YELLOW}当前没有安装任何代理协议${NC}"
    else
        echo -e "${GREEN}$(cat $CONFIG_DIR/installed_protocols)${NC}"
    fi
    
    echo -e "${BLUE}==============================================${NC}"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    show_menu
}

# 显示配置信息
show_configs() {
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}           代理配置信息            ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    
    for proto in $PROTOCOLS; do
        if grep -q "^$proto$" "$CONFIG_DIR/installed_protocols" 2>/dev/null; then
            echo -e "${YELLOW}${proto}配置:${NC}"
            case $proto in
                "shadowsocks")
                    if [ -f "$CONFIG_DIR/shadowsocks_url.txt" ]; then
                        echo -e "链接: ${GREEN}$(cat $CONFIG_DIR/shadowsocks_url.txt)${NC}"
                    fi
                    ;;
                "v2ray")
                    if [ -f "$CONFIG_DIR/v2ray_url.txt" ]; then
                        echo -e "VMESS链接: ${GREEN}$(cat $CONFIG_DIR/v2ray_url.txt)${NC}"
                    fi
                    ;;
                "naiveproxy")
                    if [ -f "$CONFIG_DIR/naiveproxy.json" ]; then
                        echo -e "用户名: ${GREEN}$(jq -r '.users | keys[0]' $CONFIG_DIR/naiveproxy.json 2>/dev/null)${NC}"
                        echo -e "密码: ${GREEN}$(jq -r '.users[]' $CONFIG_DIR/naiveproxy.json 2>/dev/null)${NC}"
                    fi
                    ;;
            esac
            echo ""
        fi
    done
    
    echo -e "${BLUE}==============================================${NC}"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    show_menu
}

# 安装所有协议
install_all_protocols() {
    echo -e "${YELLOW}开始一键安装所有代理协议...${NC}"
    for proto in $PROTOCOLS; do
        install_protocol "$proto" $(generate_random_port)
    done
    echo -e "${GREEN}所有协议安装完成！${NC}"
    sleep 2
    show_menu
}

# 卸载所有协议
uninstall_all_protocols() {
    echo -e "${YELLOW}开始一键卸载所有代理协议...${NC}"
    for proto in $PROTOCOLS; do
        uninstall_protocol "$proto"
    done
    echo -e "${GREEN}所有协议卸载完成！${NC}"
    sleep 2
    show_menu
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

# Shadowsocks配置
configure_shadowsocks() {
    local port=$1
    local password=$(generate_random_string 16)
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
    local port=$1
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
    local port=$1
    local username="user$(generate_random_string 4)"
    local password=$(generate_random_string 16)
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
    
    # 检查是否已安装
    if grep -q "^$protocol$" "$CONFIG_DIR/installed_protocols" 2>/dev/null; then
        echo -e "${YELLOW}${protocol}已经安装，跳过安装...${NC}"
        sleep 2
        return
    fi
    
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
    
    read -n 1 -s -r -p "安装完成，按任意键继续..."
    install_menu
}

# 卸载协议
uninstall_protocol() {
    local protocol=$1
    
    # 检查是否已安装
    if ! grep -q "^$protocol$" "$CONFIG_DIR/installed_protocols" 2>/dev/null; then
        echo -e "${YELLOW}${protocol}未安装，无需卸载...${NC}"
        sleep 2
        return
    fi
    
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
    
    read -n 1 -s -r -p "卸载完成，按任意键继续..."
    uninstall_menu
}

# 初始化检查
init_check() {
    check_alpine
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：请使用root用户运行此脚本${NC}"
        exit 1
    fi
    
    # 安装必要依赖
    install_dependencies
    optimize_memory
}

# 主程序
init_check
show_menu
