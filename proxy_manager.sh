#!/bin/bash

# ============================================
# 代理协议一键管理脚本 v6.0
# 整合了 https://github.com/ldg118/Proxy 项目
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 全局配置
LOG_FILE="/var/log/proxy_manager.log"
CONFIG_DIR="/etc/proxy_manager"
BACKUP_DIR="$CONFIG_DIR/backups"
CONFIG_FILE="$CONFIG_DIR/configs.json"
TEMP_DIR="/tmp/proxy_manager"
SUPPORTED_OS=("ubuntu" "debian" "centos" "alpine")

# CDN镜像源配置
MIRROR_SITES=(
    "https://cdn.jsdelivr.net/gh"
    "https://raw.githubusercontent.com"
    "https://ghproxy.com/https://github.com"
)

# Proxy项目仓库地址
PROXY_REPO="Slotheve/Proxy"
PROXY_BRANCH="main"

# 协议脚本列表
PROTOCOL_SCRIPTS=(
    "ss.sh:Shadowsocks"
    "meta.sh:Clash Meta"
    "hysteria.sh:Hysteria"
    "tuic.sh:TUIC"
    "xray-none.sh:Xray(TCP)"
    "singbox-reality.sh:Sing-Box(Reality)"
    "singbox-shadowtls.sh:Sing-Box(ShadowTLS)"
    "singbox-ws.sh:Sing-Box(WebSocket)"
)

# 初始化日志系统
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "初始化日志系统完成" "$GREEN"
}

# 带颜色和时间的日志记录
log() {
    local msg="$1"
    local color="${2:-$NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${color}${msg}${NC}" | tee -a "$LOG_FILE"
}

# 安全下载函数（多源重试）
safe_download() {
    local url_path="$1"
    local output="$2"
    local max_retries=3
    local timeout=20
    local success=0

    for mirror in "${MIRROR_SITES[@]}"; do
        local retry_count=0
        while [ $retry_count -lt $max_retries ]; do
            log "尝试从 $mirror/$url_path 下载 (重试 $retry_count/$max_retries)" "$YELLOW"
            if wget --timeout=$timeout --tries=1 -O "$output" "$mirror/$url_path" 2>> "$LOG_FILE"; then
                success=1
                break 2
            fi
            retry_count=$((retry_count+1))
            sleep 2
        done
    done

    if [ $success -eq 0 ]; then
        log "所有镜像源下载失败: $url_path" "$RED"
        return 1
    fi
    return 0
}

# 绘制界面元素
draw_line() {
    echo -e "${PURPLE}============================================${NC}"
}

draw_title() {
    clear
    draw_line
    echo -e "${PURPLE}         代理协议一键管理脚本 v6.0         ${NC}"
    echo -e "${PURPLE}============================================${NC}"
}

# 系统检查
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "错误: 此脚本需要root权限运行!" "$RED"
        echo -e "${YELLOW}请使用 'sudo bash $0' 或切换到root用户执行${NC}"
        exit 1
    fi
}

check_os() {
    local os_id
    if [ -f /etc/os-release ]; then
        os_id=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
    elif [ -f /etc/centos-release ]; then
        os_id="centos"
    elif [ -f /etc/alpine-release ]; then
        os_id="alpine"
    else
        os_id="unknown"
    fi

    if ! printf '%s\n' "${SUPPORTED_OS[@]}" | grep -q "^$os_id$"; then
        log "错误: 不支持的操作系统! 检测到: $os_id" "$RED"
        exit 1
    fi
    echo "$os_id"
}

# 依赖管理
install_dependencies() {
    local os=$1
    log "正在安装系统依赖..." "$GREEN"

    case "$os" in
        ubuntu|debian)
            apt-get update >/dev/null 2>&1 || log "更新软件包索引失败" "$YELLOW"
            apt-get install -y curl wget jq qrencode openssl >/dev/null 2>&1 || {
                log "部分依赖安装失败，尝试补救..." "$YELLOW"
                apt-get install -y curl wget >/dev/null 2>&1 || {
                    log "关键依赖(curl/wget)安装失败!" "$RED"
                    return 1
                }
            }
            ;;
        centos)
            yum install -y epel-release >/dev/null 2>&1 || yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm >/dev/null 2>&1
            yum install -y curl wget jq qrencode openssl >/dev/null 2>&1 || {
                log "部分依赖安装失败，尝试补救..." "$YELLOW"
                yum install -y curl wget >/dev/null 2>&1 || {
                    log "关键依赖(curl/wget)安装失败!" "$RED"
                    return 1
                }
            }
            ;;
        alpine)
            apk add --no-cache curl wget jq qrencode openssl bash >/dev/null 2>&1 || {
                log "部分依赖安装失败，尝试补救..." "$YELLOW"
                apk add --no-cache curl wget bash >/dev/null 2>&1 || {
                    log "关键依赖(curl/wget/bash)安装失败!" "$RED"
                    return 1
                }
            }
            ;;
    esac

    # 验证关键命令
    for cmd in curl wget bash; do
        if ! command -v "$cmd" &>/dev/null; then
            log "关键命令 $cmd 未安装!" "$RED"
            return 1
        fi
    done

    log "系统依赖安装完成" "$GREEN"
    return 0
}

# 配置管理
init_config() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$TEMP_DIR"
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
    fi
}

save_config() {
    local protocol="$1"
    local config="$2"
    
    if ! jq --arg proto "$protocol" --argjson conf "$config" \
       '. + {($proto): $conf}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"; then
        log "保存配置失败!" "$RED"
        return 1
    fi
    
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

get_config() {
    local protocol="$1"
    if [ -s "$CONFIG_FILE" ]; then
        jq -r --arg proto "$protocol" '.[$proto] // empty' "$CONFIG_FILE"
    else
        echo "{}"
    fi
}

# 用户输入处理
get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    read -p "$prompt" input
    echo "${input:-$default}"
}

# 下载协议脚本
download_protocol_script() {
    local script_name="$1"
    local output_path="$TEMP_DIR/$script_name"
    
    mkdir -p "$TEMP_DIR"
    
    if ! safe_download "$PROXY_REPO/$PROXY_BRANCH/$script_name" "$output_path"; then
        log "下载协议脚本 $script_name 失败!" "$RED"
        return 1
    fi
    
    chmod +x "$output_path"
    log "协议脚本 $script_name 下载成功" "$GREEN"
    echo "$output_path"
}

# 执行协议脚本
run_protocol_script() {
    local script_name="$1"
    local script_path
    
    script_path=$(download_protocol_script "$script_name")
    if [ $? -ne 0 ] || [ -z "$script_path" ]; then
        log "准备执行协议脚本失败!" "$RED"
        return 1
    fi
    
    log "正在执行协议脚本: $script_name" "$CYAN"
    bash "$script_path"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log "协议脚本 $script_name 执行成功" "$GREEN"
        # 尝试从协议脚本的输出中提取配置信息并保存
        extract_and_save_config "$script_name" "$script_path"
    else
        log "协议脚本 $script_name 执行失败，退出码: $exit_code" "$RED"
    fi
    
    return $exit_code
}

# 从协议脚本输出中提取配置信息并保存
extract_and_save_config() {
    local script_name="$1"
    local script_path="$2"
    local protocol_name="${script_name%.sh}"
    
    # 这里可以根据不同协议脚本的输出格式，编写相应的提取逻辑
    # 由于每个协议脚本的输出格式可能不同，这里只是一个示例框架
    
    log "尝试提取 $protocol_name 配置信息" "$YELLOW"
    
    # 示例：提取IP、端口等信息
    local public_ip=$(curl -s https://api.ipify.org || echo "127.0.0.1")
    
    # 根据不同协议脚本，可能需要不同的提取逻辑
    case "$protocol_name" in
        ss)
            # 尝试从ss配置文件中提取信息
            if [ -f "/etc/shadowsocks-libev/config.json" ]; then
                local port=$(jq -r '.server_port' /etc/shadowsocks-libev/config.json 2>/dev/null || echo "")
                local password=$(jq -r '.password' /etc/shadowsocks-libev/config.json 2>/dev/null || echo "")
                local method=$(jq -r '.method' /etc/shadowsocks-libev/config.json 2>/dev/null || echo "")
                
                if [ -n "$port" ] && [ -n "$password" ] && [ -n "$method" ]; then
                    local config_json=$(jq -n \
                        --arg ip "$public_ip" \
                        --arg port "$port" \
                        --arg pass "$password" \
                        --arg method "$method" \
                        --arg remark "SS-Auto" \
                        '{ip: $ip, port: $port, password: $pass, method: $method, remark: $remark, need_tls: false}')
                    
                    save_config "shadowsocks" "$config_json"
                    log "Shadowsocks 配置信息已保存" "$GREEN"
                fi
            fi
            ;;
        # 其他协议的提取逻辑可以类似实现
        *)
            log "暂不支持自动提取 $protocol_name 配置信息" "$YELLOW"
            ;;
    esac
}

# 显示配置信息
show_configs() {
    draw_title
    echo -e "${CYAN}已保存的配置信息:${NC}"
    draw_line
    
    if [ ! -s "$CONFIG_FILE" ] || [ "$(jq 'length' "$CONFIG_FILE")" -eq 0 ]; then
        echo -e "${YELLOW}暂无保存的配置信息${NC}"
        return
    fi
    
    local protocols
    protocols=$(jq -r 'keys[]' "$CONFIG_FILE")
    
    for protocol in $protocols; do
        echo -e "${GREEN}[$protocol]${NC}"
        
        local config
        config=$(jq -r --arg proto "$protocol" '.[$proto]' "$CONFIG_FILE")
        
        # 显示基本信息
        local ip=$(echo "$config" | jq -r '.ip // "未知"')
        local port=$(echo "$config" | jq -r '.port // "未知"')
        local remark=$(echo "$config" | jq -r '.remark // "未知"')
        
        echo -e "服务器: ${ip}"
        echo -e "端口: ${port}"
        echo -e "备注: ${remark}"
        
        # 根据协议类型显示特定信息
        case "$protocol" in
            shadowsocks)
                local password=$(echo "$config" | jq -r '.password // "未知"')
                local method=$(echo "$config" | jq -r '.method // "未知"')
                echo -e "密码: ${password}"
                echo -e "加密: ${method}"
                
                # 生成分享链接
                if [ "$ip" != "未知" ] && [ "$port" != "未知" ] && [ "$password" != "未知" ] && [ "$method" != "未知" ]; then
                    local ss_uri="ss://$(echo -n "${method}:${password}@${ip}:${port}" | base64 -w 0)#${remark}"
                    echo -e "${BLUE}分享链接: ${ss_uri}${NC}"
                    
                    if command -v qrencode &>/dev/null; then
                        echo -e "${YELLOW}二维码:${NC}"
                        qrencode -t UTF8 "$ss_uri"
                    fi
                fi
                ;;
            # 其他协议的显示逻辑可以类似实现
            *)
                # 通用显示逻辑，显示所有键值对
                echo "$config" | jq -r 'to_entries | .[] | "\(.key): \(.value)"'
                ;;
        esac
        
        draw_line
    done
}

# 服务状态管理
manage_services() {
    draw_title
    echo -e "${CYAN}服务状态管理:${NC}"
    echo -e "${CYAN}1. 查看所有服务状态${NC}"
    echo -e "${CYAN}2. 启动服务${NC}"
    echo -e "${CYAN}3. 停止服务${NC}"
    echo -e "${CYAN}4. 重启服务${NC}"
    echo -e "${RED}0. 返回主菜单${NC}"
    draw_line
    
    read -p "请输入选项: " choice
    
    case "$choice" in
        1)
            draw_title
            echo -e "${CYAN}服务状态:${NC}"
            draw_line
            
            # 检查常见的代理服务状态
            check_service_status "shadowsocks-libev"
            check_service_status "v2ray"
            check_service_status "xray"
            check_service_status "trojan"
            check_service_status "hysteria"
            check_service_status "tuic"
            check_service_status "sing-box"
            check_service_status "clash"
            check_service_status "clash-meta"
            ;;
        2|3|4)
            draw_title
            echo -e "${CYAN}选择要操作的服务:${NC}"
            draw_line
            
            local services=("shadowsocks-libev" "v2ray" "xray" "trojan" "hysteria" "tuic" "sing-box" "clash" "clash-meta")
            local i=1
            
            for service in "${services[@]}"; do
                echo -e "${CYAN}$i. $service${NC}"
                i=$((i+1))
            done
            
            echo -e "${RED}0. 返回${NC}"
            draw_line
            
            read -p "请输入选项: " service_choice
            
            if [ "$service_choice" -ge 1 ] && [ "$service_choice" -le ${#services[@]} ]; then
                local selected_service=${services[$((service_choice-1))]}
                
                case "$choice" in
                    2) systemctl start "$selected_service" ;;
                    3) systemctl stop "$selected_service" ;;
                    4) systemctl restart "$selected_service" ;;
                esac
                
                log "服务 $selected_service 操作完成" "$GREEN"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入!${NC}"
            ;;
    esac
    
    read -p "按Enter键继续..."
}

# 检查服务状态
check_service_status() {
    local service="$1"
    
    if systemctl list-unit-files | grep -q "$service"; then
        local status=$(systemctl is-active "$service")
        local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
        
        if [ "$status" = "active" ]; then
            echo -e "$service: ${GREEN}运行中${NC} (${enabled})"
        else
            echo -e "$service: ${RED}已停止${NC} (${enabled})"
        fi
    else
        echo -e "$service: ${YELLOW}未安装${NC}"
    fi
}

# 备份与恢复
backup_restore() {
    draw_title
    echo -e "${CYAN}备份与恢复:${NC}"
    echo -e "${CYAN}1. 创建配置备份${NC}"
    echo -e "${CYAN}2. 恢复配置备份${NC}"
    echo -e "${RED}0. 返回主菜单${NC}"
    draw_line
    
    read -p "请输入选项: " choice
    
    case "$choice" in
        1)
            local backup_file="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).json"
            cp "$CONFIG_FILE" "$backup_file"
            log "配置已备份到: $backup_file" "$GREEN"
            ;;
        2)
            draw_title
            echo -e "${CYAN}可用备份:${NC}"
            draw_line
            
            local backups=("$BACKUP_DIR"/*)
            if [ ${#backups[@]} -eq 0 ] || [ ! -f "${backups[0]}" ]; then
                echo -e "${YELLOW}暂无可用备份${NC}"
                read -p "按Enter键继续..."
                return
            fi
            
            local i=1
            for backup in "${backups[@]}"; do
                if [ -f "$backup" ]; then
                    echo -e "${CYAN}$i. $(basename "$backup")${NC}"
                    i=$((i+1))
                fi
            done
            
            echo -e "${RED}0. 返回${NC}"
            draw_line
            
            read -p "请输入选项: " backup_choice
            
            if [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#backups[@]} ]; then
                local selected_backup=${backups[$((backup_choice-1))]}
                cp "$selected_backup" "$CONFIG_FILE"
                log "配置已从 $(basename "$selected_backup") 恢复" "$GREEN"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入!${NC}"
            ;;
    esac
    
    read -p "按Enter键继续..."
}

# 主菜单
show_main_menu() {
    draw_title
    echo -e "${CYAN}可用协议:${NC}"
    
    local i=1
    for protocol in "${PROTOCOL_SCRIPTS[@]}"; do
        local script_name="${protocol%%:*}"
        local display_name="${protocol#*:}"
        echo -e "${CYAN}$i. 安装 $display_name${NC}"
        i=$((i+1))
    done
    
    echo -e "${YELLOW}$i. 查看配置信息${NC}"
    i=$((i+1))
    echo -e "${YELLOW}$i. 服务状态管理${NC}"
    i=$((i+1))
    echo -e "${YELLOW}$i. 备份与恢复${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    draw_line
}

# 主函数
main() {
    check_root
    init_log
    
    # 检测系统
    os=$(check_os)
    log "检测到操作系统: $os" "$GREEN"
    
    # 安装依赖
    if ! install_dependencies "$os"; then
        log "依赖安装失败，请检查网络连接或手动安装依赖后重试" "$RED"
        exit 1
    fi
    
    # 初始化配置
    init_config
    
    # 主循环
    while true; do
        show_main_menu
        read -p "请输入选项: " choice
        
        if [ "$choice" -ge 1 ] && [ "$choice" -le ${#PROTOCOL_SCRIPTS[@]} ]; then
            # 安装选择的协议
            local protocol_index=$((choice-1))
            local protocol="${PROTOCOL_SCRIPTS[$protocol_index]}"
            local script_name="${protocol%%:*}"
            local display_name="${protocol#*:}"
            
            log "准备安装 $display_name" "$GREEN"
            run_protocol_script "$script_name"
        elif [ "$choice" -eq $((${#PROTOCOL_SCRIPTS[@]}+1)) ]; then
            # 查看配置信息
            show_configs
        elif [ "$choice" -eq $((${#PROTOCOL_SCRIPTS[@]}+2)) ]; then
            # 服务状态管理
            manage_services
        elif [ "$choice" -eq $((${#PROTOCOL_SCRIPTS[@]}+3)) ]; then
            # 备份与恢复
            backup_restore
        elif [ "$choice" -eq 0 ]; then
            echo -e "${GREEN}退出脚本...${NC}"
            exit 0
        else
            echo -e "${RED}无效选项，请重新输入!${NC}"
        fi
        
        read -p "按Enter键继续..."
    done
}

# 执行入口
main
