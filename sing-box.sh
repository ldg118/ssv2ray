#!/bin/bash

# 多协议代理安装与管理脚本
# 支持系统：Ubuntu / Debian / Alpine / CentOS
# 支持协议：V2Ray, sing-box, Xray (支持 Reality, gRPC, WebSocket, TLS等)
# 作者：基于 ChatGPT 生成，由专业开发者完善

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
blue() { echo -e "\033[34m$1\033[0m"; }

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
  if ! command -v acme.sh &>/dev/null; then
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
    green "acme.sh 安装完成"
  else
    yellow "acme.sh 已安装，跳过..."
  fi
}

apply_cert() {
  install_acme
  read -p "请输入要申请证书的域名: " domain
  read -p "请输入邮箱地址(可选): " email
  
  if [ -z "$email" ]; then
    ~/.acme.sh/acme.sh --issue -d $domain --standalone
  else
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --register-account -m $email
  fi
  
  ~/.acme.sh/acme.sh --install-cert -d $domain \
    --key-file       $CERT_DIR/$domain.key \
    --fullchain-file $CERT_DIR/$domain.crt
    
  # 生成短链接证书路径供配置使用
  ln -sf $CERT_DIR/$domain.key $CERT_DIR/server.key
  ln -sf $CERT_DIR/$domain.crt $CERT_DIR/server.crt
  
  green "证书已生成并保存到 $CERT_DIR"
}

generate_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

# ========= 配置生成函数 =========
generate_xray_config() {
  local protocol=$1
  local port=$2
  local uuid=$3
  local domain=$4
  local use_tls=$5
  local transport=$6
  local reality_params=$7
  
  local config_file="$CONFIG_DIR/xray.json"
  
  case $protocol in
    vmess)
      inbound=$(cat <<EOF
      {
        "port": $port,
        "protocol": "vmess",
        "settings": {
          "clients": [
            {
              "id": "$uuid",
              "alterId": 0
            }
          ]
        },
        "streamSettings": {
          "network": "$transport",
          "security": "$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )",
          $(if [ "$use_tls" = "y" ]; then
            echo "\"tlsSettings\": {
              \"certificates\": [
                {
                  \"certificateFile\": \"$CERT_DIR/server.crt\",
                  \"keyFile\": \"$CERT_DIR/server.key\"
                }
              ]
            },"
          fi)
          $(if [ "$transport" = "ws" ]; then
            echo "\"wsSettings\": {
              \"path\": \"/$uuid\",
              \"headers\": {
                \"Host\": \"$domain\"
              }
            }"
          elif [ "$transport" = "grpc" ]; then
            echo "\"grpcSettings\": {
              \"serviceName\": \"$(echo $uuid | cut -d'-' -f1)\"
            }"
          else
            echo "\"tcpSettings\": {}"
          fi)
        }
      }
EOF
      )
      ;;
    vless)
      inbound=$(cat <<EOF
      {
        "port": $port,
        "protocol": "vless",
        "settings": {
          "clients": [
            {
              "id": "$uuid",
              "flow": "$( [ "$use_tls" = "y" ] && [ "$transport" = "tcp" ] && echo "xtls-rprx-vision" || echo "" )"
            }
          ],
          "decryption": "none"
        },
        "streamSettings": {
          "network": "$transport",
          "security": "$(if [ "$reality_params" ]; then echo "reality"; elif [ "$use_tls" = "y" ]; then echo "tls"; else echo "none"; fi)",
          $(if [ "$reality_params" ]; then
            IFS='|' read -ra params <<< "$reality_params"
            echo "\"realitySettings\": {
              \"show\": false,
              \"dest\": \"${params[0]}\",
              \"xver\": 0,
              \"serverNames\": [\"${params[1]}\"],
              \"privateKey\": \"${params[2]}\",
              \"shortIds\": [\"${params[3]}\"]
            },"
          elif [ "$use_tls" = "y" ]; then
            echo "\"tlsSettings\": {
              \"certificates\": [
                {
                  \"certificateFile\": \"$CERT_DIR/server.crt\",
                  \"keyFile\": \"$CERT_DIR/server.key\"
                }
              ]
            },"
          fi)
          $(if [ "$transport" = "ws" ]; then
            echo "\"wsSettings\": {
              \"path\": \"/$uuid\",
              \"headers\": {
                \"Host\": \"$domain\"
              }
            }"
          elif [ "$transport" = "grpc" ]; then
            echo "\"grpcSettings\": {
              \"serviceName\": \"$(echo $uuid | cut -d'-' -f1)\"
            }"
          else
            echo "\"tcpSettings\": {}"
          fi)
        }
      }
EOF
      )
      ;;
    trojan)
      inbound=$(cat <<EOF
      {
        "port": $port,
        "protocol": "trojan",
        "settings": {
          "clients": [
            {
              "password": "$uuid"
            }
          ]
        },
        "streamSettings": {
          "network": "$transport",
          "security": "$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )",
          $(if [ "$use_tls" = "y" ]; then
            echo "\"tlsSettings\": {
              \"certificates\": [
                {
                  \"certificateFile\": \"$CERT_DIR/server.crt\",
                  \"keyFile\": \"$CERT_DIR/server.key\"
                }
              ]
            },"
          fi)
          $(if [ "$transport" = "ws" ]; then
            echo "\"wsSettings\": {
              \"path\": \"/$uuid\",
              \"headers\": {
                \"Host\": \"$domain\"
              }
            }"
          elif [ "$transport" = "grpc" ]; then
            echo "\"grpcSettings\": {
              \"serviceName\": \"$(echo $uuid | cut -d'-' -f1)\"
            }"
          else
            echo "\"tcpSettings\": {}"
          fi)
        }
      }
EOF
      )
      ;;
    *)
      red "不支持的协议: $protocol"
      return 1
      ;;
  esac

  cat > "$config_file" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/xray-access.log",
    "error": "$LOG_DIR/xray-error.log"
  },
  "inbounds": [$inbound],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

  green "Xray 配置文件已生成: $config_file"
}

generate_reality_keys() {
  local keys=$(xray x25519)
  private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
  public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')
  short_id=$(openssl rand -hex 8)
  
  echo "$private_key|$public_key|$short_id"
}

# ========= 安装函数 =========
install_xray() {
  if [ -f "$BIN_DIR/xray" ]; then
    yellow "Xray 已安装，跳过..."
    return
  fi

  yellow "正在安装 Xray..."
  curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip
  unzip -o xray.zip -d "$BIN_DIR" && chmod +x "$BIN_DIR/xray"
  rm -f xray.zip
  
  # 检查是否安装成功
  if "$BIN_DIR/xray" -version &>/dev/null; then
    green "Xray 安装成功"
    
    # 创建 systemd 服务
    cat > "$SYSTEMD_DIR/xray.service" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$BIN_DIR/xray run -config $CONFIG_DIR/xray.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray
    green "Xray 服务已配置"
  else
    red "Xray 安装失败"
    exit 1
  fi
}

# ========= 协议配置向导 =========
protocol_wizard() {
  blue "========================"
  blue "  协议配置向导"
  blue "========================"
  
  # 选择协议
  PS3="请选择协议: "
  options=("VLESS" "VMess" "Trojan" "Shadowsocks" "退出")
  select opt in "${options[@]}"; do
    case $opt in
      "VLESS"|"VMess"|"Trojan")
        protocol=$(echo "$opt" | tr '[:upper:]' '[:lower:]')
        break
        ;;
      "Shadowsocks")
        red "Shadowsocks 暂不支持，请选择其他协议"
        ;;
      "退出")
        return
        ;;
      *) red "无效选项";;
    esac
  done

  # 获取基本配置
  read -p "请输入监听端口(默认: 443): " port
  port=${port:-443}
  
  uuid=$(generate_uuid)
  yellow "生成的UUID: $uuid"
  
  # 选择传输方式
  PS3="请选择传输方式: "
  transport_opts=("tcp" "ws" "grpc" "h2" "退出")
  select transport in "${transport_opts[@]}"; do
    case $transport in
      "tcp"|"ws"|"grpc"|"h2")
        break
        ;;
      "退出")
        return
        ;;
      *) red "无效选项";;
    esac
  done

  # TLS/Reality 配置
  use_tls="n"
  use_reality="n"
  domain=""
  
  if [ "$port" -eq 443 ] || [ "$transport" != "tcp" ]; then
    blue "建议启用TLS以提高安全性和伪装效果"
    read -p "是否启用TLS? (y/n, 默认y): " use_tls
    use_tls=${use_tls:-y}
    
    if [ "$use_tls" = "y" ]; then
      if [ "$protocol" = "vless" ]; then
        read -p "是否使用Reality代替TLS? (y/n, 默认n): " use_reality
        use_reality=${use_reality:-n}
      fi
      
      if [ "$use_reality" != "y" ]; then
        read -p "请输入域名(需已解析到本机): " domain
        if [ ! -f "$CERT_DIR/server.crt" ]; then
          yellow "未找到证书，正在申请..."
          apply_cert
        fi
      fi
    fi
  fi

  # Reality 特殊配置
  reality_params=""
  if [ "$use_reality" = "y" ]; then
    blue "正在生成Reality密钥对..."
    reality_keys=$(generate_reality_keys)
    private_key=$(echo "$reality_keys" | cut -d'|' -f1)
    public_key=$(echo "$reality_keys" | cut -d'|' -f2)
    short_id=$(echo "$reality_keys" | cut -d'|' -f3)
    
    yellow "公钥(Public Key): $public_key"
    yellow "短ID(Short ID): $short_id"
    
    read -p "请输入目标网站(如: www.apple.com): " dest_domain
    read -p "请输入服务器名称(SNI, 默认同目标网站): " server_name
    server_name=${server_name:-$dest_domain}
    
    reality_params="$dest_domain:443|$server_name|$private_key|$short_id"
  fi

  # 生成配置
  case $protocol in
    vless|vmess|trojan)
      generate_xray_config "$protocol" "$port" "$uuid" "$domain" "$use_tls" "$transport" "$reality_params"
      ;;
    *)
      red "不支持的协议"
      return
      ;;
  esac

  # 启动服务
  systemctl restart xray
  if systemctl is-active --quiet xray; then
    green "Xray 服务启动成功"
    show_client_config "$protocol" "$uuid" "$domain" "$port" "$transport" "$public_key" "$short_id"
  else
    red "Xray 服务启动失败，请检查配置"
    journalctl -u xray -n 10 --no-pager
  fi
}

show_client_config() {
  local protocol=$1
  local uuid=$2
  local domain=$3
  local port=$4
  local transport=$5
  local public_key=$6
  local short_id=$7

  blue "========================"
  blue "  客户端配置信息"
  blue "========================"
  
  case $protocol in
    vless)
      if [ "$reality_params" ]; then
        # Reality 配置
        cat <<EOF
协议: VLESS + Reality
地址: ${domain:-你的服务器IP}
端口: $port
UUID: $uuid
传输: $transport
公钥(Public Key): $public_key
短ID(Short ID): $short_id
SNI: ${server_name:-www.apple.com}
流控(Flow): xtls-rprx-vision

EOF
        # 生成分享链接
        if [ "$transport" = "tcp" ]; then
          echo "vless://$uuid@${domain:-你的服务器IP}:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${server_name}&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#VLESS+Reality"
        fi
      else
        # 普通VLESS配置
        cat <<EOF
协议: VLESS
地址: ${domain:-你的服务器IP}
端口: $port
UUID: $uuid
传输: $transport
TLS: $( [ "$use_tls" = "y" ] && echo "开启" || echo "关闭" )
流控(Flow): $( [ "$use_tls" = "y" ] && [ "$transport" = "tcp" ] && echo "xtls-rprx-vision" || echo "无" )

EOF
        # 生成分享链接
        if [ "$transport" = "tcp" ]; then
          echo "vless://$uuid@${domain:-你的服务器IP}:$port?encryption=none&flow=$( [ "$use_tls" = "y" ] && echo "xtls-rprx-vision" || echo "none" )&security=$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )&sni=$domain&fp=chrome&type=tcp&headerType=none#VLESS"
        elif [ "$transport" = "ws" ]; then
          path="/$uuid"
          echo "vless://$uuid@${domain:-你的服务器IP}:$port?encryption=none&security=$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )&sni=$domain&fp=chrome&type=ws&host=$domain&path=$(echo $path | jq -sRr @uri)#VLESS+WS"
        fi
      fi
      ;;
    vmess)
      # VMess 配置
      local alterId=0
      local security="auto"
      
      cat <<EOF
协议: VMess
地址: ${domain:-你的服务器IP}
端口: $port
UUID: $uuid
额外ID(alterId): $alterId
传输: $transport
TLS: $( [ "$use_tls" = "y" ] && echo "开启" || echo "关闭" )

EOF
      # 生成分享链接
      if [ "$transport" = "tcp" ]; then
        vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "VMess TCP",
  "add": "${domain:-你的服务器IP}",
  "port": "$port",
  "id": "$uuid",
  "aid": "$alterId",
  "scy": "$security",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": "$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )",
  "sni": "$domain",
  "alpn": ""
}
EOF
        )
        echo "vmess://$(echo "$vmess_json" | base64 -w 0)"
      elif [ "$transport" = "ws" ]; then
        path="/$uuid"
        vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "VMess WS",
  "add": "${domain:-你的服务器IP}",
  "port": "$port",
  "id": "$uuid",
  "aid": "$alterId",
  "scy": "$security",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "$path",
  "tls": "$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )",
  "sni": "$domain",
  "alpn": ""
}
EOF
        )
        echo "vmess://$(echo "$vmess_json" | base64 -w 0)"
      fi
      ;;
    trojan)
      # Trojan 配置
      cat <<EOF
协议: Trojan
地址: ${domain:-你的服务器IP}
端口: $port
密码: $uuid
传输: $transport
TLS: $( [ "$use_tls" = "y" ] && echo "开启" || echo "关闭" )

EOF
      # 生成分享链接
      if [ "$transport" = "tcp" ]; then
        echo "trojan://$uuid@${domain:-你的服务器IP}:$port?security=$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )&sni=$domain&fp=chrome&type=tcp&headerType=none#Trojan"
      elif [ "$transport" = "ws" ]; then
        path="/$uuid"
        echo "trojan://$uuid@${domain:-你的服务器IP}:$port?security=$( [ "$use_tls" = "y" ] && echo "tls" || echo "none" )&sni=$domain&fp=chrome&type=ws&host=$domain&path=$(echo $path | jq -sRr @uri)#Trojan+WS"
      fi
      ;;
  esac
  
  # 显示二维码
  if command -v qrencode &>/dev/null; then
    blue "二维码:"
    qrencode -t UTF8 "$(tail -n 1 <<< "$(show_client_config)")"
  fi
}

# ========= 主菜单 =========
main_menu() {
  while true; do
    echo "========================"
    echo "  Xray 高级管理脚本"
    echo "========================"
    echo "1) 安装/更新 Xray"
    echo "2) 协议配置向导"
    echo "3) 申请 TLS 证书"
    echo "4) 查看客户端配置"
    echo "5) 修改配置"
    echo "6) 查看运行状态"
    echo "7) 重启服务"
    echo "8) 卸载 Xray"
    echo "0) 退出"
    read -p "请选择操作: " choice

    case $choice in
      1) install_xray ;;
      2) protocol_wizard ;;
      3) apply_cert ;;
      4) show_client_config ;;
      5) modify_config ;;
      6) systemctl status xray ;;
      7) systemctl restart xray ;;
      8) uninstall_xray ;;
      0) exit 0 ;;
      *) red "无效选择，请重新输入" ;;
    esac
  done
}

# ========= 卸载函数 =========
uninstall_xray() {
  red "警告：这将完全卸载 Xray 并删除所有配置!"
  read -p "确定要卸载 Xray 吗? (y/n): " confirm
  if [ "$confirm" != "y" ]; then
    yellow "已取消卸载"
    return
  fi

  systemctl stop xray
  systemctl disable xray
  rm -f "$SYSTEMD_DIR/xray.service"
  rm -f "$BIN_DIR/xray"
  rm -rf "$CONFIG_DIR/xray.json"
  systemctl daemon-reload

  # 选择性删除证书和日志
  read -p "是否要删除证书和日志文件? (y/n): " del_files
  if [ "$del_files" = "y" ]; then
    rm -rf "$CERT_DIR" "$LOG_DIR"
  fi

  green "Xray 已成功卸载"
}

# ========= 修改配置 =========
modify_config() {
  if [ ! -f "$CONFIG_DIR/xray.json" ]; then
    red "未找到配置文件，请先安装并配置 Xray"
    return
  fi

  blue "当前配置:"
  jq . "$CONFIG_DIR/xray.json"

  echo ""
  blue "修改选项:"
  echo "1) 更改端口"
  echo "2) 更改UUID"
  echo "3) 更改传输协议"
  echo "4) 更改TLS设置"
  echo "5) 手动编辑配置"
  echo "0) 返回"

  read -p "请选择: " modify_choice

  case $modify_choice in
    1)
      read -p "请输入新端口: " new_port
      jq ".inbounds[0].port = $new_port" "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
      ;;
    2)
      new_uuid=$(generate_uuid)
      jq ".inbounds[0].settings.clients[0].id = \"$new_uuid\"" "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
      green "新的UUID: $new_uuid"
      ;;
    3)
      blue "可用传输协议:"
      echo "1) tcp"
      echo "2) ws"
      echo "3) grpc"
      echo "4) h2"
      read -p "请选择传输协议: " transport_choice
      case $transport_choice in
        1) transport="tcp" ;;
        2) transport="ws" ;;
        3) transport="grpc" ;;
        4) transport="h2" ;;
        *) red "无效选择"; return ;;
      esac
      jq ".inbounds[0].streamSettings.network = \"$transport\"" "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
      
      # 如果是ws/grpc，需要设置path/serviceName
      if [ "$transport" = "ws" ]; then
        read -p "请输入WebSocket路径(默认随机): " ws_path
        ws_path=${ws_path:-"/$(generate_uuid | cut -d'-' -f1)"}
        jq ".inbounds[0].streamSettings.wsSettings.path = \"$ws_path\"" "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
      elif [ "$transport" = "grpc" ]; then
        read -p "请输入gRPC serviceName(默认随机): " service_name
        service_name=${service_name:-"$(generate_uuid | cut -d'-' -f1)"}
        jq ".inbounds[0].streamSettings.grpcSettings.serviceName = \"$service_name\"" "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
      fi
      ;;
    4)
      current_tls=$(jq -r '.inbounds[0].streamSettings.security' "$CONFIG_DIR/xray.json")
      if [ "$current_tls" = "null" ]; then
        current_tls="none"
      fi
      
      blue "当前TLS设置: $current_tls"
      echo "1) none (无TLS)"
      echo "2) tls (普通TLS)"
      echo "3) reality (Reality协议)"
      read -p "请选择TLS类型: " tls_choice
      
      case $tls_choice in
        1)
          jq 'del(.inbounds[0].streamSettings.security) | del(.inbounds[0].streamSettings.tlsSettings)' "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
          ;;
        2)
          if [ ! -f "$CERT_DIR/server.crt" ]; then
            red "未找到证书文件，请先申请证书"
            return
          fi
          jq '.inbounds[0].streamSettings.security = "tls" | .inbounds[0].streamSettings.tlsSettings = {"certificates": [{"certificateFile": "'"$CERT_DIR/server.crt"'", "keyFile": "'"$CERT_DIR/server.key"'"}]}' "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
          ;;
        3)
          reality_keys=$(generate_reality_keys)
          private_key=$(echo "$reality_keys" | cut -d'|' -f1)
          public_key=$(echo "$reality_keys" | cut -d'|' -f2)
          short_id=$(echo "$reality_keys" | cut -d'|' -f3)
          
          yellow "公钥(Public Key): $public_key"
          yellow "短ID(Short ID): $short_id"
          
          read -p "请输入目标网站(如: www.apple.com): " dest_domain
          read -p "请输入服务器名称(SNI, 默认同目标网站): " server_name
          server_name=${server_name:-$dest_domain}
          
          jq '.inbounds[0].streamSettings.security = "reality" | .inbounds[0].streamSettings.realitySettings = {"show": false, "dest": "'"$dest_domain:443"'", "xver": 0, "serverNames": ["'"$server_name"'"], "privateKey": "'"$private_key"'", "shortIds": ["'"$short_id"'"]}' "$CONFIG_DIR/xray.json" > "$CONFIG_DIR/xray.tmp" && mv "$CONFIG_DIR/xray.tmp" "$CONFIG_DIR/xray.json"
          ;;
        *) red "无效选择"; return ;;
      esac
      ;;
    5)
      if command -v nano &>/dev/null; then
        nano "$CONFIG_DIR/xray.json"
      elif command -v vim &>/dev/null; then
        vim "$CONFIG_DIR/xray.json"
      elif command -v vi &>/dev/null; then
        vi "$CONFIG_DIR/xray.json"
      else
        red "未找到可用的文本编辑器"
      fi
      ;;
    0) return ;;
    *) red "无效选择" ;;
  esac

  systemctl restart xray
  if systemctl is-active --quiet xray; then
    green "配置修改成功，Xray 已重启"
  else
    red "Xray 启动失败，请检查配置"
    journalctl -u xray -n 10 --no-pager
  fi
}

# ========= 主程序 =========
check_root
check_system
main_menu
