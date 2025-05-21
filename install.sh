#!/bin/bash
#
# V2Ray 一键安装脚本 & 管理脚本
# 安装入口脚本
#

# 脚本版本
VERSION="1.0.0"

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo "错误：请使用 root 用户运行此脚本"
    exit 1
fi

# 下载脚本
download_script() {
    echo "正在下载 V2Ray 一键安装脚本..."
    
    # 创建目录
    mkdir -p /usr/local/v2ray_script
    
    # 下载主脚本
    curl -L -o /usr/local/v2ray_script/v2ray.sh https://raw.githubusercontent.com/user/v2ray_script/master/v2ray.sh
    
    # 下载模块
    mkdir -p /usr/local/v2ray_script/src
    curl -L -o /usr/local/v2ray_script/src/i18n.sh https://raw.githubusercontent.com/user/v2ray_script/master/src/i18n.sh
    curl -L -o /usr/local/v2ray_script/src/utils.sh https://raw.githubusercontent.com/user/v2ray_script/master/src/utils.sh
    curl -L -o /usr/local/v2ray_script/src/system.sh https://raw.githubusercontent.com/user/v2ray_script/master/src/system.sh
    curl -L -o /usr/local/v2ray_script/src/install.sh https://raw.githubusercontent.com/user/v2ray_script/master/src/install.sh
    curl -L -o /usr/local/v2ray_script/src/config.sh https://raw.githubusercontent.com/user/v2ray_script/master/src/config.sh
    
    # 创建数据目录
    mkdir -p /usr/local/v2ray_script/data/i18n
    mkdir -p /usr/local/v2ray_script/data/config
    mkdir -p /usr/local/v2ray_script/data/templates
    
    # 下载语言文件
    curl -L -o /usr/local/v2ray_script/data/i18n/zh_CN.sh https://raw.githubusercontent.com/user/v2ray_script/master/data/i18n/zh_CN.sh
    
    # 设置权限
    chmod +x /usr/local/v2ray_script/v2ray.sh
    chmod +x /usr/local/v2ray_script/src/*.sh
    
    # 创建符号链接
    ln -sf /usr/local/v2ray_script/v2ray.sh /usr/local/bin/v2ray
    
    echo "下载完成！"
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
}

# 主函数
main() {
    echo "欢迎使用 V2Ray 一键安装脚本 & 管理脚本 v$VERSION"
    
    # 检查是否为本地安装
    if [[ -f "./v2ray.sh" && -d "./src" ]]; then
        local_install
    else
        download_script
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
