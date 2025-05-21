#!/bin/bash
#
# V2Ray 一键安装脚本 & 管理脚本
# 安装入口脚本 - 增强版
#

# 脚本版本
VERSION="1.0.1"

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo "错误：请使用 root 用户运行此脚本"
    exit 1
fi

# 下载脚本 - 增强版，支持多源下载
download_script() {
    echo "正在下载 V2Ray 一键安装脚本..."
    
    # 创建目录
    mkdir -p /usr/local/v2ray_script
    
    # 定义下载源列表
    local github_url="https://raw.githubusercontent.com/user/v2ray_script/master"
    local fastgit_url="https://raw.fastgit.org/user/v2ray_script/master"
    local jsdelivr_url="https://cdn.jsdelivr.net/gh/user/v2ray_script@master"
    
    # 下载函数，支持多源和重试
    download_file() {
        local file_path=$1
        local output_path=$2
        local max_retries=3
        local retry_count=0
        local download_success=false
        
        # 尝试从多个源下载
        for base_url in "$github_url" "$fastgit_url" "$jsdelivr_url"; do
            retry_count=0
            while [ $retry_count -lt $max_retries ]; do
                echo "尝试从 $base_url 下载 $file_path..."
                if curl -L -o "$output_path" "$base_url/$file_path" --connect-timeout 10 --retry 3 --silent --show-error; then
                    download_success=true
                    echo "下载成功：$file_path"
                    break
                else
                    retry_count=$((retry_count + 1))
                    echo "下载失败，尝试第 $retry_count 次重试..."
                    sleep 2
                fi
            done
            
            if [ "$download_success" = true ]; then
                break
            fi
        done
        
        # 检查下载结果
        if [ "$download_success" != true ]; then
            echo "所有源均无法下载 $file_path，请检查网络连接"
            return 1
        fi
        
        return 0
    }
    
    # 下载主脚本
    download_file "v2ray.sh" "/usr/local/v2ray_script/v2ray.sh" || return 1
    
    # 创建目录结构
    mkdir -p /usr/local/v2ray_script/src
    mkdir -p /usr/local/v2ray_script/data/i18n
    mkdir -p /usr/local/v2ray_script/data/config
    mkdir -p /usr/local/v2ray_script/data/templates
    
    # 下载模块
    download_file "src/i18n.sh" "/usr/local/v2ray_script/src/i18n.sh" || return 1
    download_file "src/utils.sh" "/usr/local/v2ray_script/src/utils.sh" || return 1
    download_file "src/system.sh" "/usr/local/v2ray_script/src/system.sh" || return 1
    download_file "src/install.sh" "/usr/local/v2ray_script/src/install.sh" || return 1
    download_file "src/config.sh" "/usr/local/v2ray_script/src/config.sh" || return 1
    
    # 下载语言文件
    download_file "data/i18n/zh_CN.sh" "/usr/local/v2ray_script/data/i18n/zh_CN.sh" || return 1
    
    # 设置权限
    chmod +x /usr/local/v2ray_script/v2ray.sh
    chmod +x /usr/local/v2ray_script/src/*.sh
    
    # 创建符号链接
    ln -sf /usr/local/v2ray_script/v2ray.sh /usr/local/bin/v2ray
    
    echo "下载完成！"
    return 0
}

# 本地安装
local_install() {
    echo "正在安装 V2Ray 一键安装脚本..."
    
    # 创建目录
    mkdir -p /usr/local/v2ray_script
    
    # 复制文件
    cp -r ./* /usr/local/v2ray_script/
    
    # 设置权限
    chmod +x /usr/local/v2ray_script/v2ray.sh
    chmod +x /usr/local/v2ray_script/src/*.sh
    
    # 创建符号链接
    ln -sf /usr/local/v2ray_script/v2ray.sh /usr/local/bin/v2ray
    
    echo "安装完成！"
    return 0
}

# 主函数
main() {
    echo "欢迎使用 V2Ray 一键安装脚本 & 管理脚本 v$VERSION"
    
    # 检查是否为本地安装
    if [[ -f "./v2ray.sh" && -d "./src" ]]; then
        local_install
    else
        if ! download_script; then
            echo "脚本下载失败，请检查网络连接或尝试手动安装"
            exit 1
        fi
    fi
    
    echo "您现在可以使用以下命令管理 V2Ray："
    echo "v2ray              - 显示管理菜单"
    echo "v2ray install      - 安装 V2Ray"
    echo "v2ray add          - 添加配置"
    echo "v2ray help         - 显示帮助信息"
    
    # 询问是否立即安装 V2Ray
    read -p "是否现在安装 V2Ray？(y/n): " choice
    case "$choice" in
        [Yy]|[Yy][Ee][Ss])
            /usr/local/bin/v2ray install
            ;;
        *)
            echo "您可以稍后运行 'v2ray install' 来安装 V2Ray"
            ;;
    esac
}

# 执行主函数
main
