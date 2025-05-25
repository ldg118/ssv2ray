#!/bin/bash

set -e

title_banner() {
    clear
    echo "##########################################"
    echo "   高级多协议代理一键安装与配置工具"
    echo "   支持 Ubuntu / Debian / Alpine"
    echo "   支持 Socks5 / Shadowsocks / VMess / VLESS / Hysteria2"
    echo "##########################################"
    echo
}

pause_enter() {
    read -p "按回车继续..." a
    clear
}

protocol_list() {
    echo "请选择要安装的协议:"
    echo "1) Socks5 (用户名密码认证)"
    echo "2) Shadowsocks (高性能加密代理)"
    echo "3) VMess (V2Ray 协议, 提供 UUID 校验)"
    echo "4) VLESS (V2Ray 免加密变种, 用于未来更安全拓展)"
    echo "5) Hysteria2 (基于UDP, 性能卓越, 适合弱网络)"
    echo "6) 卸载所有已安装代理"
    echo "0) 退出"
    read -p "请选择协议 [1-6/0]: " proto
}

os_detect() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo "不支持当前操作系统" ; exit 1
    fi
}

inst_pkg() {
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update && apt-get install -y "$@"
            ;;
        alpine)
            apk update && apk add "$@"
            ;;
        *)
            echo "不支持当前系统" ; exit 1
    esac
}

input_with_default() { # $1: 问题  $2: 默认值  $3: 变量名
    read -p "$1 [$2]: " var
    eval $3="${var:-$2}"
}

confirm_info() { # $1 总览内容
    echo "$1"
    echo "确认以上信息？(y/n)"
    read -p "请输入: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消本项配置"
        pause_enter
        return 1
    fi
    return 0
}

show_client_ss() {
    IP=$(curl -s https://api.ipify.org)
    echo
    echo "------ Shadowsocks 客户端配置信息 ------"
    echo "服务器地址: $IP"
    echo "服务器端口: $ss_port"
    echo "密码:       $ss_passwd"
    echo "加密方式:   $ss_method"
    echo "链接：ss://$(echo -n "aes-256-gcm:$ss_passwd@$IP:$ss_port" | base64 -w 0)"
    echo "----------------------------------------"
}

show_client_v2ray() {
    IP=$(curl -s https://api.ipify.org)
    echo
    echo "------ $1 客户端配置信息 ------"
    echo "服务器地址: $IP"
    echo "端口:       $v2ray_port"
    echo "UUID:       $v2ray_uuid"
    if [[ "$1" == "VMess" ]]; then
        alterId=0
        proto=vmess
    else
        alterId=""
        proto=vless
    fi
    cat <<EOF
配置二维码/链接（可导入v2rayN/v2fly/UQR等）：
{
  "v": "2",
  "ps": "${IP}-${proto}",
  "add": "$IP",
  "port": "$v2ray_port",
  "id": "$v2ray_uuid",
  "aid": "$alterId",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
}
EOF
    echo "----------------------------------------"
}

show_client_hysteria2() {
    IP=$(curl -s https://api.ipify.org)
    echo
    echo "------ Hysteria2 客户端配置信息 ------"
    echo "服务器地址: $IP"
    echo "端口:       $hy_port"
    echo "密钥:       $hy_key"
    echo "obfs方式:   salamander"
    echo "url: hysteria2://$hy_key@$IP:$hy_port?obfs=salamander"
    echo "----------------------------------------"
}

show_client_socks5() {
    IP=$(curl -s https://api.ipify.org)
    echo
    echo "------ Socks5 客户端配置信息 ------"
    echo "服务器地址: $IP"
    echo "端口:       $s5_port"
    echo "用户名:     $s5_user"
    echo "密码:       $s5_pass"
    echo "----------------------------------------"
}

# 安装配置部分

config_socks5() {
    title_banner
    echo "Socks5 (Dante) 代理协议设置"
    input_with_default "请输入监听端口" 1080 s5_port
    input_with_default "请输入用户名" socksuser s5_user
    input_with_default "请输入密码" pass123 s5_pass
    cat <<INF
Socks5 代理参数总览：
端口: $s5_port
用户名: $s5_user
密码: $s5_pass
INF
    confirm_info "" || return

    inst_pkg dante-server
    useradd -M -s /bin/false $s5_user 2>/dev/null || true
    echo "$s5_user:$s5_pass" | chpasswd
    cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $s5_port
external: $(ip route get 8.8.8.8 | awk '{print $5;exit}')
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
    echo "Socks5服务已部署！"
    show_client_socks5
    pause_enter
}

config_shadowsocks() {
    title_banner
    echo "Shadowsocks-libev 代理协议设置"
    input_with_default "请输入监听端口" 8388 ss_port
    input_with_default "请输入密码" pass123 ss_passwd
    input_with_default "请输入加密方式(推荐aes-256-gcm)" aes-256-gcm ss_method
    cat <<INF
Shadowsocks 代理参数总览：
端口: $ss_port
密码: $ss_passwd
加密: $ss_method
INF
    confirm_info "" || return

    inst_pkg shadowsocks-libev
    cat > /etc/shadowsocks-libev/config.json <<EOF
{
    "server":"0.0.0.0",
    "server_port":$ss_port,
    "password":"$ss_passwd",
    "timeout":300,
    "method":"$ss_method"
}
EOF
    systemctl enable shadowsocks-libev
    systemctl restart shadowsocks-libev
    echo "Shadowsocks服务已部署！"
    show_client_ss
    pause_enter
}

config_vmess() {
    title_banner
    echo "V2Ray VMess 代理协议设置"
    input_with_default "请输入监听端口" 10080 v2ray_port
    input_with_default "请输入UUID(可留空自动生成)" "" v2ray_uuid
    if [ -z "$v2ray_uuid" ]; then
        v2ray_uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    cat <<INF
VMess 代理参数总览：
端口: $v2ray_port
UUID: $v2ray_uuid
INF
    confirm_info "" || return

    inst_pkg v2ray
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": $v2ray_port,
    "protocol": "vmess",
    "settings": {
      "clients": [{"id": "$v2ray_uuid","alterId": 0}]
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    systemctl enable v2ray
    systemctl restart v2ray
    echo "V2Ray - VMess服务已部署！"
    show_client_v2ray "VMess"
    pause_enter
}

config_vless() {
    title_banner
    echo "V2Ray VLESS 代理协议设置"
    input_with_default "请输入监听端口" 10090 v2ray_port
    input_with_default "请输入UUID(可留空自动生成)" "" v2ray_uuid
    if [ -z "$v2ray_uuid" ]; then
        v2ray_uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    cat <<INF
VLESS 代理参数总览：
端口: $v2ray_port
UUID: $v2ray_uuid
INF
    confirm_info "" || return

    inst_pkg v2ray
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": $v2ray_port,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$v2ray_uuid"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp"
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    systemctl enable v2ray
    systemctl restart v2ray
    echo "V2Ray - VLESS服务已部署！"
    show_client_v2ray "VLESS"
    pause_enter
}

config_hysteria2() {
    title_banner
    echo "Hysteria2 代理协议设置"
    input_with_default "请输入监听端口" 5678 hy_port
    input_with_default "请输入密钥（留空自动生成）" "" hy_key
    if [ -z "$hy_key" ]; then
        hy_key=$(head -c 12 /dev/urandom | base64)
    fi

    cat <<INF
Hysteria2 代理参数总览：
端口: $hy_port
密钥: $hy_key
obfs: salamander
INF
    confirm_info "" || return

    URL=$(wget -qO- https://api.github.com/repos/apernet/hysteria/releases/latest | grep browser_download_url | grep linux-amd64 | head -1 | cut -d '"' -f 4)
    wget -O /usr/local/bin/hysteria2 "$URL"
    chmod +x /usr/local/bin/hysteria2

    mkdir -p /etc/hysteria
    cat > /etc/hysteria/config.yaml <<EOF
listen: :$hy_port
obfs:
  type: salamander
  salamander:
    password: $hy_key
auth:
  type: password
  password: [$hy_key]
transport:
  udp:
    up_mbps: 100
    down_mbps: 100
EOF
    # 创建 systemd 服务
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
    echo "Hysteria2服务已部署！"
    show_client_hysteria2
    pause_enter
}

uninstall_agents() {
    title_banner
    echo "！！！ 卸载警告 ！！！"
    echo "本操作会卸载全部代理协议及配置。"
    echo "确定要卸载？请输入 yes 以确认:"
    read -p "确认卸载?(yes/no): " uc
    if [ "$uc" != "yes" ]; then
        echo "用户取消卸载"
        pause_enter
        return
    fi
    case "$OS_ID" in
        ubuntu|debian)
            systemctl stop danted ss-server v2ray hysteria2 2>/dev/null
            apt-get remove --purge -y dante-server shadowsocks-libev v2ray hysteria
            ;;
        alpine)
            rc-service danted stop 2>/dev/null
            rc-service ss-server stop 2>/dev/null
            rc-service v2ray stop 2>/dev/null
            rc-service hysteria2 stop 2>/dev/null
            apk del dante-server shadowsocks-libev v2ray hysteria2
            ;;
    esac
    rm -rf /etc/danted.conf /etc/shadowsocks-libev/config.json /etc/v2ray /etc/hysteria
    rm -f /etc/systemd/system/hysteria2.service
    systemctl daemon-reload
    echo "已全部卸载"
    pause_enter
}

main_menu() {
    os_detect
    while true; do
        title_banner
        protocol_list
        case "$proto" in
            1) config_socks5 ;;
            2) config_shadowsocks ;;
            3) config_vmess ;;
            4) config_vless ;;
            5) config_hysteria2 ;;
            6) uninstall_agents ;;
            0) echo "退出"; exit 0 ;;
            *) echo "未识别的操作"; pause_enter ;;
        esac
    done
}

main_menu
