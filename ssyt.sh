#!/bin/bash

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
NC='\033[0m'

function print_banner() {
    echo -e "${CYN}========== 多协议代理安装器 - GitHub增强版 ==========${NC}"
    echo -e "${BLU} 兼容 Ubuntu / Debian / Alpine          by GPT-4"
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
    for i in wget curl tar gzip; do
        command -v $i >/dev/null 2>&1 || inst_pkg $i
    done
}

function uninstall_all() {
    echo -e "${YEL}正在卸载......${NC}"
    case "$OS" in
        ubuntu|debian)
            systemctl stop danted ss-server v2ray hysteria2 2>/dev/null
            apt-get remove --purge -y dante-server shadowsocks-libev
            ;;
        alpine)
            rc-service danted stop 2>/dev/null
            rc-service ss-server stop 2>/dev/null
            apk del dante-server shadowsocks-libev
            ;;
    esac
    systemctl stop v2ray hysteria2 2>/dev/null
    rm -rf /etc/danted.conf /etc/shadowsocks-libev/config.json /etc/v2ray /etc/hysteria
    rm -f /usr/local/bin/v2ray /usr/local/bin/v2ctl /usr/local/bin/hysteria2
    rm -f /etc/systemd/system/v2ray.service /etc/systemd/system/hysteria2.service
    systemctl daemon-reload
    echo -e "${GRN}卸载完毕${NC}"
    pause; exit 0
}

function info_downloaded() {
    echo -e "${GRN}已从GitHub下载安装: ${BLU}${1}${NC}"
}

function get_latest_github_release_url() {
    local repo="$1"
    local regex="$2"
    local url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" \
        | grep browser_download_url \
        | grep -E "$regex" \
        | head -1 \
        | cut -d '"' -f 4)
    echo "$url"
}

function github_install_v2ray() {
    v2bin='/usr/local/bin/v2ray'
    if [ -x "$v2bin" ]; then return 0; fi
    echo -e "${YEL}正在从GitHub下载安装V2Ray...${NC}"
    V2_URL=$(get_latest_github_release_url "v2fly/v2ray-core" "linux-64.zip")
    [ -z "$V2_URL" ] && echo -e "${RED}获取V2Ray最新版本失败!${NC}" && exit 1
    wget -O /tmp/v2ray.zip "$V2_URL" || curl -o /tmp/v2ray.zip "$V2_URL"
    unzip /tmp/v2ray.zip -d /tmp/v2rxtmp
    cp /tmp/v2rxtmp/v2ray /usr/local/bin/v2ray
    chmod +x /usr/local/bin/v2ray
    cp /tmp/v2rxtmp/v2ctl /usr/local/bin/v2ctl
    chmod +x /usr/local/bin/v2ctl || true
    mkdir -p /etc/v2ray
    rm -rf /tmp/v2rxtmp /tmp/v2ray.zip
    info_downloaded "/usr/local/bin/v2ray"
}

function github_install_hysteria2() {
    hystbin='/usr/local/bin/hysteria2'
    if [ -x "$hystbin" ]; then return 0; fi
    echo -e "${YEL}正在从GitHub下载安装Hysteria2...${NC}"
    URL=$(get_latest_github_release_url "apernet/hysteria" "linux-amd64")
    [ -z "$URL" ] && echo -e "${RED}获取Hysteria2最新版本失败!${NC}" && exit 1
    wget -O $hystbin "$URL" || curl -Lo $hystbin "$URL"
    chmod +x $hystbin
    info_downloaded $hystbin
}

function select_protocol() {
    clear
    print_banner
    echo -e "${YEL}请选择要安装和配置的协议:${NC}"
    echo "  1) Socks5 (dante)"
    echo "  2) Shadowsocks-libev"
    echo "  3) V2Ray (vmess)"
    echo "  4) V2Ray (vless)"
    echo "  5) Hysteria2"
    echo "  6) 卸载所有协议并退出"
    read -p "选择数字 [1-6]: " SEL
    if [[ $SEL == "6" ]]; then uninstall_all; fi
}

function confirm_cfg() {
    echo -e "${CYN}--------------------------------------${NC}"
    echo -e "   ${BLU}您的配置如下: ${NC}"
    echo -e "${info}"
    echo -e "${CYN}--------------------------------------${NC}"
    read -p "确认安装以上配置？(y/n): " YESNO
    case "$YESNO" in y|Y) ;; *) echo -e "${RED}放弃安装${NC}"; pause; exit 1 ;; esac
}

function get_randstr() { tr -dc A-Za-z0-9 </dev/urandom | head -c $1; }

function conf_socks5() {
    inst_pkg dante-server
    echo -e "${YEL}Socks5 代理配置${NC}"
    read -p "监听端口 (默认1080): " PORT; PORT=${PORT:-1080}
    read -p "用户名 (默认 socksu): " USER; USER=${USER:-socksu}
    read -p "密码 (默认 8位随机): " PASS; PASS=${PASS:-$(get_randstr 8)}
    EXIF=$(ip route get 8.8.8.8 | awk '{print $5;exit}')
    info="协议：Socks5 (dante)\n端口：$PORT\n用户名：$USER\n密码：$PASS"
    confirm_cfg
    useradd -M -s /bin/false $USER 2>/dev/null || true
    echo "$USER:$PASS" | chpasswd
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
    echo -e "${GRN}Socks5 配置完毕${NC}"
}

function conf_shadowsocks() {
    inst_pkg shadowsocks-libev
    echo -e "${YEL}Shadowsocks-libev 配置${NC}"
    read -p "监听端口 (默认8388): " PORT; PORT=${PORT:-8388}
    read -p "密码 (默认 8位随机): " PASS; PASS=${PASS:-$(get_randstr 8)}
    echo "加密方式可选 (默认为aes-256-gcm):"
    echo "1) aes-256-gcm"
    echo "2) chacha20-ietf-poly1305"
    read -p "选择加密方式 [1-2]: " MT
    [ "$MT" == "2" ] && METHOD="chacha20-ietf-poly1305" || METHOD="aes-256-gcm"
    info="协议：Shadowsocks-libev\n端口：$PORT\n密码：$PASS\n加密方式：$METHOD"
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
    echo -e "${GRN}Shadowsocks 配置完毕${NC}"
}

function conf_v2ray_common() {
    echo -e "${YEL}V2Ray 配置${NC}"
    assure_tools
    inst_pkg unzip || true
    if ! command -v v2ray >/dev/null 2>&1; then
        github_install_v2ray
    fi

    read -p "监听端口 (默认 10086): " PORT; PORT=${PORT:-10086}
    UUID=$(cat /proc/sys/kernel/random/uuid)
    read -p "UUID (默认随机): " IN_UUID;  UUID=${IN_UUID:-$UUID}
    echo "传输模式可选："
    echo "1) TCP"
    echo "2) WebSocket (ws)"
    read -p "选择网络类型 [1-2] (默认1): " NET
    [ "$NET" == "2" ] && NETSTR="ws" || NETSTR="tcp"
    [ "$NET" == "2" ] && read -p "WebSocket 路径(默认 /ray): " WSPATH; WSPATH=${WSPATH:-/ray}
}

function conf_v2ray_vmess() {
    conf_v2ray_common
    if [ "$NETSTR" == "ws" ]; then
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [{"id":"'"$UUID"'", "alterId": 0}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "'"$WSPATH"'"
        }
      }
    }'
        netinfo="网络：WebSocket\n路径：$WSPATH"
    else
        V2RIN='{
      "port": '"$PORT"',
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [{"id":"'"$UUID"'", "alterId": 0}]
      },
      "streamSettings": {"network": "tcp"}
    }'
        netinfo="网络：TCP"
    fi
    info="协议：V2Ray VMess\n端口：$PORT\nUUID：$UUID\n${netinfo}"
    confirm_cfg
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [ $V2RIN ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
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
    echo -e "${GRN}V2Ray VMess 配置完毕${NC}"
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
        netinfo="网络：WebSocket\n路径：$WSPATH"
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
        netinfo="网络：TCP"
    fi
    info="协议：V2Ray VLESS\n端口：$PORT\nUUID：$UUID\n${netinfo}"
    confirm_cfg
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [ $V2RIN ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
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
    echo -e "${GRN}V2Ray VLESS 配置完毕${NC}"
}

function conf_hysteria2() {
    echo -e "${YEL}Hysteria2 配置${NC}"
    assure_tools
    github_install_hysteria2
    read -p "监听端口 (默认 5678): " PORT; PORT=${PORT:-5678}
    RANDKEY=$(get_randstr 12)
    read -p "Hysteria2 密钥(默认随机): " HKEY; HKEY=${HKEY:-$RANDKEY}
    echo "udp上限 (Mbps, 默认100): "; read UDPUP; UDPUP=${UDPUP:-100}
    echo "udp下限 (Mbps, 默认100): "; read UDPDOWN; UDPDOWN=${UDPDOWN:-100}
    info="协议：Hysteria2\n端口：$PORT\n密钥：$HKEY\n上/下行：$UDPUP/$UDPDOWN Mbps"
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
    echo -e "${GRN}Hysteria2 配置完毕${NC}"
}

# 主流程
detect_os
while :; do
    select_protocol
    case "$SEL" in
        1) conf_socks5; pause ;;
        2) conf_shadowsocks; pause ;;
        3) conf_v2ray_vmess; pause ;;
        4) conf_v2ray_vless; pause ;;
        5) conf_hysteria2; pause ;;
        *) echo -e "${RED}无效输入${NC}"; pause ;;
    esac
done
