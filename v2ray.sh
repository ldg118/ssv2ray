#!/bin/bash
#
# V2Ray 一键安装脚本 & 管理脚本
# 主脚本
#

# 脚本版本
VERSION="1.0.0"

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$SCRIPT_DIR/src/i18n.sh"
source "$SCRIPT_DIR/src/utils.sh"
source "$SCRIPT_DIR/src/system.sh"
source "$SCRIPT_DIR/src/install.sh"
source "$SCRIPT_DIR/src/config.sh"

# 初始化
init() {
    # 检查是否为 root 用户
    check_root
    
    # 加载语言文件
    load_language "zh_CN"
    
    # 检测系统环境
    detect_os
}

# 显示帮助信息
show_help() {
    echo "V2Ray 一键安装脚本 & 管理脚本 v$VERSION"
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  install         安装 V2Ray"
    echo "  uninstall       卸载 V2Ray"
    echo "  add             添加配置"
    echo "  modify          修改配置"
    echo "  delete          删除配置"
    echo "  list            列出所有配置"
    echo "  info            查看配置详情"
    echo "  export          导出配置"
    echo "  start           启动服务"
    echo "  stop            停止服务"
    echo "  restart         重启服务"
    echo "  status          查看服务状态"
    echo "  update          更新 V2Ray"
    echo "  help            显示此帮助信息"
    echo "  version         显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0 install      安装 V2Ray"
    echo "  $0 add          添加配置"
    echo "  $0 info         查看配置详情"
    echo ""
    echo "更多信息请访问: https://github.com/v2fly/v2ray-core"
}

# 显示版本信息
show_version() {
    echo "V2Ray 一键安装脚本 & 管理脚本 v$VERSION"
}

# 主菜单
main_menu() {
    while true; do
        show_menu
        
        local choice=$(get_user_choice "" 14)
        
        case $choice in
            1)  # 安装 V2Ray
                install_v2ray
                press_any_key
                ;;
            2)  # 卸载 V2Ray
                uninstall_v2ray
                press_any_key
                ;;
            3)  # 添加配置
                add_config
                press_any_key
                ;;
            4)  # 修改配置
                modify_config
                press_any_key
                ;;
            5)  # 删除配置
                delete_config
                press_any_key
                ;;
            6)  # 查看配置
                echo "$(t CONFIG_LIST)"
                list_configs
                press_any_key
                ;;
            7)  # 查看配置详情
                local configs=$(list_configs)
                if [[ -z "$configs" ]]; then
                    echo "$(t CONFIG_EMPTY)"
                else
                    echo "$(t CONFIG_LIST)"
                    echo "$configs"
                    echo "=========================================================="
                    local config_count=$(echo "$configs" | wc -l)
                    local choice=$(get_user_choice "$(t PROMPT_SELECT)" $config_count)
                    local name=$(echo "$configs" | sed -n "${choice}p" | cut -d' ' -f1)
                    show_config_info "$name"
                fi
                press_any_key
                ;;
            8)  # 导出配置
                export_config
                press_any_key
                ;;
            9)  # 查看状态
                check_v2ray_status
                press_any_key
                ;;
            10) # 启动服务
                start_service "v2ray"
                press_any_key
                ;;
            11) # 停止服务
                stop_service "v2ray"
                press_any_key
                ;;
            12) # 重启服务
                restart_service "v2ray"
                press_any_key
                ;;
            13) # 更新 V2Ray
                update_v2ray
                press_any_key
                ;;
            14) # 设置
                settings_menu
                ;;
            0)  # 退出
                echo "$(t MSG_GOODBYE)"
                exit 0
                ;;
            *)
                echo "$(t MSG_INVALID_CHOICE)"
                press_any_key
                ;;
        esac
    done
}

# 设置菜单
settings_menu() {
    while true; do
        show_settings_menu
        
        local choice=$(get_user_choice "" 4)
        
        case $choice in
            1)  # 语言设置
                language_menu
                ;;
            2)  # BBR
                if is_bbr_enabled; then
                    echo "BBR 已启用"
                else
                    echo "正在启用 BBR..."
                    if enable_bbr; then
                        echo "BBR 启用成功"
                    else
                        echo "BBR 启用失败，内核版本可能不支持"
                    fi
                fi
                press_any_key
                ;;
            3)  # 屏蔽 BT
                echo "功能开发中..."
                press_any_key
                ;;
            4)  # 屏蔽中国 IP
                echo "功能开发中..."
                press_any_key
                ;;
            0)  # 返回
                return
                ;;
            *)
                echo "$(t MSG_INVALID_CHOICE)"
                press_any_key
                ;;
        esac
    done
}

# 语言菜单
language_menu() {
    show_language_menu
    
    local choice=$(get_user_choice "" 2)
    
    case $choice in
        1)  # 简体中文
            set_language "zh_CN"
            echo "语言已设置为简体中文"
            ;;
        2)  # 英文
            echo "暂不支持英文"
            ;;
        *)
            echo "$(t MSG_INVALID_CHOICE)"
            ;;
    esac
    
    press_any_key
}

# 命令行参数处理
process_args() {
    local command=$1
    shift
    
    case $command in
        install)
            install_v2ray
            ;;
        uninstall)
            uninstall_v2ray
            ;;
        add)
            add_config
            ;;
        modify)
            modify_config
            ;;
        delete)
            delete_config
            ;;
        list)
            echo "$(t CONFIG_LIST)"
            list_configs
            ;;
        info)
            if [[ -n "$1" ]]; then
                show_config_info "$1"
            else
                local configs=$(list_configs)
                if [[ -z "$configs" ]]; then
                    echo "$(t CONFIG_EMPTY)"
                else
                    echo "$(t CONFIG_LIST)"
                    echo "$configs"
                    echo "=========================================================="
                    local config_count=$(echo "$configs" | wc -l)
                    local choice=$(get_user_choice "$(t PROMPT_SELECT)" $config_count)
                    local name=$(echo "$configs" | sed -n "${choice}p" | cut -d' ' -f1)
                    show_config_info "$name"
                fi
            fi
            ;;
        export)
            export_config
            ;;
        start)
            start_service "v2ray"
            ;;
        stop)
            stop_service "v2ray"
            ;;
        restart)
            restart_service "v2ray"
            ;;
        status)
            check_v2ray_status
            ;;
        update)
            update_v2ray
            ;;
        help)
            show_help
            ;;
        version)
            show_version
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 主函数
main() {
    # 初始化
    init
    
    # 显示欢迎信息
    echo "$(t MSG_WELCOME)"
    
    # 处理命令行参数
    if [[ $# -gt 0 ]]; then
        process_args "$@"
    else
        # 显示主菜单
        main_menu
    fi
}

# 执行主函数
main "$@"
