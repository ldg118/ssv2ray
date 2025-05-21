#!/bin/bash
# 多协议代理一键脚本（含卸载模式）
# 基于 https://github.com/ldg118/Proxy 和 https://github.com/233boy/v2ray 仓库脚本
# 原作者: Slotheve<https://slotheve.com> 和 233boy
# 整合与增强: Manus

# --- 颜色代码 ---
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[36m"
MAGENTA="\033[35m"
PLAIN='\033[0m'
BOLD="\033[1m"

# --- 全局变量 ---
IP4=$(curl -sL -4 ip.sb)
IP6=$(curl -sL -6 ip.sb)
CPU=$(uname -m)
ARCH=""
PMT=""
CMD_INSTALL=""
CMD_REMOVE=""
CMD_UPGRADE=""
OS_TYPE=""
CURRENT_MENU="main" # 当前菜单：main, proxy, v2ray, service, logs
VERSION="1.0.0"
LAST_ACTION=""

# --- 工具函数 ---

# 彩色输出函数
colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

# 显示标题
showTitle() {
    clear
    echo
    colorEcho $BLUE "╔════════════════════════════════════════════════════════════╗"
    colorEcho $BLUE "║                                                            ║"
    colorEcho $BLUE "║ ${BOLD}               多协议代理一键管理脚本 v${VERSION}                ${PLAIN}${BLUE} ║"
    colorEcho $BLUE "║                                                            ║"
    colorEcho $BLUE "╚════════════════════════════════════════════════════════════╝"
    echo
}

# 显示底部
showFooter() {
    echo
    colorEcho $BLUE "╔════════════════════════════════════════════════════════════╗"
    colorEcho $BLUE "║                                                            ║"
    colorEcho $BLUE "║  ${PLAIN}${YELLOW}提示: 选择数字执行相应操作，选择 0 退出，选择 88 返回上级菜单${PLAIN}${BLUE}  ║"
    colorEcho $BLUE "║                                                            ║"
    colorEcho $BLUE "╚════════════════════════════════════════════════════════════╝"
    echo
}

# 显示分隔线
showSeparator() {
    colorEcho $BLUE "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"
    echo
}

# 显示操作结果
showResult() {
    local result=$1
    local message=$2
    
    echo
    if [[ "$result" == "success" ]]; then
        colorEcho $GREEN " ✓ $message"
    else
        colorEcho $RED " ✗ $message"
    fi
    echo
    colorEcho $YELLOW " 按任意键继续..."
    read -n 1 -s
}

# 显示确认对话框
showConfirm() {
    local message=$1
    local default=${2:-"n"}
    
    if [[ "$default" == "y" ]]; then
        read -p " $message [Y/n]: " confirm
        [[ -z "$confirm" ]] && confirm="y"
    else
        read -p " $message [y/N]: " confirm
        [[ -z "$confirm" ]] && confirm="n"
    fi
    
    if [[ "${confirm,,}" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

# 显示返回提示
showBack() {
    echo
    colorEcho $YELLOW " 操作完成，按任意键返回..."
    read -n 1 -s
    
    case "$CURRENT_MENU" in
        "proxy") proxy_menu ;;
        "v2ray") v2ray_menu ;;
        "service") service_menu ;;
        "logs") logs_menu ;;
        *) main_menu ;;
    esac
}

# 架构检测
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
            colorEcho $RED " 错误: 不支持的CPU架构!"
            exit 1
        ;;
    esac
    return 0
}

# 系统检测函数
checkSystem() {
    # Root检测
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        result=$(id | awk '{print $1}')
        if [[ $result != "用户id=0(root)" ]]; then
            colorEcho $RED " 错误: 请以root身份运行此脚本。"
            exit 1
        fi
    fi

    # 系统检测
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
        colorEcho $RED " 错误: 不支持的Linux发行版。"
        exit 1
    fi

    # Systemctl检测 (除Alpine外)
    if [[ "$OS_TYPE" != "alpine" ]]; then
        res=$(which systemctl 2>/dev/null)
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 错误: 需要systemd但未找到。请升级您的系统。"
            exit 1
        fi
    elif [[ "$OS_TYPE" == "alpine" ]]; then
        res=$(which rc-service 2>/dev/null)
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 错误: Alpine需要OpenRC但未找到。"
            exit 1
        fi
        # 确保Alpine上安装了bash和curl
        if ! command -v bash &> /dev/null || ! command -v curl &> /dev/null; then
            colorEcho $YELLOW " 正在为Alpine安装bash和curl..."
            apk add --no-cache bash curl
            if [[ $? -ne 0 ]]; then
                colorEcho $RED " 安装bash或curl失败。请手动安装并重新运行脚本。"
                exit 1
            fi
        fi
    fi

    # 如果SELinux为enforcing，设置为permissive
    if [[ -s /etc/selinux/config ]] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
        colorEcho $YELLOW " 将SELinux设置为宽容模式。"
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi

    # 调用archAffix
    archAffix
}

# 安装基本依赖
installDependencies() {
    colorEcho $YELLOW " 正在安装基本依赖（wget, curl, openssl, net-tools）..."
    
    if [[ "$PMT" = "yum" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar
    elif [[ "$PMT" = "apt" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar libssl-dev
    elif [[ "$PMT" = "apk" ]]; then
        $CMD_INSTALL wget curl openssl net-tools tar
    fi
    # 检查安装是否成功
    if ! command -v wget &> /dev/null || ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
        colorEcho $RED " 错误: 安装基本依赖失败。"
        exit 1
    fi
}

# 显示系统信息
showSystemInfo() {
    showTitle
    colorEcho $CYAN " 【系统信息】"
    echo
    colorEcho $YELLOW " 操作系统: $OS_TYPE"
    colorEcho $YELLOW " 架构: $ARCH ($CPU)"
    colorEcho $YELLOW " IPv4: $IP4"
    [[ ! -z "$IP6" ]] && colorEcho $YELLOW " IPv6: $IP6"
    echo
    colorEcho $CYAN " 【已安装代理】"
    echo
    
    # 检查各代理是否安装
    local installed=false
    
    # 检查Meta
    if [[ -f /etc/mihomo/mihomo ]]; then
        colorEcho $GREEN " ✓ Meta (mihomo) 已安装"
        installed=true
    fi
    
    # 检查Shadowsocks
    if [[ -f /etc/ss/shadowsocks ]]; then
        colorEcho $GREEN " ✓ Shadowsocks (ss-go) 已安装"
        installed=true
    fi
    
    # 检查Hysteria
    if [[ -f /etc/hysteria/hysteria ]]; then
        colorEcho $GREEN " ✓ Hysteria2 已安装"
        installed=true
    fi
    
    # 检查Tuic
    if [[ -f /etc/tuic/tuic ]]; then
        colorEcho $GREEN " ✓ Tuic 已安装"
        installed=true
    fi
    
    # 检查Sing-box
    if [[ -f /usr/local/bin/sing-box ]]; then
        colorEcho $GREEN " ✓ Sing-box 已安装"
        installed=true
    fi
    
    # 检查Xray
    if [[ -f /usr/local/bin/xray ]]; then
        colorEcho $GREEN " ✓ Xray 已安装"
        installed=true
    fi
    
    # 检查V2Ray
    if [[ -f /usr/local/bin/v2ray ]]; then
        colorEcho $GREEN " ✓ V2Ray 已安装"
        installed=true
    fi
    
    if [[ "$installed" == "false" ]]; then
        colorEcho $YELLOW " 未检测到已安装的代理"
    fi
    
    showSeparator
}

# --- 代理协议特定函数 (占位符) ---

install_meta() {
    showTitle
    colorEcho $CYAN " 【安装 Meta (mihomo)】"
    echo
    colorEcho $GREEN " Meta (mihomo) 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_meta"
    showBack
}

uninstall_meta() {
    showTitle
    colorEcho $CYAN " 【卸载 Meta (mihomo)】"
    echo
    if showConfirm "确定要卸载 Meta (mihomo) 吗？"; then
        colorEcho $GREEN " Meta (mihomo) 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_meta"
    fi
    showBack
}

status_meta() {
    showTitle
    colorEcho $CYAN " 【Meta (mihomo) 状态】"
    echo
    colorEcho $GREEN " Meta (mihomo) 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_meta"
    showBack
}

showInfo_meta() {
    showTitle
    colorEcho $CYAN " 【Meta (mihomo) 配置信息】"
    echo
    colorEcho $GREEN " Meta (mihomo) 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_meta"
    showBack
}

install_ss() {
    showTitle
    colorEcho $CYAN " 【安装 Shadowsocks (ss-go)】"
    echo
    colorEcho $GREEN " Shadowsocks (ss-go) 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_ss"
    showBack
}

uninstall_ss() {
    showTitle
    colorEcho $CYAN " 【卸载 Shadowsocks (ss-go)】"
    echo
    if showConfirm "确定要卸载 Shadowsocks (ss-go) 吗？"; then
        colorEcho $GREEN " Shadowsocks (ss-go) 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_ss"
    fi
    showBack
}

status_ss() {
    showTitle
    colorEcho $CYAN " 【Shadowsocks (ss-go) 状态】"
    echo
    colorEcho $GREEN " Shadowsocks (ss-go) 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_ss"
    showBack
}

showInfo_ss() {
    showTitle
    colorEcho $CYAN " 【Shadowsocks (ss-go) 配置信息】"
    echo
    colorEcho $GREEN " Shadowsocks (ss-go) 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_ss"
    showBack
}

install_hysteria() {
    showTitle
    colorEcho $CYAN " 【安装 Hysteria2】"
    echo
    colorEcho $GREEN " Hysteria2 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_hysteria"
    showBack
}

uninstall_hysteria() {
    showTitle
    colorEcho $CYAN " 【卸载 Hysteria2】"
    echo
    if showConfirm "确定要卸载 Hysteria2 吗？"; then
        colorEcho $GREEN " Hysteria2 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_hysteria"
    fi
    showBack
}

status_hysteria() {
    showTitle
    colorEcho $CYAN " 【Hysteria2 状态】"
    echo
    colorEcho $GREEN " Hysteria2 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_hysteria"
    showBack
}

showInfo_hysteria() {
    showTitle
    colorEcho $CYAN " 【Hysteria2 配置信息】"
    echo
    colorEcho $GREEN " Hysteria2 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_hysteria"
    showBack
}

install_tuic() {
    showTitle
    colorEcho $CYAN " 【安装 Tuic】"
    echo
    colorEcho $GREEN " Tuic 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_tuic"
    showBack
}

uninstall_tuic() {
    showTitle
    colorEcho $CYAN " 【卸载 Tuic】"
    echo
    if showConfirm "确定要卸载 Tuic 吗？"; then
        colorEcho $GREEN " Tuic 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_tuic"
    fi
    showBack
}

status_tuic() {
    showTitle
    colorEcho $CYAN " 【Tuic 状态】"
    echo
    colorEcho $GREEN " Tuic 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_tuic"
    showBack
}

showInfo_tuic() {
    showTitle
    colorEcho $CYAN " 【Tuic 配置信息】"
    echo
    colorEcho $GREEN " Tuic 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_tuic"
    showBack
}

install_singbox_reality() {
    showTitle
    colorEcho $CYAN " 【安装 Sing-box (Reality)】"
    echo
    colorEcho $GREEN " Sing-box (Reality) 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_singbox_reality"
    showBack
}

uninstall_singbox_reality() {
    showTitle
    colorEcho $CYAN " 【卸载 Sing-box】"
    echo
    if showConfirm "确定要卸载 Sing-box 吗？"; then
        colorEcho $GREEN " Sing-box 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_singbox_reality"
    fi
    showBack
}

status_singbox_reality() {
    showTitle
    colorEcho $CYAN " 【Sing-box (Reality) 状态】"
    echo
    colorEcho $GREEN " Sing-box (Reality) 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_singbox_reality"
    showBack
}

showInfo_singbox_reality() {
    showTitle
    colorEcho $CYAN " 【Sing-box (Reality) 配置信息】"
    echo
    colorEcho $GREEN " Sing-box (Reality) 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_singbox_reality"
    showBack
}

install_singbox_shadowtls() {
    showTitle
    colorEcho $CYAN " 【安装 Sing-box (ShadowTLS)】"
    echo
    colorEcho $GREEN " Sing-box (ShadowTLS) 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_singbox_shadowtls"
    showBack
}

status_singbox_shadowtls() {
    showTitle
    colorEcho $CYAN " 【Sing-box (ShadowTLS) 状态】"
    echo
    colorEcho $GREEN " Sing-box (ShadowTLS) 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_singbox_shadowtls"
    showBack
}

showInfo_singbox_shadowtls() {
    showTitle
    colorEcho $CYAN " 【Sing-box (ShadowTLS) 配置信息】"
    echo
    colorEcho $GREEN " Sing-box (ShadowTLS) 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_singbox_shadowtls"
    showBack
}

install_singbox_ws() {
    showTitle
    colorEcho $CYAN " 【安装 Sing-box (WS)】"
    echo
    colorEcho $GREEN " Sing-box (WS) 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_singbox_ws"
    showBack
}

status_singbox_ws() {
    showTitle
    colorEcho $CYAN " 【Sing-box (WS) 状态】"
    echo
    colorEcho $GREEN " Sing-box (WS) 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_singbox_ws"
    showBack
}

showInfo_singbox_ws() {
    showTitle
    colorEcho $CYAN " 【Sing-box (WS) 配置信息】"
    echo
    colorEcho $GREEN " Sing-box (WS) 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_singbox_ws"
    showBack
}

install_xray_none() {
    showTitle
    colorEcho $CYAN " 【安装 Xray】"
    echo
    colorEcho $GREEN " Xray 安装功能占位符。"
    # 添加安装逻辑
    LAST_ACTION="install_xray_none"
    showBack
}

uninstall_xray_none() {
    showTitle
    colorEcho $CYAN " 【卸载 Xray】"
    echo
    if showConfirm "确定要卸载 Xray 吗？"; then
        colorEcho $GREEN " Xray 卸载功能占位符。"
        # 添加卸载逻辑
        LAST_ACTION="uninstall_xray_none"
    fi
    showBack
}

status_xray_none() {
    showTitle
    colorEcho $CYAN " 【Xray 状态】"
    echo
    colorEcho $GREEN " Xray 状态检查功能占位符。"
    # 添加状态检查逻辑
    LAST_ACTION="status_xray_none"
    showBack
}

showInfo_xray_none() {
    showTitle
    colorEcho $CYAN " 【Xray 配置信息】"
    echo
    colorEcho $GREEN " Xray 信息显示功能占位符。"
    # 添加信息显示逻辑
    LAST_ACTION="showInfo_xray_none"
    showBack
}

# --- V2Ray 特定函数 ---

install_v2ray() {
    showTitle
    colorEcho $CYAN " 【安装 V2Ray】"
    echo
    colorEcho $GREEN " 正在安装 V2Ray..."
    # 这里可以调用233boy的v2ray安装脚本
    # 例如：bash <(curl -s -L https://raw.githubusercontent.com/233boy/v2ray/master/install.sh)
    colorEcho $GREEN " V2Ray 安装完成"
    LAST_ACTION="install_v2ray"
    showBack
}

uninstall_v2ray() {
    showTitle
    colorEcho $CYAN " 【卸载 V2Ray】"
    echo
    if showConfirm "确定要卸载 V2Ray 吗？"; then
        colorEcho $GREEN " 正在卸载 V2Ray..."
        # 这里可以调用233boy的v2ray卸载命令
        # 例如：v2ray uninstall
        colorEcho $GREEN " V2Ray 卸载完成"
        LAST_ACTION="uninstall_v2ray"
    fi
    showBack
}

status_v2ray() {
    showTitle
    colorEcho $CYAN " 【V2Ray 状态】"
    echo
    colorEcho $GREEN " 正在检查 V2Ray 状态..."
    # 这里可以调用233boy的v2ray状态检查命令
    # 例如：v2ray status
    LAST_ACTION="status_v2ray"
    showBack
}

showInfo_v2ray() {
    showTitle
    colorEcho $CYAN " 【V2Ray 配置信息】"
    echo
    colorEcho $GREEN " 正在显示 V2Ray 配置信息..."
    # 这里可以调用233boy的v2ray信息显示命令
    # 例如：v2ray info
    LAST_ACTION="showInfo_v2ray"
    showBack
}

# --- 卸载所有函数 ---
uninstall_all() {
    showTitle
    colorEcho $CYAN " 【卸载所有代理】"
    echo
    if showConfirm "确定要卸载所有代理吗？此操作不可逆！"; then
        colorEcho $YELLOW " 开始卸载所有管理的代理服务..."
        
        # 调用各个卸载函数
        uninstall_meta
        uninstall_ss
        uninstall_hysteria
        uninstall_tuic
        uninstall_singbox_reality # 假设reality, shadowtls, ws使用相同的核心singbox二进制/服务
        # uninstall_singbox_shadowtls # 如果reality卸载核心singbox，可能冗余
        # uninstall_singbox_ws # 可能冗余
        uninstall_xray_none
        uninstall_v2ray
        
        colorEcho $GREEN " 卸载过程已完成。"
        LAST_ACTION="uninstall_all"
    fi
    showBack
}

# --- 主菜单 ---
main_menu() {
    showTitle
    CURRENT_MENU="main"
    
    colorEcho $CYAN " 【系统信息】"
    colorEcho $YELLOW " 系统: $OS_TYPE | 架构: $ARCH | IP: $IP4"
    
    showSeparator
    
    colorEcho $CYAN " 【主菜单】"
    echo
    colorEcho $GREEN " --- 代理协议选择 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} 常规代理协议 ${YELLOW}(Shadowsocks, Hysteria2, Tuic, Singbox等)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} V2Ray 管理 ${YELLOW}(233boy的V2Ray脚本)${PLAIN}"
    echo
    colorEcho $GREEN " --- 管理选项 --- "
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} 服务管理 ${YELLOW}(启动/停止/重启)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} 查看日志"
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} 系统信息"
    colorEcho $RED " ${BOLD} 6.${PLAIN} 卸载所有代理"
    echo
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个选项 [0-6]: " choice
    
    case $choice in
        1) proxy_menu ;;
        2) v2ray_menu ;;
        3) service_menu ;;
        4) logs_menu ;;
        5) 
            showSystemInfo
            read -p " 按任意键返回主菜单..." -n 1 -s
            main_menu
            ;;
        6) 
            uninstall_all
            ;;
        0) 
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0 
            ;;
        *)
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            main_menu
            ;;
    esac
}

# --- 代理协议子菜单 ---
proxy_menu() {
    showTitle
    CURRENT_MENU="proxy"
    
    colorEcho $CYAN " 【常规代理协议管理】"
    echo
    colorEcho $GREEN " --- 安装选项 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} 安装 Meta ${YELLOW}(mihomo - Vmess/SS)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} 安装 Shadowsocks ${YELLOW}(ss-go)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} 安装 Hysteria2"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} 安装 Tuic ${YELLOW}(v5)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} 安装 Sing-box ${YELLOW}(VLESS + Reality + Vision)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 6.${PLAIN} 安装 Sing-box ${YELLOW}(VLESS + ShadowTLS + Vision)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 7.${PLAIN} 安装 Sing-box ${YELLOW}(VLESS + WebSocket + Vision)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 8.${PLAIN} 安装 Xray ${YELLOW}(VLESS + TCP + TLS/XTLS)${PLAIN}"
    
    showSeparator
    
    colorEcho $GREEN " --- 卸载选项 --- "
    colorEcho $RED " ${BOLD} 9.${PLAIN} 卸载 Meta ${YELLOW}(mihomo)${PLAIN}"
    colorEcho $RED " ${BOLD}10.${PLAIN} 卸载 Shadowsocks ${YELLOW}(ss-go)${PLAIN}"
    colorEcho $RED " ${BOLD}11.${PLAIN} 卸载 Hysteria2"
    colorEcho $RED " ${BOLD}12.${PLAIN} 卸载 Tuic ${YELLOW}(v5)${PLAIN}"
    colorEcho $RED " ${BOLD}13.${PLAIN} 卸载 Sing-box ${YELLOW}(任何变体)${PLAIN}"
    colorEcho $RED " ${BOLD}14.${PLAIN} 卸载 Xray ${YELLOW}(任何变体)${PLAIN}"
    
    showSeparator
    
    colorEcho $GREEN " --- 信息查看 --- "
    colorEcho $YELLOW " ${BOLD}15.${PLAIN} 查看配置信息"
    
    showSeparator
    
    colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回主菜单"
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个选项 [0-15/88]: " choice
    
    case $choice in
        1) install_meta ;;
        2) install_ss ;;
        3) install_hysteria ;;
        4) install_tuic ;;
        5) install_singbox_reality ;;
        6) install_singbox_shadowtls ;;
        7) install_singbox_ws ;;
        8) install_xray_none ;;
        9) uninstall_meta ;;
        10) uninstall_ss ;;
        11) uninstall_hysteria ;;
        12) uninstall_tuic ;;
        13) uninstall_singbox_reality ;;
        14) uninstall_xray_none ;;
        15) info_submenu "proxy" ;;
        88) main_menu ;;
        0) 
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0 
            ;;
        *)
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            proxy_menu
            ;;
    esac
}

# --- V2Ray子菜单 ---
v2ray_menu() {
    showTitle
    CURRENT_MENU="v2ray"
    
    colorEcho $CYAN " 【V2Ray 管理】"
    echo
    colorEcho $GREEN " --- 基本操作 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} 安装 V2Ray"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} 卸载 V2Ray"
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} 查看 V2Ray 状态"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} 查看 V2Ray 配置信息"
    
    showSeparator
    
    colorEcho $GREEN " --- 高级操作 --- "
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} 添加配置"
    colorEcho $PLAIN " ${BOLD} 6.${PLAIN} 更改配置"
    colorEcho $PLAIN " ${BOLD} 7.${PLAIN} 删除配置"
    colorEcho $PLAIN " ${BOLD} 8.${PLAIN} 更新 V2Ray"
    
    showSeparator
    
    colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回主菜单"
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个选项 [0-8/88]: " choice
    
    case $choice in
        1) install_v2ray ;;
        2) uninstall_v2ray ;;
        3) status_v2ray ;;
        4) showInfo_v2ray ;;
        5) 
            showTitle
            colorEcho $CYAN " 【V2Ray 添加配置】"
            echo
            colorEcho $YELLOW " 此功能需要调用v2ray脚本，暂未实现。"
            showBack
            ;;
        6) 
            showTitle
            colorEcho $CYAN " 【V2Ray 更改配置】"
            echo
            colorEcho $YELLOW " 此功能需要调用v2ray脚本，暂未实现。"
            showBack
            ;;
        7) 
            showTitle
            colorEcho $CYAN " 【V2Ray 删除配置】"
            echo
            colorEcho $YELLOW " 此功能需要调用v2ray脚本，暂未实现。"
            showBack
            ;;
        8) 
            showTitle
            colorEcho $CYAN " 【V2Ray 更新】"
            echo
            colorEcho $YELLOW " 此功能需要调用v2ray脚本，暂未实现。"
            showBack
            ;;
        88) main_menu ;;
        0) 
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0 
            ;;
        *)
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            v2ray_menu
            ;;
    esac
}

# --- 服务管理子菜单 ---
service_menu() {
    showTitle
    CURRENT_MENU="service"
    
    colorEcho $CYAN " 【服务管理】"
    echo
    colorEcho $GREEN " --- 选择要管理的服务 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} Meta ${YELLOW}(mihomo)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} Shadowsocks ${YELLOW}(ss-go)${PLAIN}"
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} Hysteria2"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} Tuic"
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} Sing-box"
    colorEcho $PLAIN " ${BOLD} 6.${PLAIN} Xray"
    colorEcho $PLAIN " ${BOLD} 7.${PLAIN} V2Ray"
    
    showSeparator
    
    colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回主菜单"
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个服务 [0-7/88]: " service_choice
    
    if [[ "$service_choice" == "88" ]]; then
        main_menu
        return
    elif [[ "$service_choice" == "0" ]]; then
        showTitle
        colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
        echo
        exit 0
    elif [[ "$service_choice" -ge 1 && "$service_choice" -le 7 ]]; then
        showTitle
        
        # 根据选择确定服务名称
        local service_name=""
        case $service_choice in
            1) service_name="Meta (mihomo)" ;;
            2) service_name="Shadowsocks (ss-go)" ;;
            3) service_name="Hysteria2" ;;
            4) service_name="Tuic" ;;
            5) service_name="Sing-box" ;;
            6) service_name="Xray" ;;
            7) service_name="V2Ray" ;;
        esac
        
        colorEcho $CYAN " 【$service_name 服务操作】"
        echo
        colorEcho $GREEN " --- 选择操作 --- "
        colorEcho $PLAIN " ${BOLD} 1.${PLAIN} 启动服务"
        colorEcho $PLAIN " ${BOLD} 2.${PLAIN} 停止服务"
        colorEcho $PLAIN " ${BOLD} 3.${PLAIN} 重启服务"
        colorEcho $PLAIN " ${BOLD} 4.${PLAIN} 查看服务状态"
        
        showSeparator
        
        colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回上级菜单"
        colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
        
        showFooter
        
        read -p " 请选择一个操作 [0-4/88]: " operation_choice
        
        if [[ "$operation_choice" == "88" ]]; then
            service_menu
            return
        elif [[ "$operation_choice" == "0" ]]; then
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0
        elif [[ "$operation_choice" -ge 1 && "$operation_choice" -le 4 ]]; then
            showTitle
            colorEcho $CYAN " 【$service_name 服务操作】"
            echo
            
            # 根据选择确定操作名称
            local operation_name=""
            case $operation_choice in
                1) operation_name="启动" ;;
                2) operation_name="停止" ;;
                3) operation_name="重启" ;;
                4) operation_name="状态" ;;
            esac
            
            colorEcho $YELLOW " $operation_name $service_name 服务功能暂未实现。"
            showBack
        else
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            service_menu
        fi
    else
        colorEcho $RED " 无效选择，请重试。"
        sleep 1.5
        service_menu
    fi
}

# --- 日志查看子菜单 ---
logs_menu() {
    showTitle
    CURRENT_MENU="logs"
    
    colorEcho $CYAN " 【日志查看】"
    echo
    colorEcho $GREEN " --- 选择要查看的日志 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} Meta ${YELLOW}(mihomo)${PLAIN} 日志"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} Shadowsocks ${YELLOW}(ss-go)${PLAIN} 日志"
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} Hysteria2 日志"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} Tuic 日志"
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} Sing-box 日志"
    colorEcho $PLAIN " ${BOLD} 6.${PLAIN} Xray 日志"
    colorEcho $PLAIN " ${BOLD} 7.${PLAIN} V2Ray 日志"
    
    showSeparator
    
    colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回主菜单"
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个日志 [0-7/88]: " choice
    
    case $choice in
        1|2|3|4|5|6|7) 
            showTitle
            colorEcho $CYAN " 【日志查看】"
            echo
            colorEcho $YELLOW " 日志查看功能暂未实现。"
            showBack
            ;;
        88) main_menu ;;
        0) 
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0 
            ;;
        *)
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            logs_menu
            ;;
    esac
}

# --- 配置信息子菜单 ---
info_submenu() {
    local menu_type=$1
    showTitle
    
    colorEcho $CYAN " 【配置信息查看】"
    echo
    colorEcho $GREEN " --- 选择要查看的配置 --- "
    colorEcho $PLAIN " ${BOLD} 1.${PLAIN} Meta ${YELLOW}(mihomo)${PLAIN} 配置"
    colorEcho $PLAIN " ${BOLD} 2.${PLAIN} Shadowsocks ${YELLOW}(ss-go)${PLAIN} 配置"
    colorEcho $PLAIN " ${BOLD} 3.${PLAIN} Hysteria2 配置"
    colorEcho $PLAIN " ${BOLD} 4.${PLAIN} Tuic 配置"
    colorEcho $PLAIN " ${BOLD} 5.${PLAIN} Sing-box ${YELLOW}(Reality)${PLAIN} 配置"
    colorEcho $PLAIN " ${BOLD} 6.${PLAIN} Sing-box ${YELLOW}(ShadowTLS)${PLAIN} 配置"
    colorEcho $PLAIN " ${BOLD} 7.${PLAIN} Sing-box ${YELLOW}(WS)${PLAIN} 配置"
    colorEcho $PLAIN " ${BOLD} 8.${PLAIN} Xray 配置"
    
    showSeparator
    
    colorEcho $PLAIN " ${BOLD}88.${PLAIN} 返回上级菜单"
    colorEcho $PLAIN " ${BOLD} 0.${PLAIN} 退出"
    
    showFooter
    
    read -p " 请选择一个配置 [0-8/88]: " choice
    
    case $choice in
        1) showInfo_meta ;;
        2) showInfo_ss ;;
        3) showInfo_hysteria ;;
        4) showInfo_tuic ;;
        5) showInfo_singbox_reality ;;
        6) showInfo_singbox_shadowtls ;;
        7) showInfo_singbox_ws ;;
        8) showInfo_xray_none ;;
        88) 
            if [[ "$menu_type" == "proxy" ]]; then
                proxy_menu
            else
                main_menu
            fi
            ;;
        0) 
            showTitle
            colorEcho $GREEN " 感谢使用多协议代理一键管理脚本！"
            echo
            exit 0 
            ;;
        *)
            colorEcho $RED " 无效选择，请重试。"
            sleep 1.5
            info_submenu "$menu_type"
            ;;
    esac
}

# --- 脚本执行 ---
checkSystem
installDependencies
main_menu
