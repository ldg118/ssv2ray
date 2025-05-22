#!/bin/bash

# ==============================================
# 多协议代理安装与管理脚本
# 支持系统：Ubuntu/Debian/Alpine
# 支持协议：vmess/vless/trojan/socks/shadowsocks/hysteria2
# 支持核心：V2Ray/Xray/sing-box
# 功能：自动配置、TLS、Reality、gRPC、WebSocket等
# ==============================================

# 版本信息
VERSION="2.0"
LANGUAGE="zh"
BASE_DIR="/etc/multi-proxy"
BIN_DIR="$BASE_DIR/bin"
CONFIG_DIR="$BASE_DIR/conf"
SCRIPT_DIR="$BASE_DIR/script"
CERT_DIR="$BASE_DIR/cert"
LOG_DIR="$BASE_DIR/log"
SYSTEMD_DIR="/etc/systemd/system"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'

# 初始化目录
init_dirs() {
    mkdir -p "$BASE_DIR" "$BIN_DIR" "$CONFIG_DIR" "$SCRIPT_DIR" "$CERT_DIR" "$LOG_DIR"
}

# 检测系统
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
    else
        echo -e "${RED}无法检测操作系统${PLAIN}"
        exit 1
    fi

    case "$OS" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            INSTALL_CMD="apt install -y"
            ;;
        alpine)
            PKG_MANAGER="apk"
            INSTALL_CMD="apk add"
            ;;
        *)
            echo -e "${RED}不支持的系统: $OS${PLAIN}"
            exit 1
            ;;
    esac
}

# 安装依赖
install_deps() {
    echo -e "${GREEN}正在安装必要依赖...${PLAIN}"
    
    if [ "$PKG_MANAGER" = "apk" ]; then
        $INSTALL_CMD bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates
    else
        $INSTALL_CMD bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates
    fi
    
    # 检查是否安装成功
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}依赖安装失败，请检查网络连接${PLAIN}"
        exit 1
    fi
}

# 检查root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}请使用root权限运行此脚本${PLAIN}"
        exit 1
    fi
}

# 安装acme.sh
install_acme() {
    if ! command -v acme.sh &> /dev/null; then
        echo -e "${GREEN}正在安装acme.sh...${PLAIN}"
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
        echo -e "${GREEN}acme.sh 安装成功${PLAIN}"
    else
        echo -e "${YELLOW}acme.sh 已经安装${PLAIN}"
    fi
}

# 申请证书
issue_cert() {
    install_acme
    
    read -p "请输入域名: " domain
    read -p "请输入邮箱(可选): " email
    
    if [ -z "$email" ]; then
        email="admin@$domain"
    fi
    
    echo -e "${GREEN}正在为 $domain 申请证书...${PLAIN}"
    
    # 临时停止nginx
    if pgrep nginx > /dev/null; then
        systemctl stop nginx
    fi
    
    ~/.acme.sh/acme.sh --issue --standalone -d "$domain" --email "$email"
    
    # 安装证书
    mkdir -p "$CERT_DIR/$domain"
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file "$CERT_DIR/$domain/key.pem" \
        --fullchain-file "$CERT_DIR/$domain/cert.pem"
    
    # 重启nginx
    if [ -f "/etc/init.d/nginx" ]; then
        systemctl start nginx
    fi
    
    echo -e "${GREEN}证书申请成功，保存在 $CERT_DIR/$domain/${PLAIN}"
}

# 安装Xray
install_xray() {
    local version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo -e "${GREEN}正在安装 Xray $version...${PLAIN}"
    
    case "$(uname -m)" in
        x86_64)
            arch="64"
            ;;
        aarch64|armv8)
            arch="arm64-v8a"
            ;;
        *)
            echo -e "${RED}不支持的架构: $(uname -m)${PLAIN}"
            exit 1
            ;;
    esac
    
    wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/$version/Xray-linux-$arch.zip"
    unzip -o xray.zip -d "$BIN_DIR"
    chmod +x "$BIN_DIR/xray"
    rm -f xray.zip
    
    # 创建配置文件
    cat > "$CONFIG_DIR/xray.json" <<EOF
{
    "log": {
        "loglevel": "warning",
        "access": "$LOG_DIR/xray-access.log",
        "error": "$LOG_DIR/xray-error.log"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$(cat /proc/sys/kernel/random/uuid)",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.apple.com:443",
                    "xver": 0,
                    "serverNames": ["www.apple.com"],
                    "privateKey": "",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 0,
                    "shortIds": [""]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    
    # 创建systemd服务
    cat > "$SYSTEMD_DIR/xray.service" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$BIN_DIR/xray run -config $CONFIG_DIR/xray.json
Restart=on-failure
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xray
    systemctl start xray
    
    echo -e "${GREEN}Xray 安装完成${PLAIN}"
}

# 安装V2Ray
install_v2ray() {
    echo -e "${GREEN}正在安装 V2Ray...${PLAIN}"
    
    wget -O v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
    unzip -o v2ray.zip -d "$BIN_DIR"
    chmod +x "$BIN_DIR/v2ray"
    rm -f v2ray.zip
    
    # 创建配置文件
    cat > "$CONFIG_DIR/v2ray.json" <<EOF
{
    "log": {
        "loglevel": "warning",
        "access": "$LOG_DIR/v2ray-access.log",
        "error": "$LOG_DIR/v2ray-error.log"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$(cat /proc/sys/kernel/random/uuid)",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/ray"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
    
    # 创建systemd服务
    cat > "$SYSTEMD_DIR/v2ray.service" <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
ExecStart=$BIN_DIR/v2ray run -config $CONFIG_DIR/v2ray.json
Restart=on-failure
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable v2ray
    systemctl start v2ray
    
    echo -e "${GREEN}V2Ray 安装完成${PLAIN}"
}

# 安装sing-box
install_singbox() {
    local version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo -e "${GREEN}正在安装 sing-box $version...${PLAIN}"
    
    case "$(uname -m)" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|armv8)
            arch="arm64"
            ;;
        *)
            echo -e "${RED}不支持的架构: $(uname -m)${PLAIN}"
            exit 1
            ;;
    esac
    
    wget -O sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/$version/sing-box-$version-linux-$arch.tar.gz"
    tar -xzf sing-box.tar.gz -C "$BIN_DIR" --strip-components=1
    chmod +x "$BIN_DIR/sing-box"
    rm -f sing-box.tar.gz
    
    # 创建配置文件
    cat > "$CONFIG_DIR/singbox.json" <<EOF
{
    "log": {
        "level": "warn",
        "output": "$LOG_DIR/singbox.log"
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "uuid": "$(cat /proc/sys/kernel/random/uuid)",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "transport": {
                "type": "grpc",
                "service_name": "grpc-service"
            },
            "tls": {
                "enabled": true,
                "server_name": "example.com",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.apple.com",
                        "server_port": 443
                    },
                    "private_key": "",
                    "short_id": [""]
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ]
}
EOF
    
    # 创建systemd服务
    cat > "$SYSTEMD_DIR/sing-box.service" <<EOF
[Unit]
Description=sing-box Service
After=network.target

[Service]
ExecStart=$BIN_DIR/sing-box run -c $CONFIG_DIR/singbox.json
Restart=on-failure
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    
    echo -e "${GREEN}sing-box 安装完成${PLAIN}"
}

# 生成分享链接
generate_links() {
    local config_file=""
    local protocol=""
    
    echo -e "${BLUE}请选择要生成链接的协议:${PLAIN}"
    echo "1) V2Ray (VMess)"
    echo "2) Xray (VLESS)"
    echo "3) Trojan"
    echo "4) Shadowsocks"
    echo "5) Hysteria2"
    read -p "请输入选项(1-5): " choice
    
    case $choice in
        1)
            config_file="$CONFIG_DIR/v2ray.json"
            protocol="vmess"
            ;;
        2)
            config_file="$CONFIG_DIR/xray.json"
            protocol="vless"
            ;;
        3)
            config_file="$CONFIG_DIR/trojan.json"
            protocol="trojan"
            ;;
        4)
            config_file="$CONFIG_DIR/ss.json"
            protocol="shadowsocks"
            ;;
        5)
            config_file="$CONFIG_DIR/hysteria2.json"
            protocol="hysteria2"
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            return
            ;;
    esac
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}配置文件不存在，请先安装对应服务${PLAIN}"
        return
    fi
    
    case $protocol in
        vmess)
            local uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$config_file")
            local port=$(jq -r '.inbounds[0].port' "$config_file")
            local alterId=$(jq -r '.inbounds[0].settings.clients[0].alterId' "$config_file")
            local network=$(jq -r '.inbounds[0].streamSettings.network' "$config_file")
            local path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$config_file")
            
            # 生成VMess链接
            local vmess_config=$(jq -n \
                --arg v "2" \
                --arg ps "MyV2Ray" \
                --arg add "$(curl -s ifconfig.me)" \
                --arg port "$port" \
                --arg id "$uuid" \
                --arg aid "$alterId" \
                --arg net "$network" \
                --arg path "$path" \
                --arg type "none" \
                '{v: $v, ps: $ps, add: $add, port: $port, id: $id, aid: $aid, net: $net, type: $type, path: $path}')
            
            local vmess_link="vmess://$(echo "$vmess_config" | base64 -w 0)"
            echo -e "${GREEN}VMess 链接:${PLAIN}"
            echo "$vmess_link"
            echo ""
            echo -e "${YELLOW}二维码:${PLAIN}"
            echo "$vmess_link" | qrencode -t UTF8
            ;;
        vless)
            local uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$config_file")
            local port=$(jq -r '.inbounds[0].port' "$config_file")
            local flow=$(jq -r '.inbounds[0].settings.clients[0].flow' "$config_file")
            local server_name=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$config_file")
            local short_id=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$config_file")
            
            # 生成VLESS链接
            local vless_link="vless://$uuid@$(curl -s ifconfig.me):$port?encryption=none&flow=$flow&security=reality&sni=$server_name&fp=chrome&pbk=&sid=$short_id&type=tcp&headerType=none#MyXray"
            echo -e "${GREEN}VLESS 链接:${PLAIN}"
            echo "$vless_link"
            echo ""
            echo -e "${YELLOW}二维码:${PLAIN}"
            echo "$vless_link" | qrencode -t UTF8
            ;;
        trojan)
            local password=$(jq -r '.inbounds[0].clients[0].password' "$config_file")
            local port=$(jq -r '.inbounds[0].port' "$config_file")
            local sni=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
            
            # 生成Trojan链接
            local trojan_link="trojan://$password@$(curl -s ifconfig.me):$port?security=tls&sni=$sni&type=tcp&headerType=none#MyTrojan"
            echo -e "${GREEN}Trojan 链接:${PLAIN}"
            echo "$trojan_link"
            echo ""
            echo -e "${YELLOW}二维码:${PLAIN}"
            echo "$trojan_link" | qrencode -t UTF8
            ;;
        shadowsocks)
            local method=$(jq -r '.inbounds[0].method' "$config_file")
            local password=$(jq -r '.inbounds[0].password' "$config_file")
            local port=$(jq -r '.inbounds[0].port' "$config_file")
            
            # 生成Shadowsocks链接
            local ss_link="ss://$(echo -n "$method:$password" | base64 -w 0)@$(curl -s ifconfig.me):$port#MyShadowsocks"
            echo -e "${GREEN}Shadowsocks 链接:${PLAIN}"
            echo "$ss_link"
            echo ""
            echo -e "${YELLOW}二维码:${PLAIN}"
            echo "$ss_link" | qrencode -t UTF8
            ;;
        hysteria2)
            local password=$(jq -r '.inbounds[0].users[0].password' "$config_file")
            local port=$(jq -r '.inbounds[0].listen_port' "$config_file")
            local sni=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
            
            # 生成Hysteria2链接
            local hy2_link="hysteria2://$password@$(curl -s ifconfig.me):$port?insecure=0&sni=$sni#MyHysteria2"
            echo -e "${GREEN}Hysteria2 链接:${PLAIN}"
            echo "$hy2_link"
            echo ""
            echo -e "${YELLOW}二维码:${PLAIN}"
            echo "$hy2_link" | qrencode -t UTF8
            ;;
    esac
}

# 修改配置
modify_config() {
    echo -e "${BLUE}请选择要修改的服务:${PLAIN}"
    echo "1) V2Ray"
    echo "2) Xray"
    echo "3) sing-box"
    read -p "请输入选项(1-3): " choice
    
    case $choice in
        1)
            local config_file="$CONFIG_DIR/v2ray.json"
            local service="v2ray"
            ;;
        2)
            local config_file="$CONFIG_DIR/xray.json"
            local service="xray"
            ;;
        3)
            local config_file="$CONFIG_DIR/singbox.json"
            local service="sing-box"
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            return
            ;;
    esac
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}配置文件不存在，请先安装对应服务${PLAIN}"
        return
    fi
    
    echo -e "${BLUE}当前配置:${PLAIN}"
    jq . "$config_file"
    
    echo -e "${BLUE}请选择要修改的选项:${PLAIN}"
    echo "1) 修改端口"
    echo "2) 修改UUID/密码"
    echo "3) 修改传输协议"
    echo "4) 修改TLS设置"
    read -p "请输入选项(1-4): " opt
    
    case $opt in
        1)
            read -p "请输入新端口: " new_port
            jq ".inbounds[0].port = $new_port" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
            ;;
        2)
            if [ "$service" = "v2ray" ] || [ "$service" = "xray" ]; then
                new_uuid=$(cat /proc/sys/kernel/random/uuid)
                jq ".inbounds[0].settings.clients[0].id = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
            elif [ "$service" = "sing-box" ]; then
                new_uuid=$(cat /proc/sys/kernel/random/uuid)
                jq ".inbounds[0].users[0].uuid = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
            fi
            ;;
        3)
            echo -e "${BLUE}请选择传输协议:${PLAIN}"
            echo "1) TCP"
            echo "2) WebSocket"
            echo "3) gRPC"
            echo "4) HTTP/2"
            read -p "请输入选项(1-4): " transport
            
            case $transport in
                1)
                    new_transport="tcp"
                    ;;
                2)
                    new_transport="ws"
                    read -p "请输入WebSocket路径(如/ray): " path
                    ;;
                3)
                    new_transport="grpc"
                    read -p "请输入gRPC服务名(如grpc-service): " service_name
                    ;;
                4)
                    new_transport="h2"
                    read -p "请输入HTTP/2路径(如/h2): " path
                    ;;
                *)
                    echo -e "${RED}无效选项${PLAIN}"
                    return
                    ;;
            esac
            
            if [ "$service" = "v2ray" ] || [ "$service" = "xray" ]; then
                jq ".inbounds[0].streamSettings.network = \"$new_transport\"" "$config_file" > "$config_file.tmp"
                if [ "$new_transport" = "ws" ] || [ "$new_transport" = "h2" ]; then
                    jq ".inbounds[0].streamSettings.${new_transport}Settings.path = \"$path\"" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                elif [ "$new_transport" = "grpc" ]; then
                    jq ".inbounds[0].streamSettings.grpcSettings.serviceName = \"$service_name\"" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                else
                    mv "$config_file.tmp" "$config_file"
                fi
            elif [ "$service" = "sing-box" ]; then
                jq ".inbounds[0].transport.type = \"$new_transport\"" "$config_file" > "$config_file.tmp"
                if [ "$new_transport" = "ws" ] || [ "$new_transport" = "h2" ]; then
                    jq ".inbounds[0].transport.path = \"$path\"" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                elif [ "$new_transport" = "grpc" ]; then
                    jq ".inbounds[0].transport.service_name = \"$service_name\"" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                else
                    mv "$config_file.tmp" "$config_file"
                fi
            fi
            ;;
        4)
            echo -e "${BLUE}请选择TLS类型:${PLAIN}"
            echo "1) TLS"
            echo "2) Reality"
            echo "3) 禁用TLS"
            read -p "请输入选项(1-3): " tls_opt
            
            case $tls_opt in
                1)
                    read -p "请输入域名(SNI): " sni
                    read -p "请输入证书路径(留空使用自动证书): " cert_path
                    read -p "请输入私钥路径(留空使用自动证书): " key_path
                    
                    if [ "$service" = "v2ray" ] || [ "$service" = "xray" ]; then
                        jq ".inbounds[0].streamSettings.security = \"tls\" | .inbounds[0].streamSettings.tlsSettings.serverName = \"$sni\"" "$config_file" > "$config_file.tmp"
                        
                        if [ -n "$cert_path" ] && [ -n "$key_path" ]; then
                            jq ".inbounds[0].streamSettings.tlsSettings.certificates += [{\"certificateFile\": \"$cert_path\", \"keyFile\": \"$key_path\"}]" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                        else
                            mv "$config_file.tmp" "$config_file"
                        fi
                    elif [ "$service" = "sing-box" ]; then
                        jq ".inbounds[0].tls.enabled = true | .inbounds[0].tls.server_name = \"$sni\" | .inbounds[0].tls.reality.enabled = false" "$config_file" > "$config_file.tmp"
                        
                        if [ -n "$cert_path" ] && [ -n "$key_path" ]; then
                            jq ".inbounds[0].tls.certificate_path = \"$cert_path\" | .inbounds[0].tls.key_path = \"$key_path\"" "$config_file.tmp" > "$config_file" && rm "$config_file.tmp"
                        else
                            mv "$config_file.tmp" "$config_file"
                        fi
                    fi
                    ;;
                2)
                    read -p "请输入域名(SNI): " sni
                    read -p "请输入目标网站(如www.apple.com): " dest
                    read -p "请输入私钥(留空自动生成): " private_key
                    read -p "请输入shortId(留空自动生成): " short_id
                    
                    if [ -z "$private_key" ]; then
                        private_key=$(openssl rand -hex 32)
                    fi
                    
                    if [ -z "$short_id" ]; then
                        short_id=$(openssl rand -hex 8)
                    fi
                    
                    if [ "$service" = "v2ray" ] || [ "$service" = "xray" ]; then
                        jq ".inbounds[0].streamSettings.security = \"reality\" | .inbounds[0].streamSettings.realitySettings.serverNames = [\"$sni\"] | .inbounds[0].streamSettings.realitySettings.dest = \"$dest\" | .inbounds[0].streamSettings.realitySettings.privateKey = \"$private_key\" | .inbounds[0].streamSettings.realitySettings.shortIds = [\"$short_id\"]" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
                    elif [ "$service" = "sing-box" ]; then
                        jq ".inbounds[0].tls.enabled = true | .inbounds[0].tls.server_name = \"$sni\" | .inbounds[0].tls.reality.enabled = true | .inbounds[0].tls.reality.handshake.server = \"$dest\" | .inbounds[0].tls.reality.handshake.server_port = 443 | .inbounds[0].tls.reality.private_key = \"$private_key\" | .inbounds[0].tls.reality.short_id = [\"$short_id\"]" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
                    fi
                    ;;
                3)
                    if [ "$service" = "v2ray" ] || [ "$service" = "xray" ]; then
                        jq ".inbounds[0].streamSettings.security = \"none\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
                    elif [ "$service" = "sing-box" ]; then
                        jq ".inbounds[0].tls.enabled = false" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
                    fi
                    ;;
                *)
                    echo -e "${RED}无效选项${PLAIN}"
                    return
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            return
            ;;
    esac
    
    systemctl restart "$service"
    echo -e "${GREEN}配置修改成功，服务已重启${PLAIN}"
}

# 卸载服务
uninstall_service() {
    echo -e "${BLUE}请选择要卸载的服务:${PLAIN}"
    echo "1) V2Ray"
    echo "2) Xray"
    echo "3) sing-box"
    echo "4) 全部卸载"
    read -p "请输入选项(1-4): " choice
    
    case $choice in
        1)
            services=("v2ray")
            ;;
        2)
            services=("xray")
            ;;
        3)
            services=("sing-box")
            ;;
        4)
            services=("v2ray" "xray" "sing-box")
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            return
            ;;
    esac
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            rm -f "$SYSTEMD_DIR/$service.service"
        fi
        
        rm -f "$BIN_DIR/$service"
        rm -f "$CONFIG_DIR/$service.json"
        
        echo -e "${GREEN}$service 已卸载${PLAIN}"
    done
    
    if [ "$choice" -eq 4 ]; then
        rm -rf "$BASE_DIR"
        echo -e "${GREEN}已清理所有配置文件和数据${PLAIN}"
    fi
}

# 显示状态
show_status() {
    echo -e "${BLUE}====== 服务状态 ======${PLAIN}"
    for service in v2ray xray sing-box; do
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}$service 正在运行${PLAIN}"
        else
            echo -e "${YELLOW}$service 未运行${PLAIN}"
        fi
    done
    
    echo -e "\n${BLUE}====== 监听端口 ======${PLAIN}"
    ss -tulnp | grep -E 'v2ray|xray|sing-box'
    
    echo -e "\n${BLUE}====== 配置目录 ======${PLAIN}"
    ls -lh "$CONFIG_DIR"
    
    echo -e "\n${BLUE}====== 日志文件 ======${PLAIN}"
    ls -lh "$LOG_DIR"
}

# 主菜单
main_menu() {
    while true; do
        echo -e "${BLUE}==============================${PLAIN}"
        echo -e "${BLUE}      多协议代理管理脚本      ${PLAIN}"
        echo -e "${BLUE}==============================${PLAIN}"
        echo -e "${GREEN}1) 安装核心组件${PLAIN}"
        echo -e "${GREEN}2) 生成分享链接${PLAIN}"
        echo -e "${GREEN}3) 修改配置${PLAIN}"
        echo -e "${GREEN}4) 申请TLS证书${PLAIN}"
        echo -e "${GREEN}5) 卸载服务${PLAIN}"
        echo -e "${GREEN}6) 查看状态${PLAIN}"
        echo -e "${RED}0) 退出${PLAIN}"
        echo -e "${BLUE}==============================${PLAIN}"
        read -p "请选择操作: " option
        
        case $option in
            1)
                echo -e "${BLUE}请选择要安装的核心:${PLAIN}"
                echo "1) V2Ray"
                echo "2) Xray"
                echo "3) sing-box"
                echo "4) acme.sh (证书工具)"
                read -p "请输入选项(1-4): " core
                
                case $core in
                    1) install_v2ray ;;
                    2) install_xray ;;
                    3) install_singbox ;;
                    4) install_acme ;;
                    *) echo -e "${RED}无效选项${PLAIN}" ;;
                esac
                ;;
            2) generate_links ;;
            3) modify_config ;;
            4) issue_cert ;;
            5) uninstall_service ;;
            6) show_status ;;
            0)
                echo -e "${GREEN}再见!${PLAIN}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入${PLAIN}"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
        clear
    done
}

# 初始化
clear
check_root
detect_system
init_dirs
install_deps

# 显示欢迎信息
echo -e "${BLUE}==============================${PLAIN}"
echo -e "${BLUE}      多协议代理管理脚本      ${PLAIN}"
echo -e "${BLUE}      版本: $VERSION          ${PLAIN}"
echo -e "${BLUE}      支持系统: $OS           ${PLAIN}"
echo -e "${BLUE}==============================${PLAIN}"

# 启动主菜单
main_menu
