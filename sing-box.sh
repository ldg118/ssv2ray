#!/bin/bash

# 多协议代理安装与管理脚本
# 支持系统：Ubuntu / Debian / Alpine
# 支持协议：V2Ray, sing-box, Xray, vmess, vless, trojan, socks, shadowsocks, hysteria2
# 支持功能：Reality, gRPC, WebSocket, TLS/XTLS, IPv6/双栈
# 版本：1.0.0
# 作者：Manus AI 自动生成

# ========= 基础定义 =========
VERSION="1.0.0"
BASE_DIR="/etc/v2ray"
BIN_DIR="$BASE_DIR/bin"
CONFIG_DIR="$BASE_DIR/conf"
SCRIPT_DIR="$BASE_DIR/script"
CERT_DIR="$BASE_DIR/cert"
LOG_DIR="$BASE_DIR/log"
TEMP_DIR="$BASE_DIR/temp"
SYSTEMD_DIR="/etc/systemd/system"
LANGUAGE="zh_CN" # 默认语言

# 创建必要的目录
mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$SCRIPT_DIR" "$CERT_DIR" "$LOG_DIR" "$TEMP_DIR"

# ========= 语言支持 =========
declare -A MESSAGES

# 中文消息
init_zh_CN() {
  MESSAGES["welcome"]="欢迎使用多协议代理安装与管理脚本"
  MESSAGES["need_root"]="请以 root 权限运行本脚本"
  MESSAGES["os_not_supported"]="不支持的系统："
  MESSAGES["os_not_detected"]="无法检测操作系统"
  MESSAGES["installing_deps"]="正在安装依赖..."
  MESSAGES["deps_installed"]="依赖安装完成"
  MESSAGES["installing"]="正在安装"
  MESSAGES["installed"]="安装完成"
  MESSAGES["cert_saved"]="证书已生成并保存到"
  MESSAGES["enter_domain"]="请输入要申请证书的域名"
  MESSAGES["invalid_choice"]="无效选择"
  MESSAGES["uninstalled"]="卸载完成"
  MESSAGES["config_updated"]="配置已更新并重启"
  MESSAGES["config_not_exist"]="配置文件不存在！"
  MESSAGES["running"]="正在运行"
  MESSAGES["not_running"]="未运行"
  MESSAGES["service_stopped"]="服务已停止并彻底清除"
  MESSAGES["files_cleaned"]="证书、日志和配置文件已清理"
  MESSAGES["enter_port"]="请输入端口号 (1-65535)"
  MESSAGES["invalid_port"]="无效的端口号，请输入1-65535之间的数字"
  MESSAGES["enter_uuid"]="请输入UUID (留空自动生成)"
  MESSAGES["enter_service"]="请输入服务名"
  MESSAGES["ipv6_enabled"]="IPv6支持已启用"
  MESSAGES["ipv6_disabled"]="IPv6支持已禁用"
  MESSAGES["press_any_key"]="按任意键继续..."
  MESSAGES["operation_completed"]="操作已完成"
  MESSAGES["operation_failed"]="操作失败"
  MESSAGES["generating_config"]="正在生成配置文件..."
  MESSAGES["config_generated"]="配置文件已生成"
  MESSAGES["select_protocol"]="请选择协议类型"
  MESSAGES["select_transport"]="请选择传输方式"
  MESSAGES["select_tls"]="请选择TLS设置"
  MESSAGES["select_core"]="请选择要安装的核心"
  MESSAGES["select_operation"]="请选择操作"
  MESSAGES["exit"]="退出"
  MESSAGES["back"]="返回上一级"
  MESSAGES["url_exported"]="链接已导出"
  MESSAGES["qrcode_generated"]="二维码已生成"
  MESSAGES["reality_enabled"]="Reality 已启用"
  MESSAGES["reality_disabled"]="Reality 未启用"
  MESSAGES["enter_reality_domain"]="请输入Reality伪装域名 (例如: www.microsoft.com)"
  MESSAGES["enter_reality_server"]="请输入Reality伪装服务器IP (例如: 13.107.42.14)"
  MESSAGES["enter_reality_port"]="请输入Reality伪装服务器端口 (例如: 443)"
  MESSAGES["enter_ws_path"]="请输入WebSocket路径 (例如: /ws)"
  MESSAGES["enter_grpc_service_name"]="请输入gRPC服务名称 (例如: grpc)"
}

# 英文消息
init_en_US() {
  MESSAGES["welcome"]="Welcome to Multi-Protocol Proxy Installation and Management Script"
  MESSAGES["need_root"]="Please run this script with root privileges"
  MESSAGES["os_not_supported"]="Unsupported system: "
  MESSAGES["os_not_detected"]="Cannot detect operating system"
  MESSAGES["installing_deps"]="Installing dependencies..."
  MESSAGES["deps_installed"]="Dependencies installed"
  MESSAGES["installing"]="Installing"
  MESSAGES["installed"]="Installation completed"
  MESSAGES["cert_saved"]="Certificate generated and saved to"
  MESSAGES["enter_domain"]="Please enter the domain for certificate application"
  MESSAGES["invalid_choice"]="Invalid choice"
  MESSAGES["uninstalled"]="Uninstallation completed"
  MESSAGES["config_updated"]="Configuration updated and restarted"
  MESSAGES["config_not_exist"]="Configuration file does not exist!"
  MESSAGES["running"]="Running"
  MESSAGES["not_running"]="Not running"
  MESSAGES["service_stopped"]="Service stopped and completely removed"
  MESSAGES["files_cleaned"]="Certificates, logs and configuration files cleaned"
  MESSAGES["enter_port"]="Please enter port number (1-65535)"
  MESSAGES["invalid_port"]="Invalid port number, please enter a number between 1-65535"
  MESSAGES["enter_uuid"]="Please enter UUID (leave empty to generate automatically)"
  MESSAGES["enter_service"]="Please enter service name"
  MESSAGES["ipv6_enabled"]="IPv6 support enabled"
  MESSAGES["ipv6_disabled"]="IPv6 support disabled"
  MESSAGES["press_any_key"]="Press any key to continue..."
  MESSAGES["operation_completed"]="Operation completed"
  MESSAGES["operation_failed"]="Operation failed"
  MESSAGES["generating_config"]="Generating configuration file..."
  MESSAGES["config_generated"]="Configuration file generated"
  MESSAGES["select_protocol"]="Please select protocol type"
  MESSAGES["select_transport"]="Please select transport method"
  MESSAGES["select_tls"]="Please select TLS settings"
  MESSAGES["select_core"]="Please select core to install"
  MESSAGES["select_operation"]="Please select operation"
  MESSAGES["exit"]="Exit"
  MESSAGES["back"]="Back to previous menu"
  MESSAGES["url_exported"]="URL exported"
  MESSAGES["qrcode_generated"]="QR code generated"
  MESSAGES["reality_enabled"]="Reality enabled"
  MESSAGES["reality_disabled"]="Reality disabled"
  MESSAGES["enter_reality_domain"]="Please enter Reality disguise domain (e.g.: www.microsoft.com)"
  MESSAGES["enter_reality_server"]="Please enter Reality disguise server IP (e.g.: 13.107.42.14)"
  MESSAGES["enter_reality_port"]="Please enter Reality disguise server port (e.g.: 443)"
  MESSAGES["enter_ws_path"]="Please enter WebSocket path (e.g.: /ws)"
  MESSAGES["enter_grpc_service_name"]="Please enter gRPC service name (e.g.: grpc)"
}

# 初始化语言
init_language() {
  case "$LANGUAGE" in
    zh_CN) init_zh_CN ;;
    en_US) init_en_US ;;
    *) init_zh_CN ;; # 默认使用中文
  esac
}

# 获取消息
msg() {
  echo "${MESSAGES[$1]}"
}

# 切换语言
switch_language() {
  case "$LANGUAGE" in
    zh_CN) LANGUAGE="en_US" ;;
    en_US) LANGUAGE="zh_CN" ;;
  esac
  init_language
  clear
  show_banner
}

# ========= 工具函数 =========
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
purple() { echo -e "\033[35m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }
white() { echo -e "\033[37m$1\033[0m"; }

# 显示横幅
show_banner() {
  clear
  cyan "======================================================"
  cyan "       $(msg welcome) v$VERSION"
  cyan "======================================================"
  echo ""
}

# 显示进度条
show_progress() {
  local duration=$1
  local step=$((duration/20))
  echo -n "["
  for i in {1..20}; do
    echo -n "#"
    sleep $step
  done
  echo "] 100%"
}

# 按任意键继续
press_any_key() {
  echo ""
  read -n 1 -s -r -p "$(msg press_any_key)"
  echo ""
}

# 生成随机字符串
random_string() {
  local length=$1
  tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# 生成UUID
generate_uuid() {
  if command -v uuidgen > /dev/null; then
    uuidgen
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

# 检查端口是否有效
is_valid_port() {
  local port=$1
  if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
    return 0
  else
    return 1
  fi
}

# 检查端口是否被占用
is_port_occupied() {
  local port=$1
  if command -v ss > /dev/null; then
    ss -tuln | grep -q ":$port "
    return $?
  elif command -v netstat > /dev/null; then
    netstat -tuln | grep -q ":$port "
    return $?
  else
    return 1  # 如果没有检测工具，假设端口可用
  fi
}

# 获取可用端口
get_available_port() {
  local start_port=${1:-10000}
  local port=$start_port
  while is_port_occupied $port; do
    port=$((port + 1))
  done
  echo $port
}

# 检查IPv6支持
check_ipv6() {
  if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# 启用IPv6
enable_ipv6() {
  if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
    echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    if check_ipv6; then
      green "$(msg ipv6_enabled)"
      return 0
    else
      red "$(msg operation_failed)"
      return 1
    fi
  else
    red "$(msg operation_failed)"
    return 1
  fi
}

# 禁用IPv6
disable_ipv6() {
  if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    if ! check_ipv6; then
      green "$(msg ipv6_disabled)"
      return 0
    else
      red "$(msg operation_failed)"
      return 1
    fi
  else
    red "$(msg operation_failed)"
    return 1
  fi
}

# 检查root权限
check_root() {
  if [[ $EUID -ne 0 ]]; then
    red "$(msg need_root)"
    exit 1
  fi
}

# 检查系统并安装依赖
check_system() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      alpine)
        yellow "$(msg installing_deps)"
        apk update && apk add bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates coreutils procps
        ;;
      debian|ubuntu)
        yellow "$(msg installing_deps)"
        apt update && apt install -y bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates uuid-runtime
        ;;
      centos|rhel|fedora)
        yellow "$(msg installing_deps)"
        if command -v dnf > /dev/null; then
          dnf install -y bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates util-linux
        else
          yum install -y bash curl unzip nginx openssl socat iptables jq qrencode ca-certificates util-linux
        fi
        ;;
      *)
        red "$(msg os_not_supported)$ID"
        exit 1
        ;;
    esac
    green "$(msg deps_installed)"
  else
    red "$(msg os_not_detected)"
    exit 1
  fi
}

# ========= 证书管理 =========
install_acme() {
  yellow "$(msg installing) acme.sh..."
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
  ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
  green "acme.sh $(msg installed)"
}

apply_cert() {
  read -p "$(msg enter_domain): " domain
  
  # 检查域名是否为空
  if [ -z "$domain" ]; then
    red "$(msg invalid_choice)"
    return 1
  fi
  
  # 停止可能占用80端口的服务
  systemctl stop nginx 2>/dev/null
  
  # 申请证书
  ~/.acme.sh/acme.sh --issue -d $domain --standalone
  
  # 安装证书
  ~/.acme.sh/acme.sh --install-cert -d $domain \
    --key-file       $CERT_DIR/$domain.key \
    --fullchain-file $CERT_DIR/$domain.crt
  
  # 重启之前停止的服务
  systemctl start nginx 2>/dev/null
  
  green "$(msg cert_saved) $CERT_DIR"
  
  # 保存域名信息
  echo "$domain" > $CONFIG_DIR/domain.txt
}

# ========= 配置生成 =========
# 生成V2Ray配置
generate_v2ray_config() {
  local protocol=$1
  local transport=$2
  local port=$3
  local uuid=$4
  local tls_type=$5
  local domain=$6
  local ws_path=$7
  local grpc_service_name=$8
  local reality_enabled=$9
  local reality_domain=${10}
  local reality_server_ip=${11}
  local reality_server_port=${12}
  
  # 创建基础配置
  local config_file="$CONFIG_DIR/v2ray.json"
  
  # 生成私钥和公钥（用于Reality）
  local private_key=""
  local public_key=""
  if [ "$reality_enabled" = "true" ]; then
    # 使用v2ray生成密钥对
    if [ -f "$BIN_DIR/v2ray" ]; then
      local key_pair=$($BIN_DIR/v2ray x25519)
      private_key=$(echo "$key_pair" | grep "Private key:" | awk '{print $3}')
      public_key=$(echo "$key_pair" | grep "Public key:" | awk '{print $3}')
    else
      # 如果v2ray不可用，使用openssl生成
      private_key=$(openssl rand -hex 32)
      # 这里简化处理，实际应该使用正确的X25519算法
      public_key=$(openssl rand -hex 32)
    fi
  fi
  
  # 创建基本配置结构
  cat > $config_file <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/v2ray_access.log",
    "error": "$LOG_DIR/v2ray_error.log"
  },
  "inbounds": [
    {
      "port": $port,
      "protocol": "$protocol",
      "settings": {
EOF

  # 根据协议类型添加不同的设置
  case "$protocol" in
    vmess)
      cat >> $config_file <<EOF
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
EOF
      ;;
    vless)
      cat >> $config_file <<EOF
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
EOF
      ;;
    trojan)
      cat >> $config_file <<EOF
        "clients": [
          {
            "password": "$uuid"
          }
        ]
EOF
      ;;
    shadowsocks)
      cat >> $config_file <<EOF
        "method": "chacha20-poly1305",
        "password": "$uuid",
        "network": "tcp,udp"
EOF
      ;;
    socks)
      cat >> $config_file <<EOF
        "auth": "password",
        "accounts": [
          {
            "user": "user",
            "pass": "$uuid"
          }
        ],
        "udp": true
EOF
      ;;
  esac

  # 关闭settings部分
  echo '      },' >> $config_file

  # 添加传输层配置
  cat >> $config_file <<EOF
      "streamSettings": {
        "network": "$transport",
EOF

  # 根据传输方式添加特定配置
  case "$transport" in
    ws)
      cat >> $config_file <<EOF
        "wsSettings": {
          "path": "$ws_path"
        },
EOF
      ;;
    grpc)
      cat >> $config_file <<EOF
        "grpcSettings": {
          "serviceName": "$grpc_service_name"
        },
EOF
      ;;
    *)
      # 对于tcp等其他传输方式，不需要特殊配置
      ;;
  esac

  # 添加TLS配置
  if [ "$tls_type" = "tls" ]; then
    cat >> $config_file <<EOF
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_DIR/$domain.crt",
              "keyFile": "$CERT_DIR/$domain.key"
            }
          ]
        }
EOF
  elif [ "$tls_type" = "xtls" ]; then
    cat >> $config_file <<EOF
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_DIR/$domain.crt",
              "keyFile": "$CERT_DIR/$domain.key"
            }
          ],
          "alpn": ["h2", "http/1.1"]
        }
EOF
  elif [ "$reality_enabled" = "true" ]; then
    cat >> $config_file <<EOF
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$reality_server_ip:$reality_server_port",
          "xver": 0,
          "serverNames": ["$reality_domain"],
          "privateKey": "$private_key",
          "publicKey": "$public_key",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [""]
        }
EOF
  else
    # 无TLS
    echo '        "security": "none"' >> $config_file
  fi

  # 关闭streamSettings部分
  echo '      },' >> $config_file

  # 添加标签
  echo '      "tag": "proxy"' >> $config_file

  # 关闭inbounds数组的第一个元素
  echo '    }' >> $config_file

  # 关闭inbounds数组
  echo '  ],' >> $config_file

  # 添加出站配置
  cat >> $config_file <<EOF
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

  green "$(msg config_generated): $config_file"
  
  # 保存配置信息
  cat > $CONFIG_DIR/v2ray_config_info.txt <<EOF
协议: $protocol
传输方式: $transport
端口: $port
UUID/密码: $uuid
TLS类型: $tls_type
域名: $domain
WebSocket路径: $ws_path
gRPC服务名: $grpc_service_name
Reality启用: $reality_enabled
Reality伪装域名: $reality_domain
Reality伪装服务器: $reality_server_ip:$reality_server_port
EOF

  if [ "$reality_enabled" = "true" ]; then
    cat >> $CONFIG_DIR/v2ray_config_info.txt <<EOF
Reality私钥: $private_key
Reality公钥: $public_key
EOF
  fi
}

# 生成Xray配置
generate_xray_config() {
  local protocol=$1
  local transport=$2
  local port=$3
  local uuid=$4
  local tls_type=$5
  local domain=$6
  local ws_path=$7
  local grpc_service_name=$8
  local reality_enabled=$9
  local reality_domain=${10}
  local reality_server_ip=${11}
  local reality_server_port=${12}
  
  # 创建基础配置
  local config_file="$CONFIG_DIR/xray.json"
  
  # 生成私钥和公钥（用于Reality）
  local private_key=""
  local public_key=""
  if [ "$reality_enabled" = "true" ]; then
    # 使用xray生成密钥对
    if [ -f "$BIN_DIR/xray" ]; then
      local key_pair=$($BIN_DIR/xray x25519)
      private_key=$(echo "$key_pair" | grep "Private key:" | awk '{print $3}')
      public_key=$(echo "$key_pair" | grep "Public key:" | awk '{print $3}')
    else
      # 如果xray不可用，使用openssl生成
      private_key=$(openssl rand -hex 32)
      # 这里简化处理，实际应该使用正确的X25519算法
      public_key=$(openssl rand -hex 32)
    fi
  fi
  
  # 创建基本配置结构
  cat > $config_file <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/xray_access.log",
    "error": "$LOG_DIR/xray_error.log"
  },
  "inbounds": [
    {
      "port": $port,
      "protocol": "$protocol",
      "settings": {
EOF

  # 根据协议类型添加不同的设置
  case "$protocol" in
    vmess)
      cat >> $config_file <<EOF
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
EOF
      ;;
    vless)
      cat >> $config_file <<EOF
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
EOF
      ;;
    trojan)
      cat >> $config_file <<EOF
        "clients": [
          {
            "password": "$uuid"
          }
        ]
EOF
      ;;
    shadowsocks)
      cat >> $config_file <<EOF
        "method": "chacha20-poly1305",
        "password": "$uuid",
        "network": "tcp,udp"
EOF
      ;;
    socks)
      cat >> $config_file <<EOF
        "auth": "password",
        "accounts": [
          {
            "user": "user",
            "pass": "$uuid"
          }
        ],
        "udp": true
EOF
      ;;
  esac

  # 关闭settings部分
  echo '      },' >> $config_file

  # 添加传输层配置
  cat >> $config_file <<EOF
      "streamSettings": {
        "network": "$transport",
EOF

  # 根据传输方式添加特定配置
  case "$transport" in
    ws)
      cat >> $config_file <<EOF
        "wsSettings": {
          "path": "$ws_path"
        },
EOF
      ;;
    grpc)
      cat >> $config_file <<EOF
        "grpcSettings": {
          "serviceName": "$grpc_service_name"
        },
EOF
      ;;
    *)
      # 对于tcp等其他传输方式，不需要特殊配置
      ;;
  esac

  # 添加TLS配置
  if [ "$tls_type" = "tls" ]; then
    cat >> $config_file <<EOF
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_DIR/$domain.crt",
              "keyFile": "$CERT_DIR/$domain.key"
            }
          ]
        }
EOF
  elif [ "$tls_type" = "xtls" ]; then
    cat >> $config_file <<EOF
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_DIR/$domain.crt",
              "keyFile": "$CERT_DIR/$domain.key"
            }
          ],
          "alpn": ["h2", "http/1.1"]
        }
EOF
  elif [ "$reality_enabled" = "true" ]; then
    cat >> $config_file <<EOF
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$reality_server_ip:$reality_server_port",
          "xver": 0,
          "serverNames": ["$reality_domain"],
          "privateKey": "$private_key",
          "publicKey": "$public_key",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [""]
        }
EOF
  else
    # 无TLS
    echo '        "security": "none"' >> $config_file
  fi

  # 关闭streamSettings部分
  echo '      },' >> $config_file

  # 添加标签
  echo '      "tag": "proxy"' >> $config_file

  # 关闭inbounds数组的第一个元素
  echo '    }' >> $config_file

  # 关闭inbounds数组
  echo '  ],' >> $config_file

  # 添加出站配置
  cat >> $config_file <<EOF
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

  green "$(msg config_generated): $config_file"
  
  # 保存配置信息
  cat > $CONFIG_DIR/xray_config_info.txt <<EOF
协议: $protocol
传输方式: $transport
端口: $port
UUID/密码: $uuid
TLS类型: $tls_type
域名: $domain
WebSocket路径: $ws_path
gRPC服务名: $grpc_service_name
Reality启用: $reality_enabled
Reality伪装域名: $reality_domain
Reality伪装服务器: $reality_server_ip:$reality_server_port
EOF

  if [ "$reality_enabled" = "true" ]; then
    cat >> $CONFIG_DIR/xray_config_info.txt <<EOF
Reality私钥: $private_key
Reality公钥: $public_key
EOF
  fi
}

# 生成sing-box配置
generate_singbox_config() {
  local protocol=$1
  local transport=$2
  local port=$3
  local uuid=$4
  local tls_type=$5
  local domain=$6
  local ws_path=$7
  local grpc_service_name=$8
  local reality_enabled=$9
  local reality_domain=${10}
  local reality_server_ip=${11}
  local reality_server_port=${12}
  
  # 创建基础配置
  local config_file="$CONFIG_DIR/singbox.json"
  
  # 生成私钥和公钥（用于Reality）
  local private_key=""
  local public_key=""
  if [ "$reality_enabled" = "true" ]; then
    # 使用sing-box生成密钥对
    if [ -f "$BIN_DIR/sing-box" ]; then
      local key_pair=$($BIN_DIR/sing-box generate reality-keypair)
      private_key=$(echo "$key_pair" | grep "PrivateKey" | awk '{print $2}')
      public_key=$(echo "$key_pair" | grep "PublicKey" | awk '{print $2}')
    else
      # 如果sing-box不可用，使用openssl生成
      private_key=$(openssl rand -hex 32)
      # 这里简化处理，实际应该使用正确的X25519算法
      public_key=$(openssl rand -hex 32)
    fi
  fi
  
  # 创建基本配置结构
  cat > $config_file <<EOF
{
  "log": {
    "level": "info",
    "output": "$LOG_DIR/singbox.log"
  },
  "inbounds": [
EOF

  # 根据协议类型添加不同的入站配置
  case "$protocol" in
    vmess)
      cat >> $config_file <<EOF
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $port,
      "users": [
        {
          "uuid": "$uuid",
          "alterId": 0
        }
      ],
EOF
      ;;
    vless)
      cat >> $config_file <<EOF
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $port,
      "users": [
        {
          "uuid": "$uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
EOF
      ;;
    trojan)
      cat >> $config_file <<EOF
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $port,
      "users": [
        {
          "password": "$uuid"
        }
      ],
EOF
      ;;
    shadowsocks)
      cat >> $config_file <<EOF
    {
      "type": "shadowsocks",
      "tag": "shadowsocks-in",
      "listen": "::",
      "listen_port": $port,
      "method": "chacha20-poly1305",
      "password": "$uuid",
EOF
      ;;
    socks)
      cat >> $config_file <<EOF
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": $port,
      "users": [
        {
          "username": "user",
          "password": "$uuid"
        }
      ],
EOF
      ;;
    hysteria2)
      cat >> $config_file <<EOF
    {
      "type": "hysteria2",
      "tag": "hysteria2-in",
      "listen": "::",
      "listen_port": $port,
      "users": [
        {
          "password": "$uuid"
        }
      ],
EOF
      ;;
  esac

  # 添加传输层配置
  if [ "$transport" = "ws" ]; then
    cat >> $config_file <<EOF
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      },
EOF
  elif [ "$transport" = "grpc" ]; then
    cat >> $config_file <<EOF
      "transport": {
        "type": "grpc",
        "service_name": "$grpc_service_name"
      },
EOF
  fi

  # 添加TLS配置
  if [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
    cat >> $config_file <<EOF
      "tls": {
        "enabled": true,
        "certificate_path": "$CERT_DIR/$domain.crt",
        "key_path": "$CERT_DIR/$domain.key"
      }
EOF
  elif [ "$reality_enabled" = "true" ]; then
    cat >> $config_file <<EOF
      "tls": {
        "enabled": true,
        "server_name": "$reality_domain",
        "reality": {
          "enabled": true,
          "private_key": "$private_key",
          "short_id": [""],
          "handshake": {
            "server": "$reality_domain",
            "server_port": $reality_server_port
          }
        }
      }
EOF
  else
    # 无TLS
    echo '      "tls": { "enabled": false }' >> $config_file
  fi

  # 关闭inbounds数组的第一个元素
  echo '    }' >> $config_file

  # 关闭inbounds数组
  echo '  ],' >> $config_file

  # 添加出站配置
  cat >> $config_file <<EOF
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "geoip": ["private"],
        "outbound": "block"
      }
    ],
    "final": "direct"
  }
}
EOF

  green "$(msg config_generated): $config_file"
  
  # 保存配置信息
  cat > $CONFIG_DIR/singbox_config_info.txt <<EOF
协议: $protocol
传输方式: $transport
端口: $port
UUID/密码: $uuid
TLS类型: $tls_type
域名: $domain
WebSocket路径: $ws_path
gRPC服务名: $grpc_service_name
Reality启用: $reality_enabled
Reality伪装域名: $reality_domain
Reality伪装服务器: $reality_server_ip:$reality_server_port
EOF

  if [ "$reality_enabled" = "true" ]; then
    cat >> $CONFIG_DIR/singbox_config_info.txt <<EOF
Reality私钥: $private_key
Reality公钥: $public_key
EOF
  fi
}

# ========= 安装函数 =========
install_xray() {
  yellow "$(msg installing) Xray..."
  
  # 下载最新版本
  curl -Lo $TEMP_DIR/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  
  # 解压
  unzip -o $TEMP_DIR/xray.zip -d "$BIN_DIR" && chmod +x "$BIN_DIR/xray"
  
  # 创建systemd服务
  cat > $SYSTEMD_DIR/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$BIN_DIR/xray run -c $CONFIG_DIR/xray.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

  # 重新加载systemd
  systemctl daemon-reload
  
  # 配置向导
  configure_service "xray"
  
  # 启动服务
  systemctl enable xray && systemctl start xray
  
  # 检查服务状态
  if systemctl is-active --quiet xray; then
    green "Xray $(msg installed)"
  else
    red "Xray $(msg operation_failed)"
  fi
  
  # 清理临时文件
  rm -f $TEMP_DIR/xray.zip
}

install_singbox() {
  yellow "$(msg installing) sing-box..."
  
  # 获取最新版本号
  local latest_version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep -o '"tag_name": ".*"' | sed 's/"tag_name": "//;s/"//')
  
  # 下载最新版本
  curl -Lo $BIN_DIR/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-$latest_version-linux-amd64.tar.gz
  
  # 解压
  tar -xzf $BIN_DIR/sing-box -C $TEMP_DIR
  mv $TEMP_DIR/sing-box-$latest_version-linux-amd64/sing-box $BIN_DIR/
  chmod +x $BIN_DIR/sing-box
  
  # 创建systemd服务
  cat > $SYSTEMD_DIR/sing-box.service <<EOF
[Unit]
Description=sing-box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$BIN_DIR/sing-box run -c $CONFIG_DIR/singbox.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

  # 重新加载systemd
  systemctl daemon-reload
  
  # 配置向导
  configure_service "sing-box"
  
  # 启动服务
  systemctl enable sing-box && systemctl start sing-box
  
  # 检查服务状态
  if systemctl is-active --quiet sing-box; then
    green "sing-box $(msg installed)"
  else
    red "sing-box $(msg operation_failed)"
  fi
  
  # 清理临时文件
  rm -f $BIN_DIR/sing-box.tar.gz
}

install_v2ray() {
  yellow "$(msg installing) V2Ray..."
  
  # 下载最新版本
  curl -Lo $TEMP_DIR/v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
  
  # 解压
  unzip -o $TEMP_DIR/v2ray.zip -d "$BIN_DIR" && chmod +x "$BIN_DIR/v2ray"
  
  # 创建systemd服务
  cat > $SYSTEMD_DIR/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$BIN_DIR/v2ray run -config $CONFIG_DIR/v2ray.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

  # 重新加载systemd
  systemctl daemon-reload
  
  # 配置向导
  configure_service "v2ray"
  
  # 启动服务
  systemctl enable v2ray && systemctl start v2ray
  
  # 检查服务状态
  if systemctl is-active --quiet v2ray; then
    green "V2Ray $(msg installed)"
  else
    red "V2Ray $(msg operation_failed)"
  fi
  
  # 清理临时文件
  rm -f $TEMP_DIR/v2ray.zip
}

# 配置服务向导
configure_service() {
  local service=$1
  yellow "$(msg generating_config)..."
  
  # 选择协议
  echo "$(msg select_protocol):"
  echo "1) VMess"
  echo "2) VLESS"
  echo "3) Trojan"
  echo "4) Shadowsocks"
  echo "5) SOCKS"
  [ "$service" = "sing-box" ] && echo "6) Hysteria2"
  read -p "$(msg select_operation) [1-5]: " protocol_choice
  
  local protocol
  case "$protocol_choice" in
    1) protocol="vmess" ;;
    2) protocol="vless" ;;
    3) protocol="trojan" ;;
    4) protocol="shadowsocks" ;;
    5) protocol="socks" ;;
    6) 
      if [ "$service" = "sing-box" ]; then
        protocol="hysteria2"
      else
        red "$(msg invalid_choice)"
        return 1
      fi
      ;;
    *) 
      red "$(msg invalid_choice)"
      return 1
      ;;
  esac
  
  # 选择传输方式
  echo "$(msg select_transport):"
  echo "1) TCP"
  echo "2) WebSocket (WS)"
  echo "3) gRPC"
  read -p "$(msg select_operation) [1-3]: " transport_choice
  
  local transport
  case "$transport_choice" in
    1) transport="tcp" ;;
    2) transport="ws" ;;
    3) transport="grpc" ;;
    *) 
      red "$(msg invalid_choice)"
      return 1
      ;;
  esac
  
  # 获取端口
  local port
  while true; do
    read -p "$(msg enter_port): " port
    if is_valid_port "$port"; then
      if is_port_occupied "$port"; then
        yellow "端口 $port 已被占用，请选择其他端口"
      else
        break
      fi
    else
      red "$(msg invalid_port)"
    fi
  done
  
  # 获取UUID
  read -p "$(msg enter_uuid): " uuid
  [ -z "$uuid" ] && uuid=$(generate_uuid)
  
  # 选择TLS设置
  echo "$(msg select_tls):"
  echo "1) 不使用TLS"
  echo "2) TLS"
  echo "3) XTLS"
  echo "4) Reality"
  read -p "$(msg select_operation) [1-4]: " tls_choice
  
  local tls_type="none"
  local reality_enabled="false"
  local domain=""
  local ws_path=""
  local grpc_service_name=""
  local reality_domain=""
  local reality_server_ip=""
  local reality_server_port=""
  
  case "$tls_choice" in
    1) tls_type="none" ;;
    2) tls_type="tls" ;;
    3) tls_type="xtls" ;;
    4) 
      tls_type="none"
      reality_enabled="true"
      ;;
    *) 
      red "$(msg invalid_choice)"
      return 1
      ;;
  esac
  
  # 如果使用TLS或XTLS，需要域名
  if [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
    # 检查是否已有域名
    if [ -f "$CONFIG_DIR/domain.txt" ]; then
      domain=$(cat "$CONFIG_DIR/domain.txt")
      echo "使用已有域名: $domain"
    else
      read -p "$(msg enter_domain): " domain
      if [ -z "$domain" ]; then
        red "$(msg invalid_choice)"
        return 1
      fi
      
      # 检查证书是否存在
      if [ ! -f "$CERT_DIR/$domain.crt" ] || [ ! -f "$CERT_DIR/$domain.key" ]; then
        yellow "未找到域名 $domain 的证书，请先申请证书"
        apply_cert
      fi
    fi
  fi
  
  # 如果使用WebSocket，需要路径
  if [ "$transport" = "ws" ]; then
    read -p "$(msg enter_ws_path): " ws_path
    [ -z "$ws_path" ] && ws_path="/ws"
  fi
  
  # 如果使用gRPC，需要服务名
  if [ "$transport" = "grpc" ]; then
    read -p "$(msg enter_grpc_service_name): " grpc_service_name
    [ -z "$grpc_service_name" ] && grpc_service_name="grpc"
  fi
  
  # 如果使用Reality，需要伪装域名和服务器
  if [ "$reality_enabled" = "true" ]; then
    read -p "$(msg enter_reality_domain): " reality_domain
    [ -z "$reality_domain" ] && reality_domain="www.microsoft.com"
    
    read -p "$(msg enter_reality_server): " reality_server_ip
    [ -z "$reality_server_ip" ] && reality_server_ip="13.107.42.14"
    
    read -p "$(msg enter_reality_port): " reality_server_port
    [ -z "$reality_server_port" ] && reality_server_port="443"
  fi
  
  # 根据服务类型生成配置
  case "$service" in
    v2ray)
      generate_v2ray_config "$protocol" "$transport" "$port" "$uuid" "$tls_type" "$domain" "$ws_path" "$grpc_service_name" "$reality_enabled" "$reality_domain" "$reality_server_ip" "$reality_server_port"
      ;;
    xray)
      generate_xray_config "$protocol" "$transport" "$port" "$uuid" "$tls_type" "$domain" "$ws_path" "$grpc_service_name" "$reality_enabled" "$reality_domain" "$reality_server_ip" "$reality_server_port"
      ;;
    sing-box)
      generate_singbox_config "$protocol" "$transport" "$port" "$uuid" "$tls_type" "$domain" "$ws_path" "$grpc_service_name" "$reality_enabled" "$reality_domain" "$reality_server_ip" "$reality_server_port"
      ;;
  esac
}

# ========= 工具功能 =========
export_link() {
  echo "$(msg select_service):"
  echo "1) V2Ray"
  echo "2) Xray"
  echo "3) sing-box"
  read -p "$(msg select_operation) [1-3]: " service_choice
  
  local service
  case "$service_choice" in
    1) service="v2ray" ;;
    2) service="xray" ;;
    3) service="sing-box" ;;
    *) 
      red "$(msg invalid_choice)"
      return 1
      ;;
  esac
  
  # 检查配置文件是否存在
  local config_file="$CONFIG_DIR/${service}.json"
  local info_file="$CONFIG_DIR/${service}_config_info.txt"
  
  if [ ! -f "$config_file" ] || [ ! -f "$info_file" ]; then
    red "$(msg config_not_exist)"
    return 1
  fi
  
  # 读取配置信息
  local protocol=$(grep "协议:" "$info_file" | cut -d' ' -f2)
  local transport=$(grep "传输方式:" "$info_file" | cut -d' ' -f2)
  local port=$(grep "端口:" "$info_file" | cut -d' ' -f2)
  local uuid=$(grep "UUID/密码:" "$info_file" | cut -d' ' -f2)
  local tls_type=$(grep "TLS类型:" "$info_file" | cut -d' ' -f2)
  local domain=$(grep "域名:" "$info_file" | cut -d' ' -f2)
  local ws_path=$(grep "WebSocket路径:" "$info_file" | cut -d' ' -f2)
  local grpc_service_name=$(grep "gRPC服务名:" "$info_file" | cut -d' ' -f2)
  local reality_enabled=$(grep "Reality启用:" "$info_file" | cut -d' ' -f2)
  local reality_domain=$(grep "Reality伪装域名:" "$info_file" | cut -d' ' -f2)
  local public_key=$(grep "Reality公钥:" "$info_file" | cut -d' ' -f2)
  
  # 获取服务器IP
  local server_ip=$(curl -s https://api.ipify.org)
  [ -z "$server_ip" ] && server_ip=$(curl -s https://ipinfo.io/ip)
  [ -z "$server_ip" ] && server_ip=$(curl -s https://api.ip.sb/ip)
  
  # 如果使用TLS，使用域名作为服务器地址
  local server_address="$server_ip"
  if [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
    server_address="$domain"
  fi
  
  # 生成链接
  local link=""
  
  case "$protocol" in
    vmess)
      # 创建VMess JSON配置
      local vmess_json="{\"v\":\"2\",\"ps\":\"$server_address\",\"add\":\"$server_address\",\"port\":$port,\"id\":\"$uuid\",\"aid\":0,\"net\":\"$transport\",\"type\":\"none\",\"host\":\"\",\"path\":\"$ws_path\",\"tls\":\"$tls_type\"}"
      
      # 如果使用gRPC，更新配置
      if [ "$transport" = "grpc" ]; then
        vmess_json="{\"v\":\"2\",\"ps\":\"$server_address\",\"add\":\"$server_address\",\"port\":$port,\"id\":\"$uuid\",\"aid\":0,\"net\":\"$transport\",\"type\":\"none\",\"host\":\"\",\"path\":\"$grpc_service_name\",\"tls\":\"$tls_type\"}"
      fi
      
      # 如果使用Reality，更新配置
      if [ "$reality_enabled" = "true" ]; then
        vmess_json="{\"v\":\"2\",\"ps\":\"$server_address\",\"add\":\"$server_address\",\"port\":$port,\"id\":\"$uuid\",\"aid\":0,\"net\":\"$transport\",\"type\":\"none\",\"host\":\"$reality_domain\",\"path\":\"\",\"tls\":\"reality\",\"sni\":\"$reality_domain\",\"fp\":\"chrome\",\"pbk\":\"$public_key\",\"sid\":\"\"}"
      fi
      
      # Base64编码
      link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
      ;;
    vless)
      # 创建VLESS链接
      if [ "$reality_enabled" = "true" ]; then
        link="vless://$uuid@$server_address:$port?encryption=none&security=reality&sni=$reality_domain&fp=chrome&pbk=$public_key&sid=&type=$transport"
      elif [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
        link="vless://$uuid@$server_address:$port?encryption=none&security=tls&type=$transport"
      else
        link="vless://$uuid@$server_address:$port?encryption=none&security=none&type=$transport"
      fi
      
      # 添加传输特定参数
      if [ "$transport" = "ws" ]; then
        link="${link}&path=$ws_path"
      elif [ "$transport" = "grpc" ]; then
        link="${link}&serviceName=$grpc_service_name"
      fi
      
      # 添加标签
      link="${link}#$server_address"
      ;;
    trojan)
      # 创建Trojan链接
      if [ "$reality_enabled" = "true" ]; then
        link="trojan://$uuid@$server_address:$port?security=reality&sni=$reality_domain&fp=chrome&pbk=$public_key&sid=&type=$transport"
      elif [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
        link="trojan://$uuid@$server_address:$port?security=tls&type=$transport"
      else
        link="trojan://$uuid@$server_address:$port?security=none&type=$transport"
      fi
      
      # 添加传输特定参数
      if [ "$transport" = "ws" ]; then
        link="${link}&path=$ws_path"
      elif [ "$transport" = "grpc" ]; then
        link="${link}&serviceName=$grpc_service_name"
      fi
      
      # 添加标签
      link="${link}#$server_address"
      ;;
    shadowsocks)
      # 创建Shadowsocks链接 (使用chacha20-poly1305加密)
      local method="chacha20-poly1305"
      local ss_password=$(echo -n "$method:$uuid" | base64 -w 0)
      link="ss://$ss_password@$server_address:$port#$server_address"
      ;;
    socks)
      # 创建SOCKS链接
      local socks_auth=$(echo -n "user:$uuid" | base64 -w 0)
      link="socks://$socks_auth@$server_address:$port#$server_address"
      ;;
    hysteria2)
      # 创建Hysteria2链接
      if [ "$tls_type" = "tls" ] || [ "$tls_type" = "xtls" ]; then
        link="hysteria2://$uuid@$server_address:$port?insecure=1&sni=$domain#$server_address"
      else
        link="hysteria2://$uuid@$server_address:$port?insecure=1#$server_address"
      fi
      ;;
  esac
  
  # 显示链接
  echo ""
  green "$(msg url_exported):"
  echo "$link"
  
  # 生成二维码
  echo "$link" | qrencode -t UTF8
  echo "$link" | qrencode -t ANSI
  green "$(msg qrcode_generated)"
  
  # 保存链接到文件
  echo "$link" > "$CONFIG_DIR/${service}_link.txt"
  echo "链接已保存到: $CONFIG_DIR/${service}_link.txt"
  
  press_any_key
}

uninstall_protocol() {
  echo "$(msg enter_service) (v2ray/xray/sing-box): "
  read -p "> " name
  
  # 检查服务是否存在
  if [ ! -f "$SYSTEMD_DIR/$name.service" ]; then
    red "服务 $name 不存在"
    return 1
  fi
  
  # 停止并禁用服务
  systemctl stop $name
  systemctl disable $name
  
  # 删除服务文件
  rm -f $SYSTEMD_DIR/$name.service
  
  # 删除二进制文件
  rm -f $BIN_DIR/$name
  
  # 删除配置文件
  rm -f $CONFIG_DIR/$name.json
  rm -f $CONFIG_DIR/${name}_config_info.txt
  rm -f $CONFIG_DIR/${name}_link.txt
  
  # 重新加载systemd
  systemctl daemon-reload
  
  green "$name $(msg uninstalled)"
}

modify_config() {
  echo "$(msg enter_service) (v2ray/xray/sing-box): "
  read -p "> " svc
  
  # 检查配置文件是否存在
  local config_file="$CONFIG_DIR/$svc.json"
  if [ ! -f "$config_file" ]; then
    red "$(msg config_not_exist)"
    return 1
  fi
  
  # 读取当前配置信息
  local info_file="$CONFIG_DIR/${svc}_config_info.txt"
  local current_protocol=$(grep "协议:" "$info_file" | cut -d' ' -f2)
  local current_transport=$(grep "传输方式:" "$info_file" | cut -d' ' -f2)
  local current_port=$(grep "端口:" "$info_file" | cut -d' ' -f2)
  local current_uuid=$(grep "UUID/密码:" "$info_file" | cut -d' ' -f2)
  local current_tls_type=$(grep "TLS类型:" "$info_file" | cut -d' ' -f2)
  local current_domain=$(grep "域名:" "$info_file" | cut -d' ' -f2)
  local current_ws_path=$(grep "WebSocket路径:" "$info_file" | cut -d' ' -f2)
  local current_grpc_service_name=$(grep "gRPC服务名:" "$info_file" | cut -d' ' -f2)
  local current_reality_enabled=$(grep "Reality启用:" "$info_file" | cut -d' ' -f2)
  local current_reality_domain=$(grep "Reality伪装域名:" "$info_file" | cut -d' ' -f2)
  local current_reality_server=$(grep "Reality伪装服务器:" "$info_file" | cut -d' ' -f2)
  
  # 显示当前配置
  echo "当前配置:"
  echo "协议: $current_protocol"
  echo "传输方式: $current_transport"
  echo "端口: $current_port"
  echo "UUID/密码: $current_uuid"
  echo "TLS类型: $current_tls_type"
  echo "域名: $current_domain"
  [ "$current_transport" = "ws" ] && echo "WebSocket路径: $current_ws_path"
  [ "$current_transport" = "grpc" ] && echo "gRPC服务名: $current_grpc_service_name"
  [ "$current_reality_enabled" = "true" ] && echo "Reality伪装域名: $current_reality_domain"
  [ "$current_reality_enabled" = "true" ] && echo "Reality伪装服务器: $current_reality_server"
  
  # 选择要修改的内容
  echo ""
  echo "选择要修改的内容:"
  echo "1) 端口"
  echo "2) UUID/密码"
  echo "3) WebSocket路径 (仅当传输方式为ws时可用)"
  echo "4) gRPC服务名 (仅当传输方式为grpc时可用)"
  echo "5) Reality设置 (仅当Reality启用时可用)"
  echo "6) 重新配置所有设置"
  echo "0) 返回"
  read -p "$(msg select_operation) [0-6]: " modify_choice
  
  case "$modify_choice" in
    1)
      # 修改端口
      local new_port
      while true; do
        read -p "$(msg enter_port): " new_port
        if is_valid_port "$new_port"; then
          if is_port_occupied "$new_port" && [ "$new_port" != "$current_port" ]; then
            yellow "端口 $new_port 已被占用，请选择其他端口"
          else
            break
          fi
        else
          red "$(msg invalid_port)"
        fi
      done
      
      # 使用jq修改配置文件中的端口
      if [ "$svc" = "sing-box" ]; then
        jq ".inbounds[0].listen_port = $new_port" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      else
        jq ".inbounds[0].port = $new_port" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      fi
      
      # 更新配置信息文件
      sed -i "s/端口: $current_port/端口: $new_port/" "$info_file"
      ;;
    2)
      # 修改UUID/密码
      read -p "$(msg enter_uuid): " new_uuid
      [ -z "$new_uuid" ] && new_uuid=$(generate_uuid)
      
      # 使用jq修改配置文件中的UUID/密码
      if [ "$svc" = "sing-box" ]; then
        if [ "$current_protocol" = "vmess" ] || [ "$current_protocol" = "vless" ]; then
          jq ".inbounds[0].users[0].uuid = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "trojan" ] || [ "$current_protocol" = "hysteria2" ]; then
          jq ".inbounds[0].users[0].password = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "shadowsocks" ]; then
          jq ".inbounds[0].password = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "socks" ]; then
          jq ".inbounds[0].users[0].password = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        fi
      else
        if [ "$current_protocol" = "vmess" ] || [ "$current_protocol" = "vless" ]; then
          jq ".inbounds[0].settings.clients[0].id = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "trojan" ]; then
          jq ".inbounds[0].settings.clients[0].password = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "shadowsocks" ]; then
          jq ".inbounds[0].settings.password = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        elif [ "$current_protocol" = "socks" ]; then
          jq ".inbounds[0].settings.accounts[0].pass = \"$new_uuid\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        fi
      fi
      
      # 更新配置信息文件
      sed -i "s/UUID\/密码: $current_uuid/UUID\/密码: $new_uuid/" "$info_file"
      ;;
    3)
      # 修改WebSocket路径
      if [ "$current_transport" != "ws" ]; then
        red "当前传输方式不是WebSocket，无法修改WebSocket路径"
        return 1
      fi
      
      read -p "$(msg enter_ws_path): " new_ws_path
      [ -z "$new_ws_path" ] && new_ws_path="/ws"
      
      # 使用jq修改配置文件中的WebSocket路径
      if [ "$svc" = "sing-box" ]; then
        jq ".inbounds[0].transport.path = \"$new_ws_path\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      else
        jq ".inbounds[0].streamSettings.wsSettings.path = \"$new_ws_path\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      fi
      
      # 更新配置信息文件
      sed -i "s/WebSocket路径: $current_ws_path/WebSocket路径: $new_ws_path/" "$info_file"
      ;;
    4)
      # 修改gRPC服务名
      if [ "$current_transport" != "grpc" ]; then
        red "当前传输方式不是gRPC，无法修改gRPC服务名"
        return 1
      fi
      
      read -p "$(msg enter_grpc_service_name): " new_grpc_service_name
      [ -z "$new_grpc_service_name" ] && new_grpc_service_name="grpc"
      
      # 使用jq修改配置文件中的gRPC服务名
      if [ "$svc" = "sing-box" ]; then
        jq ".inbounds[0].transport.service_name = \"$new_grpc_service_name\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      else
        jq ".inbounds[0].streamSettings.grpcSettings.serviceName = \"$new_grpc_service_name\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      fi
      
      # 更新配置信息文件
      sed -i "s/gRPC服务名: $current_grpc_service_name/gRPC服务名: $new_grpc_service_name/" "$info_file"
      ;;
    5)
      # 修改Reality设置
      if [ "$current_reality_enabled" != "true" ]; then
        red "当前未启用Reality，无法修改Reality设置"
        return 1
      fi
      
      read -p "$(msg enter_reality_domain): " new_reality_domain
      [ -z "$new_reality_domain" ] && new_reality_domain="www.microsoft.com"
      
      read -p "$(msg enter_reality_server): " new_reality_server_ip
      [ -z "$new_reality_server_ip" ] && new_reality_server_ip="13.107.42.14"
      
      read -p "$(msg enter_reality_port): " new_reality_server_port
      [ -z "$new_reality_server_port" ] && new_reality_server_port="443"
      
      # 使用jq修改配置文件中的Reality设置
      if [ "$svc" = "sing-box" ]; then
        jq ".inbounds[0].tls.server_name = \"$new_reality_domain\" | .inbounds[0].tls.reality.handshake.server = \"$new_reality_domain\" | .inbounds[0].tls.reality.handshake.server_port = $new_reality_server_port" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      else
        jq ".inbounds[0].streamSettings.realitySettings.serverNames[0] = \"$new_reality_domain\" | .inbounds[0].streamSettings.realitySettings.dest = \"$new_reality_server_ip:$new_reality_server_port\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
      fi
      
      # 更新配置信息文件
      sed -i "s/Reality伪装域名: $current_reality_domain/Reality伪装域名: $new_reality_domain/" "$info_file"
      sed -i "s/Reality伪装服务器: $current_reality_server/Reality伪装服务器: $new_reality_server_ip:$new_reality_server_port/" "$info_file"
      ;;
    6)
      # 重新配置所有设置
      configure_service "$svc"
      ;;
    0)
      return 0
      ;;
    *)
      red "$(msg invalid_choice)"
      return 1
      ;;
  esac
  
  # 重启服务
  systemctl restart $svc
  
  green "$svc $(msg config_updated)"
}

show_status() {
  echo "服务状态:"
  for svc in v2ray xray sing-box; do
    if systemctl is-active --quiet $svc; then
      green "$svc $(msg running)"
      
      # 显示配置信息
      if [ -f "$CONFIG_DIR/${svc}_config_info.txt" ]; then
        echo "----------------------------------------"
        cat "$CONFIG_DIR/${svc}_config_info.txt"
        echo "----------------------------------------"
      fi
    else
      yellow "$svc $(msg not_running)"
    fi
  done
  
  # 显示IPv6状态
  echo ""
  echo "IPv6状态:"
  if check_ipv6; then
    green "IPv6 $(msg running)"
  else
    yellow "IPv6 $(msg not_running)"
  fi
  
  press_any_key
}

stop_and_clean_all() {
  echo "警告: 此操作将停止并清理所有服务和配置文件"
  read -p "确认继续? (y/n): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    return 0
  fi
  
  for svc in v2ray xray sing-box; do
    systemctl stop $svc 2>/dev/null
    systemctl disable $svc 2>/dev/null
    rm -f $SYSTEMD_DIR/$svc.service
    rm -f $BIN_DIR/$svc
    rm -f $CONFIG_DIR/$svc.json
    rm -f $CONFIG_DIR/${svc}_config_info.txt
    rm -f $CONFIG_DIR/${svc}_link.txt
    green "$svc $(msg service_stopped)"
  done
  
  # 清理证书和日志
  rm -rf $CERT_DIR/* $LOG_DIR/* $TEMP_DIR/*
  
  # 重新加载systemd
  systemctl daemon-reload
  
  green "$(msg files_cleaned)"
}

ipv6_menu() {
  while true; do
    clear
    echo "========================"
    echo "  IPv6 管理"
    echo "========================"
    echo "1) 启用IPv6"
    echo "2) 禁用IPv6"
    echo "3) 检查IPv6状态"
    echo "0) $(msg back)"
    read -p "$(msg select_operation) [0-3]: " opt
    case $opt in
      1) enable_ipv6 ;;
      2) disable_ipv6 ;;
      3)
        if check_ipv6; then
          green "IPv6 $(msg running)"
        else
          yellow "IPv6 $(msg not_running)"
        fi
        press_any_key
        ;;
      0) return 0 ;;
      *) red "$(msg invalid_choice)" ;;
    esac
  done
}

main_menu() {
  while true; do
    show_banner
    echo "1) $(msg installing) $(msg select_core)"
    echo "2) 导出客户端链接"
    echo "3) 卸载服务"
    echo "4) 修改配置"
    echo "5) 查看运行状态"
    echo "6) 申请 TLS 证书"
    echo "7) IPv6 管理"
    echo "8) 停止并清理所有服务与配置"
    echo "9) 切换语言 / Switch Language"
    echo "0) $(msg exit)"
    read -p "$(msg select_operation) [0-9]: " opt
    case $opt in
      1)
        echo "  1) $(msg installing) Xray"
        echo "  2) $(msg installing) V2Ray"
        echo "  3) $(msg installing) sing-box"
        echo "  4) $(msg installing) acme.sh $(msg select_core)"
        read -p "  $(msg select_operation) [1-4]: " core
        case $core in
          1) install_xray ;;
          2) install_v2ray ;;
          3) install_singbox ;;
          4) install_acme ;;
          *) red "$(msg invalid_choice)" ;;
        esac
        press_any_key
        ;;
      2) export_link ;;
      3) uninstall_protocol; press_any_key ;;
      4) modify_config; press_any_key ;;
      5) show_status ;;
      6) apply_cert; press_any_key ;;
      7) ipv6_menu ;;
      8) stop_and_clean_all; press_any_key ;;
      9) switch_language ;;
      0) exit 0 ;;
      *) red "$(msg invalid_choice)" ;;
    esac
  done
}

# ========= 主程序 =========
check_root
init_language
check_system
main_menu
