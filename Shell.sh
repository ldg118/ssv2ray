#!/bin/bash

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
NC='\033[0m'

function print_banner() {
    echo -e "${CYN}======= 代理管理器 GPT 版 =======${NC}"
    echo -e "${BLU}支持 Ubuntu / Debian / Alpine，GitHub自动安装"
    echo ""
}

function pause() { echo ""; read -n 1 -s -r -p "按任意键返回主菜单 ..."; echo ""; }

function detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}无法检测到支持的系统环境!${NC}"
        exit 1
    fi
}

function inst_pkg() {
    case "$OS" in
        ubuntu|debian) apt-get update && apt-get install -y "$@" ;;
        alpine) apk update && apk add --no-cache "$@" ;;
        *) echo -e "${RED}不支持此操作系统.${NC}"; exit 1 ;;
    esac
}

function assure_tools() {
    for i in wget curl tar; do
        command -v $i >/dev/null 2>&1 || inst_pkg $i
    done
}

function uninstall_socks5() {
    systemctl stop danted 2>/dev/null
    case "$OS" in ubuntu|debian) apt-get remove --purge -y dante-server ;; alpine) apk del dante-server ;; esac
    rm -rf /etc/danted.conf
    echo -e "${GRN}已卸载 Socks5 (dante)${NC}"
}
function uninstall_shadowsocks() {
    systemctl stop shadowsocks-libev 2>/dev/null
    case "$OS" in ubuntu|debian) apt-get remove --purge -y shadowsocks-libev ;; alpine) apk del shadowsocks-libev ;; esac
    rm -rf /etc/shadowsocks-libev
    echo -e "${GRN}已卸载 Shadowsocks-libev${NC}"
}
function uninstall_v2ray() {
    systemctl stop v2ray 2>/dev/null
    rm -rf /etc/v2ray /usr/local/bin/v2ray /usr/local/bin/v2ctl /etc/systemd/system/v2ray.service
    systemctl daemon-reload
    echo -e "${GRN}已卸载 V2Ray${NC}"
}
function uninstall_hysteria2() {
    systemctl stop hysteria2 2>/dev/null
    rm -rf /etc/hysteria /usr/local/bin/hysteria2 /etc/systemd/system/hysteria2.service
    systemctl daemon-reload
    echo -e "${GRN}已卸载 Hysteria2${NC}"
}

function uninstall_menu() {
    clear
    print_banner
    echo -e "${YEL}单独卸载协议:${NC}"
    echo "  1) Socks5 (dante)"
    echo "  2) Shadowsocks-libev"
    echo "  3) V2Ray (vmess/vless)"
    echo "  4) Hysteria2"
    echo "  5) 返回主菜单"
    read -p "选择要卸载的协议 [1-5]: " U
    case "$U" in
        1) uninstall_socks5; pause ;;
        2) uninstall_shadowsocks; pause ;;
        3) uninstall_v2ray; pause ;;
        4) uninstall_hysteria2; pause ;;
        *) ;;
    esac
}

function uninstall_all() {
    uninstall_socks5
    uninstall_shadowsocks
    uninstall_v2ray
    uninstall_hysteria2
    echo -e "${GRN}所有协议已卸载完毕${NC}"
    pause; exit 0
}

function get_latest_github_release_url() {
    local repo="$1"
    local regex="$2"
    local url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep browser_download_url | grep -E "$regex" | head -1 | cut -d '"' -f 4)
    echo "$url"
}
function github_install_v2ray() {
    v2bin='/usr/local/bin/v2ray'
    if [ -x "$v2bin" ]; then return 0; fi
    echo -e "${YEL}下载V2Ray...${NC}"
    V2_URL=$(get_latest_github_release_url "v2fly/v2ray-core" "linux-64.zip")
    wget -O /tmp/v2ray.zip "$V2_URL" || curl -o /tmp/v2ray.zip "$V2_URL"
    unzip /tmp/v2ray.zip -d /tmp/v2rxtmp
    cp /tmp/v2rxtmp/v2ray /usr/local/bin/v2ray
    chmod +x /usr/local/bin/v2ray
    cp /tmp/v2rxtmp/v2ctl /usr/local/bin/v2ctl
    chmod +x /usr/local/bin/v2ctl || true
    mkdir -p /etc/v2ray
    rm -rf /tmp/v2rxtmp /tmp/v2ray.zip
}
function github_install_hysteria2() {
    hystbin='/usr/local/bin/hysteria2'
    if [ -x "$hystbin" ]; then return 0; fi
    echo -e "${YEL}下载Hysteria2...${NC}"
    URL=$(get_latest_github_release_url "apernet/hysteria" "linux-amd64")
    wget -O $hystbin "$URL" || curl -Lo $hystbin "$URL"
    chmod +x $hystbin
}
function get_randstr() { tr -dc A-Za-z0-9 </dev/urandom | head -c $1; }

function confirm_cfg() {
    echo -e "${CYN}--------------------------------------${NC}"
    echo -e "   ${BLU}您的配置如下: ${NC}"
    echo -e "${info}"
    echo -e "${CYN}--------------------------------------${NC}"
    echo -e "${BLU}客户端订阅/连接链接:${NC}\n$link"
    echo -e "${CYN}--------------------------------------${NC}"
    read -p "确认安装配置？(y/n): " YESNO
    [[ "$YESNO" =~ [yY] ]] || { echo -e "${RED}已放弃配置${NC}"; pause; exit 1; }
}

function conf_socks5() {
    inst_pkg dante-server
    read -p "监听端口 (默认1080): " PORT; PORT=${PORT:-1080}
    read -p "用户名 (默认 socksu): " USER; USER=${USER:-socksu}
    read -p "密码 (8位随机默认): " PASS; PASS=${PASS:-$(get_randstr 8)}
    DOMAIN=$(hostname -I | awk '{print $1}')
    info="协议：Socks5 (dante)\n端口：$PORT\n用户名：$USER\n密码：$PASS\n服务器：$DOMAIN"
    link="socks5://$USER:$PASS@$DOMAIN:$PORT"
    confirm_cfg
    useradd -M -s /bin/false $USER 2>/dev/null || true
    echo "$USER:$PASS" | chpasswd
    EXIF=$(ip route get 8.8.8.8 | awk '{print $5;exit}')
    cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $PORT
external: $EXIF
method: username
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect
    log: connect disconnect
    protocol: tcp udp
}
EOF
    systemctl enable danted
    systemctl restart danted
    echo -e "${GRN}Socks5 配置和订阅已生成${NC}"
}

function conf_shadowsocks() {
    inst_pkg shadowsocks-libev
    read -p "监听端口 (默认8388): " PORT; PORT=${PORT:-8388}
    read -p "密码 (8位随机默认): " PASS; PASS=${PASS:-$(get_randstr 8)}
    echo "加密方式可选 (默认aes-256-gcm):"
    echo "1) aes-256-gcm"
    echo "2) chacha20-ietf-poly1305"
    read -p "选择加密方式 [1-2]: " MT
    [ "$MT" == "2" ] && METHOD="chacha20-ietf-poly1305" || METHOD="aes-256-gcm"
    DOMAIN=$(hostname -I | awk '{print $1}')
    base64_method_pass=$(echo -n "$METHOD:$PASS" | base64 -w 0 2>/dev/null || echo -n "$METHOD:$PASS" | base64)
    link="ss://$base64_method_pass@$DOMAIN:$PORT"
    info="协议：Shadowsocks-libev\n端口：$PORT\n密码：$PASS\n加密方式：$METHOD\n服务器：$DOMAIN"
    confirm_cfg
    mkdir -p /etc/shadowsocks-libev
    cat > /etc/shadowsocks-libev/config.json <<EOF
{
    "server":"0.0.0.0",
    "server_port":$PORT,
    "password":"$PASS",
    "timeout":300,
    "method":"$METHOD"
}
EOF
    systemctl enable shadowsocks-libev
    systemctl restart shadowsocks-libev
    echo -e "${GRN}Shadowsocks 配置和订阅已生成${NC}"
}

function conf_v2ray_common() {
    assure_tools
    inst_pkg unzip || true
    if ! command -v v2ray >/dev/null 2>&1; then
        github_install_v2ray
    fi
    read -p "监听端口 (默认10086): " PORT; PORT=${PORT:-10086}
    UUID=$(cat /proc/sys/kernel/random/uuid)
    read -p "UUID (默认随机): " IN_UUID;  UUID=${IN_UUID:-$UUID}
    echo "传输模式:"
    echo "1) TCP"
    echo "2) WebSocket (ws)"
    read -p "网络 [1-2](默认1): " NET
    [ "$NET" == "2" ] && NETSTR="ws" || NETSTR="tcp"
    [ "$NET" == "2" ] && read -p "WebSocket路径(默认 /ray): " WSPATH; WSPATH=${WSPATH:-/ray}
    DOMAIN=$(hostname -I | awk '{print $1}')
}

function conf_v2ray_vmess() {
    conf_v2ray_common
    if [ "$NETSTR" == "ws" ]; then
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": { "clients": [{"id":"'"$UUID"'", "alterId": 0}] },
      "streamSettings": {
        "network": "ws","wsSettings": { "path": "'"$WSPATH"'" }
      }
    }'
        netinfo="network=ws; path=$WSPATH"
    else
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": { "clients": [{"id":"'"$UUID"'", "alterId": 0}] },
      "streamSettings": {"network": "tcp"}
    }'
        netinfo="network=tcp"
    fi
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [ $V2RIN ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
    link_json="{\"v\":\"2\",\"ps\":\"GPT-vmess\",\"add\":\"$DOMAIN\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"$NETSTR\",\"type\":\"none\",\"host\":\"\",\"path\":\"$WSPATH\",\"tls\":\"\"}"
    link="vmess://"$(echo -n "$link_json" | base64 -w 0 2>/dev/null || echo -n "$link_json" | base64)
    info="协议：V2Ray VMess\n端口：$PORT\nUUID：$UUID\n$netinfo\n服务器：$DOMAIN"
    confirm_cfg
    cat > /etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray
    systemctl restart v2ray
    echo -e "${GRN}V2Ray VMess 配置和订阅已生成${NC}"
}

function conf_v2ray_vless() {
    conf_v2ray_common
    if [ "$NETSTR" == "ws" ]; then
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"'"$UUID"'"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "'"$WSPATH"'" }
      }
    }'
        netinfo="network=ws; path=$WSPATH"
    else
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"'"$UUID"'"}],
        "decryption": "none"
      },
      "streamSettings": { "network": "tcp" }
    }'
        netinfo="network=tcp"
    fi
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [ $V2RIN ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
    link="vless://$UUID@$DOMAIN:$PORT?encryption=none&$netinfo#GPT-vless"
    info="协议：V2Ray VLESS\n端口：$PORT\nUUID：$UUID\n$netinfo\n服务器：$DOMAIN"
    confirm_cfg
    cat > /etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray
    systemctl restart v2ray
    echo -e "${GRN}V2Ray VLESS 配置和订阅已生成${NC}"
}

function conf_hysteria2() {
    assure_tools
    github_install_hysteria2
    read -p "监听端口(默认 5678): " PORT; PORT=${PORT:-5678}
    RANDKEY=$(get_randstr 12)
    read -p "Hysteria2 密钥(默认随机): " HKEY; HKEY=${HKEY:-$RANDKEY}
    echo "udp上限 (Mbps, 默认100): "; read UDPUP; UDPUP=${UDPUP:-100}
    echo "udp下限 (Mbps, 默认100): "; read UDPDOWN; UDPDOWN=${UDPDOWN:-100}
    DOMAIN=$(hostname -I | awk '{print $1}')
    info="协议：Hysteria2\n端口：$PORT\n密钥：$HKEY\n服务器：$DOMAIN"
    link="hy2://$HKEY@$DOMAIN:$PORT"
    confirm_cfg
    mkdir -p /etc/hysteria
    cat > /etc/hysteria/config.yaml <<EOF
listen: :$PORT
obfs:
  type: salamander
  salamander:
    password: $HKEY
auth:
  type: password
  password: [$HKEY]
transport:
  udp:
    up_mbps: $UDPUP
    down_mbps: $UDPDOWN
EOF
    cat > /etc/systemd/system/hysteria2.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria2 server -c /etc/hysteria/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable hysteria2
    systemctl restart hysteria2
    echo -e "${GRN}Hysteria2 配置和订阅已生成${NC}"
}

function main_menu() {
    clear
    print_banner
    echo -e "${YEL}请选择:${NC}"
    echo " 1) 安装 Socks5 (dante)"
    echo " 2) 安装 Shadowsocks-libev"
    echo " 3) 安装 V2Ray (vmess)"
    echo " 4) 安装 V2Ray (vless)"
    echo " 5) 安装 Hysteria2"
    echo " 6) 单独卸载某协议"
    echo " 7) 一键全卸"
    echo " 0) 退出"
    read -p "选择数字 [0-7]: " SEL
    case "$SEL" in
        1) conf_socks5; pause ;;
        2) conf_shadowsocks; pause ;;
        3) conf_v2ray_vmess; pause ;;
        4) conf_v2ray_vless; pause ;;
        5) conf_hysteria2; pause ;;
        6) uninstall_menu ;;
        7) uninstall_all ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效输入${NC}"; pause ;;
    esac
}

detect_os
while :; do main_menu; done
