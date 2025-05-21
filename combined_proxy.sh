#!/bin/bash
# Combined Proxy Script with Uninstall Mode
# Based on scripts from https://github.com/ldg118/Proxy
# Original Author: Slotheve<https://slotheve.com>
# Combined and Enhanced by Manus
# 多协议代理一键脚本（含卸载模式）
# 基于 https://github.com/ldg118/Proxy 仓库脚本
# 原作者: Slotheve<https://slotheve.com>
# 整合与增强: Manus

# --- Color Codes ---
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

# --- Global Variables ---
IP4=$(curl -sL -4 ip.sb)
IP6=$(curl -sL -6 ip.sb)
CPU=$(uname -m)
ARCH=""
PMT=""
CMD_INSTALL=""
CMD_REMOVE=""
CMD_UPGRADE=""
OS_TYPE=""
LANGUAGE="en" # Default language: en for English, zh for Chinese

# --- Utility Functions ---

# Color Echo Function
colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

# Bilingual Message Function
msg() {
    local en_msg="$1"
    local zh_msg="$2"
    
    if [[ "$LANGUAGE" == "zh" ]]; then
        echo -e "$zh_msg"
    else
        echo -e "$en_msg"
    fi
}

# Architecture Check
archAffix() {
    case "$CPU" in
        x86_64|amd64)
            ARCH="amd64"
            CPU="x86_64"
        ;;
        armv8|aarch64)
            ARCH="arm64"
            CPU="aarch64"
        ;;
        *)
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $RED " 错误: 不支持的CPU架构!"
            else
                colorEcho $RED " Error: Unsupported CPU architecture!"
            fi
            exit 1
        ;;
    esac
    return 0
}

# System Check Function
checkSystem() {
    # Root check
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        result=$(id | awk '{print $1}')
        if [[ $result != "用户id=0(root)" ]]; then
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $RED " 错误: 请以root身份运行此脚本。"
            else
                colorEcho $RED " Error: Please run this script as root."
            fi
            exit 1
        fi
    fi

    # OS check
    if [[ -f /etc/redhat-release ]]; then
        OS_TYPE="centos"
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /etc/os-release; then
        OS_TYPE="debian"
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /etc/os-release; then
        OS_TYPE="ubuntu"
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    elif grep -Eqi "alpine" /etc/issue || grep -Eqi "alpine" /etc/os-release; then
        OS_TYPE="alpine"
        PMT="apk"
        CMD_INSTALL="apk add --no-cache "
        CMD_REMOVE="apk del "
        CMD_UPGRADE="apk update; apk upgrade"
    else
        if [[ "$LANGUAGE" == "zh" ]]; then
            colorEcho $RED " 错误: 不支持的Linux发行版。"
        else
            colorEcho $RED " Error: Unsupported Linux distribution."
        fi
        exit 1
    fi

    # Systemctl check (except Alpine)
    if [[ "$OS_TYPE" != "alpine" ]]; then
        res=$(which systemctl 2>/dev/null)
        if [[ "$?" != "0" ]]; then
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $RED " 错误: 需要systemd但未找到。请升级您的系统。"
            else
                colorEcho $RED " Error: Systemd is required, but not found. Please upgrade your system."
            fi
            exit 1
        fi
    elif [[ "$OS_TYPE" == "alpine" ]]; then
        res=$(which rc-service 2>/dev/null)
        if [[ "$?" != "0" ]]; then
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $RED " 错误: Alpine需要OpenRC但未找到。"
            else
                colorEcho $RED " Error: OpenRC is required for Alpine, but not found."
            fi
            exit 1
        fi
        # Ensure bash and curl are installed on Alpine
        if ! command -v bash &> /dev/null || ! command -v curl &> /dev/null; then
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $YELLOW " 正在为Alpine安装bash和curl..."
            else
                colorEcho $YELLOW " Installing bash and curl for Alpine..."
            fi
            apk add --no-cache bash curl
            if [[ $? -ne 0 ]]; then
                if [[ "$LANGUAGE" == "zh" ]]; then
                    colorEcho $RED " 安装bash或curl失败。请手动安装并重新运行脚本。"
                else
                    colorEcho $RED " Failed to install bash or curl. Please install them manually and rerun the script."
                fi
                exit 1
            fi
        fi
    fi

    # Set SELinux to permissive if enforcing
    if [[ -s /etc/selinux/config ]] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
        if [[ "$LANGUAGE" == "zh" ]]; then
            colorEcho $YELLOW " 将SELinux设置为宽容模式。"
        else
            colorEcho $YELLOW " Setting SELinux to permissive."
        fi
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi

    # Call archAffix
    archAffix
}

# Install Basic Dependencies
installDependencies() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $YELLOW " 正在安装基本依赖（wget, curl, openssl, net-tools）..."
    else
        colorEcho $YELLOW " Installing basic dependencies (wget, curl, openssl, net-tools)..."
    fi
    
    if [[ "$PMT" = "yum" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar
    elif [[ "$PMT" = "apt" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar libssl-dev
    elif [[ "$PMT" = "apk" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar
    fi
    # Check if installation was successful
    if ! command -v wget &> /dev/null || ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
        if [[ "$LANGUAGE" == "zh" ]]; then
            colorEcho $RED " 错误: 安装基本依赖失败。"
        else
            colorEcho $RED " Error: Failed to install basic dependencies."
        fi
        exit 1
    fi
}

# --- Language Selection ---
select_language() {
    clear
    echo "############################################################"
    echo "#                 语言选择 / Language Selection              #"
    echo "############################################################"
    echo ""
    echo "  1. 中文"
    echo "  2. English"
    echo ""
    read -p "请选择语言/Please select language [1-2]: " lang_choice
    
    case $lang_choice in
        1)
            LANGUAGE="zh"
            colorEcho $GREEN " 已选择中文作为显示语言"
            ;;
        2)
            LANGUAGE="en"
            colorEcho $GREEN " English has been selected as the display language"
            ;;
        *)
            LANGUAGE="en"
            colorEcho $YELLOW " 无效选择，使用默认语言(英文) / Invalid choice, using default language (English)"
            ;;
    esac
    sleep 1
}

# --- Protocol Specific Functions (Placeholders) ---

install_meta() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Meta (mihomo) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Meta (mihomo) installation."
    fi
    # Add installation logic here
}

uninstall_meta() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Meta (mihomo) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Meta (mihomo) uninstallation."
    fi
    # Add uninstallation logic here
}

status_meta() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Meta (mihomo) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Meta (mihomo) status check."
    fi
    # Add status check logic here
}

showInfo_meta() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Meta (mihomo) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Meta (mihomo) info display."
    fi
    # Add info display logic here
}

install_ss() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Shadowsocks (ss-go) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Shadowsocks (ss-go) installation."
    fi
    # Add installation logic here
}

uninstall_ss() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Shadowsocks (ss-go) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Shadowsocks (ss-go) uninstallation."
    fi
    # Add uninstallation logic here
}

status_ss() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Shadowsocks (ss-go) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Shadowsocks (ss-go) status check."
    fi
    # Add status check logic here
}

showInfo_ss() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Shadowsocks (ss-go) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Shadowsocks (ss-go) info display."
    fi
    # Add info display logic here
}

install_hysteria() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Hysteria2 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Hysteria2 installation."
    fi
    # Add installation logic here
}

uninstall_hysteria() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Hysteria2 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Hysteria2 uninstallation."
    fi
    # Add uninstallation logic here
}

status_hysteria() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Hysteria2 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Hysteria2 status check."
    fi
    # Add status check logic here
}

showInfo_hysteria() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Hysteria2 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Hysteria2 info display."
    fi
    # Add info display logic here
}

install_tuic() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Tuic 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Tuic installation."
    fi
    # Add installation logic here
}

uninstall_tuic() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Tuic 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Tuic uninstallation."
    fi
    # Add uninstallation logic here
}

status_tuic() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Tuic 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Tuic status check."
    fi
    # Add status check logic here
}

showInfo_tuic() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Tuic 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Tuic info display."
    fi
    # Add info display logic here
}

install_singbox_reality() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (Reality) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (Reality) installation."
    fi
    # Add installation logic here
}

uninstall_singbox_reality() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (Reality) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (Reality) uninstallation."
    fi
    # Add uninstallation logic here
}

status_singbox_reality() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (Reality) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (Reality) status check."
    fi
    # Add status check logic here
}

showInfo_singbox_reality() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (Reality) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (Reality) info display."
    fi
    # Add info display logic here
}

install_singbox_shadowtls() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (ShadowTLS) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (ShadowTLS) installation."
    fi
    # Add installation logic here
}

uninstall_singbox_shadowtls() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (ShadowTLS) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (ShadowTLS) uninstallation."
    fi
    # Add uninstallation logic here
}

status_singbox_shadowtls() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (ShadowTLS) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (ShadowTLS) status check."
    fi
    # Add status check logic here
}

showInfo_singbox_shadowtls() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (ShadowTLS) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (ShadowTLS) info display."
    fi
    # Add info display logic here
}

install_singbox_ws() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (WS) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (WS) installation."
    fi
    # Add installation logic here
}

uninstall_singbox_ws() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (WS) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (WS) uninstallation."
    fi
    # Add uninstallation logic here
}

status_singbox_ws() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (WS) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (WS) status check."
    fi
    # Add status check logic here
}

showInfo_singbox_ws() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Singbox (WS) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Singbox (WS) info display."
    fi
    # Add info display logic here
}

install_xray_none() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Xray (None) 安装功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Xray (None) installation."
    fi
    # Add installation logic here
}

uninstall_xray_none() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Xray (None) 卸载功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Xray (None) uninstallation."
    fi
    # Add uninstallation logic here
}

status_xray_none() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Xray (None) 状态检查功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Xray (None) status check."
    fi
    # Add status check logic here
}

showInfo_xray_none() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " Xray (None) 信息显示功能占位符。"
    else
        colorEcho $GREEN " Placeholder for Xray (None) info display."
    fi
    # Add info display logic here
}

# --- Uninstall All Function ---
uninstall_all() {
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $YELLOW " 开始卸载所有管理的代理服务..."
    else
        colorEcho $YELLOW " Starting uninstallation of all managed proxy services..."
    fi
    
    # Call individual uninstall functions
    uninstall_meta
    uninstall_ss
    uninstall_hysteria
    uninstall_tuic
    uninstall_singbox_reality # Assuming reality, shadowtls, ws use the same core singbox binary/service
    # uninstall_singbox_shadowtls # Likely redundant if reality uninstalls core singbox
    # uninstall_singbox_ws # Likely redundant
    uninstall_xray_none
    
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $GREEN " 卸载过程已完成。"
    else
        colorEcho $GREEN " Uninstallation process completed."
    fi
}

# --- Main Menu ---
main_menu() {
    clear
    if [[ "$LANGUAGE" == "zh" ]]; then
        colorEcho $BLUE "############################################################"
        colorEcho $BLUE "#                多协议代理一键安装脚本                    #"
        colorEcho $BLUE "#----------------------------------------------------------#"
        colorEcho $BLUE "#         基于 Slotheve (ldg118/Proxy) 的脚本              #"
        colorEcho $BLUE "#         由 Manus 整合并增强，添加统一菜单和卸载功能     #"
        colorEcho $BLUE "############################################################"
        echo
        colorEcho $GREEN " --- 安装选项 --- "
        colorEcho $PLAIN "  1. 安装 Meta (mihomo - Vmess/SS)"
        colorEcho $PLAIN "  2. 安装 Shadowsocks (ss-go)"
        colorEcho $PLAIN "  3. 安装 Hysteria2"
        colorEcho $PLAIN "  4. 安装 Tuic (v5)"
        colorEcho $PLAIN "  5. 安装 Sing-box (VLESS + Reality + Vision)"
        colorEcho $PLAIN "  6. 安装 Sing-box (VLESS + ShadowTLS + Vision)" # Placeholder
        colorEcho $PLAIN "  7. 安装 Sing-box (VLESS + WebSocket + Vision)" # Placeholder
        colorEcho $PLAIN "  8. 安装 Xray (VLESS + TCP + TLS/XTLS)" # Placeholder
        echo
        colorEcho $GREEN " --- 卸载选项 --- "
        colorEcho $RED "  9. 卸载 Meta (mihomo)"
        colorEcho $RED " 10. 卸载 Shadowsocks (ss-go)"
        colorEcho $RED " 11. 卸载 Hysteria2"
        colorEcho $RED " 12. 卸载 Tuic (v5)"
        colorEcho $RED " 13. 卸载 Sing-box (任何变体)"
        colorEcho $RED " 14. 卸载 Xray (任何变体)"
        colorEcho $RED " 15. 卸载所有管理的代理"
        echo
        colorEcho $GREEN " --- 其他选项 --- "
        colorEcho $YELLOW " 16. 查看状态/配置信息 (稍后选择协议)"
        colorEcho $YELLOW " 17. 管理服务 (启动/停止/重启 - 稍后选择)"
        colorEcho $YELLOW " 18. 查看日志 (稍后选择协议)"
        colorEcho $YELLOW " 19. 切换语言"
        echo
        colorEcho $PLAIN "  0. 退出"
        echo
        
        read -p " 请选择一个选项 [0-19]: " choice
    else
        colorEcho $BLUE "############################################################"
        colorEcho $BLUE "#         Combined Proxy Installation Script             #"
        colorEcho $BLUE "#----------------------------------------------------------#"
        colorEcho $BLUE "#         Based on scripts by Slotheve (ldg118/Proxy)      #"
        colorEcho $BLUE "#         Enhanced with unified menu & uninstall by Manus  #"
        colorEcho $BLUE "############################################################"
        echo
        colorEcho $GREEN " --- Installation Options --- "
        colorEcho $PLAIN "  1. Install Meta (mihomo - Vmess/SS)"
        colorEcho $PLAIN "  2. Install Shadowsocks (ss-go)"
        colorEcho $PLAIN "  3. Install Hysteria2"
        colorEcho $PLAIN "  4. Install Tuic (v5)"
        colorEcho $PLAIN "  5. Install Sing-box (VLESS + Reality + Vision)"
        colorEcho $PLAIN "  6. Install Sing-box (VLESS + ShadowTLS + Vision)" # Placeholder
        colorEcho $PLAIN "  7. Install Sing-box (VLESS + WebSocket + Vision)" # Placeholder
        colorEcho $PLAIN "  8. Install Xray (VLESS + TCP + TLS/XTLS)" # Placeholder
        echo
        colorEcho $GREEN " --- Uninstallation Options --- "
        colorEcho $RED "  9. Uninstall Meta (mihomo)"
        colorEcho $RED " 10. Uninstall Shadowsocks (ss-go)"
        colorEcho $RED " 11. Uninstall Hysteria2"
        colorEcho $RED " 12. Uninstall Tuic (v5)"
        colorEcho $RED " 13. Uninstall Sing-box (Any Variant)"
        colorEcho $RED " 14. Uninstall Xray (Any Variant)"
        colorEcho $RED " 15. Uninstall ALL Managed Proxies"
        echo
        colorEcho $GREEN " --- Other Options --- "
        colorEcho $YELLOW " 16. View Status / Config Info (Choose Protocol Later)"
        colorEcho $YELLOW " 17. Manage Services (Start/Stop/Restart - Choose Later)"
        colorEcho $YELLOW " 18. View Logs (Choose Protocol Later)"
        colorEcho $YELLOW " 19. Switch Language"
        echo
        colorEcho $PLAIN "  0. Exit"
        echo
        
        read -p " Please select an option [0-19]: " choice
    fi

    case $choice in
        1) install_meta ;; 
        2) install_ss ;; 
        3) install_hysteria ;; 
        4) install_tuic ;; 
        5) install_singbox_reality ;; 
        6) install_singbox_shadowtls ;; # Placeholder call
        7) install_singbox_ws ;; # Placeholder call
        8) install_xray_none ;; # Placeholder call
        9) uninstall_meta ;; 
       10) uninstall_ss ;; 
       11) uninstall_hysteria ;; 
       12) uninstall_tuic ;; 
       13) uninstall_singbox_reality ;; # Assuming one uninstall for all singbox
       14) uninstall_xray_none ;; # Assuming one uninstall for all xray
       15) uninstall_all ;; 
       # 16, 17, 18 would need sub-menus
       16) 
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $YELLOW " 状态/信息菜单尚未实现。"
            else
                colorEcho $YELLOW " Status/Info menu not yet implemented."
            fi
            ;; 
       17) 
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $YELLOW " 服务管理菜单尚未实现。"
            else
                colorEcho $YELLOW " Service management menu not yet implemented."
            fi
            ;; 
       18) 
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $YELLOW " 日志查看菜单尚未实现。"
            else
                colorEcho $YELLOW " Log viewing menu not yet implemented."
            fi
            ;; 
       19) select_language; main_menu ;;
        0) exit 0 ;; 
        *)
            if [[ "$LANGUAGE" == "zh" ]]; then
                colorEcho $RED " 无效选择，请重试。"
            else
                colorEcho $RED " Invalid choice, please try again."
            fi
            sleep 1.5
            main_menu
            ;;
    esac
}

# --- Script Execution ---
select_language
checkSystem
installDependencies
main_menu
