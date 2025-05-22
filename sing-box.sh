#!/bin/bash

# 多协议代理安装与管理脚本
# 支持系统：Ubuntu / Debian / Alpine
# 支持协议：V2Ray, sing-box, Xray，vmess, vless, trojan, socks, shadowsocks, hysteria2
# 作者：ChatGPT 自动生成

# ========= 基础定义 =========
BASE_DIR="/etc/v2ray"
BIN_DIR="$BASE_DIR/bin"
CONFIG_DIR="$BASE_DIR/conf"
SCRIPT_DIR="$BASE_DIR/script"
CERT_DIR="$BASE_DIR/cert"
LOG_DIR="$BASE_DIR/log"
SYSTEMD_DIR="/etc/systemd/system"

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$SCRIPT_DIR" "$CERT_DIR" "$LOG_DIR"

# ========= 工具函数 =========
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

check_root() {
  [[ $EUID -ne 0 ]] && red "请以 root 权限运行本脚本" && exit 1
}

check_system() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      alpine)
        apk update && apk add bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates
        ;;
      debian|ubuntu)
        apt update && apt install -y bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates
        ;;
      centos|rhel)
        yum install -y bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates
        ;;
      *)
        red "不支持的系统：$ID"
        exit 1
        ;;
    esac
  else
    red "无法检测操作系统"
    exit 1
  fi
}

install_acme() {
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
  ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
}

apply_cert() {
  read -p "请输入要申请证书的域名: " domain
  ~/.acme.sh/acme.sh --issue -d $domain --standalone
  ~/.acme.sh/acme.sh --install-cert -d $domain \
    --key-file       $CERT_DIR/$domain.key \
    --fullchain-file $CERT_DIR/$domain.crt
  green "证书已生成并保存到 $CERT_DIR"
}

# ========= 安装函数 =========
install_xray() {
  curl -Lo xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip -o xray.zip -d "$BIN_DIR" && chmod +x "$BIN_DIR/xray"
  cat > $SYSTEMD_DIR/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$BIN_DIR/xray run -c $CONFIG_DIR/xray.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl enable xray && systemctl start xray
  green "Xray 安装完成"
}

install_singbox() {
  curl -Lo $BIN_DIR/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64 && \
  chmod +x $BIN_DIR/sing-box
  cat > $SYSTEMD_DIR/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=$BIN_DIR/sing-box run -c $CONFIG_DIR/singbox.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl enable sing-box && systemctl start sing-box
  green "Sing-box 安装完成"
}

install_v2ray() {
  curl -Lo v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
  unzip -o v2ray.zip -d "$BIN_DIR" && chmod +x "$BIN_DIR/v2ray"
  cat > $SYSTEMD_DIR/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
ExecStart=$BIN_DIR/v2ray run -config $CONFIG_DIR/v2ray.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl enable v2ray && systemctl start v2ray
  green "V2Ray 安装完成"
}

# ========= 工具功能 =========
export_link() {
  echo "导出链接："
  read -p "协议类型 (vmess/vless/trojan/ss/hysteria2): " proto
  # 省略原有代码保持不变
  # ...
}

uninstall_protocol() {
  echo "输入要卸载的服务 (xray/v2ray/sing-box): "
  read -p "> " name
  systemctl stop $name
  systemctl disable $name
  rm -f $SYSTEMD_DIR/$name.service
  rm -f $BIN_DIR/$name
  rm -rf $CONFIG_DIR/$name.json
  green "$name 卸载完成"
}

modify_config() {
  echo "当前支持修改端口和 UUID："
  read -p "请输入服务名 (v2ray/xray/sing-box): " svc
  config_file="$CONFIG_DIR/$svc.json"
  [ ! -f "$config_file" ] && red "配置文件不存在！" && return
  read -p "新端口号: " new_port
  read -p "新 UUID: " new_uuid
  jq ".inbounds[0].port = $new_port | .inbounds[0].settings.clients[0].id = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
  systemctl restart $svc
  green "$svc 配置已更新并重启"
}

show_status() {
  for svc in v2ray xray sing-box; do
    systemctl is-active --quiet $svc && green "$svc 正在运行" || yellow "$svc 未运行"
  done
}

stop_and_clean_all() {
  for svc in v2ray xray sing-box; do
    systemctl stop $svc
    systemctl disable $svc
    rm -f $SYSTEMD_DIR/$svc.service
    rm -f $BIN_DIR/$svc
    rm -f $CONFIG_DIR/$svc.json
    green "$svc 服务已停止并彻底清除"
  done
  rm -rf $CERT_DIR/* $LOG_DIR/*
  green "证书、日志和配置文件已清理"
}

main_menu() {
  while true; do
    echo "========================"
    echo "  多协议代理安装脚本"
    echo "========================"
    echo "1) 安装核心组件"
    echo "2) 导出客户端链接"
    echo "3) 卸载服务"
    echo "4) 修改配置"
    echo "5) 查看运行状态"
    echo "6) 申请 TLS 证书"
    echo "7) 停止并清理所有服务与配置"
    echo "0) 退出"
    read -p "请选择操作: " opt
    case $opt in
      1)
        echo "  1) 安装 Xray"
        echo "  2) 安装 V2Ray"
        echo "  3) 安装 Sing-box"
        echo "  4) 安装 acme.sh 证书工具"
        read -p "  请选择要安装的核心: " core
        case $core in
          1) install_xray;;
          2) install_v2ray;;
          3) install_singbox;;
          4) install_acme;;
          *) red "无效选择";;
        esac
        ;;
      2) export_link;;
      3) uninstall_protocol;;
      4) modify_config;;
      5) show_status;;
      6) apply_cert;;
      7) stop_and_clean_all;;
      0) exit 0;;
      *) red "无效选择";;
    esac
  done
}

# ========= 主程序 =========
check_root
check_system
main_menu
