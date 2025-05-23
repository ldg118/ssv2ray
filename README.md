# V2Ray 一键安装脚本 & 管理脚本使用文档

## 1. 简介

V2Ray 一键安装脚本 & 管理脚本是一个功能全面的工具，用于简化 V2Ray 的安装、配置和管理过程。本脚本支持 Ubuntu、Debian 和 Alpine 系统，提供完整的中文界面，支持多种代理协议和传输方式，并具备丰富的配置管理功能。

### 主要特点

- **多系统兼容**：支持 Ubuntu、Debian 和 Alpine 系统
- **完整中文界面**：所有菜单和提示均为中文，操作简单直观
- **多协议支持**：支持 VMess、VLESS、Trojan 和 Shadowsocks 协议
- **多传输方式**：支持 TCP、WebSocket、HTTP/2、gRPC、mKCP、QUIC 等传输方式
- **TLS 支持**：自动配置 TLS 证书，提升安全性
- **配置管理**：支持添加、修改、删除和导出配置
- **一键导出**：支持导出为 URL 链接、二维码和客户端配置文件
- **参数修改**：支持修改端口、UUID、密码、路径等参数
- **服务管理**：支持启动、停止、重启和查看服务状态
- **BBR 加速**：支持一键启用 BBR 加速
- **多源下载**：支持从多个镜像源下载，提高安装成功率

## 2. 安装指南

### 2.1 系统要求

- 操作系统：Ubuntu 16.04+、Debian 9+、Alpine 3.15+
- 内存：至少 128MB
- 硬盘：至少 300MB 可用空间
- 网络：可访问互联网
- 权限：root 用户或具有 sudo 权限的用户

### 2.2 安装步骤

1. 以 root 用户登录服务器（如果不是 root 用户，请先执行 `sudo -i` 切换到 root 用户）

2. 下载并执行安装脚本：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/user/v2ray_script/master/install.sh && chmod +x install.sh && bash install.sh
```

3. 安装完成后，可以通过以下命令进入管理菜单：

```bash
v2ray
```

### 2.3 快速安装 V2Ray

如果您希望直接安装 V2Ray，可以执行：

```bash
v2ray install
```

### 2.4 手动安装（如果自动安装失败）

如果自动安装失败，您可以尝试手动安装：

1. 创建临时目录：
```bash
mkdir -p /tmp/v2ray_install
```

2. 手动下载 V2Ray（选择适合您系统架构的版本）：
```bash
# 64位系统
curl -L -o /tmp/v2ray_install/v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip

# ARM64系统
curl -L -o /tmp/v2ray_install/v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-arm64-v8a.zip
```

3. 解压文件：
```bash
unzip -o /tmp/v2ray_install/v2ray.zip -d /tmp/v2ray_install
```

4. 安装 V2Ray：
```bash
mkdir -p /usr/local/bin /usr/local/etc/v2ray /var/log/v2ray
cp /tmp/v2ray_install/v2ray /usr/local/bin/
cp /tmp/v2ray_install/geoip.dat /usr/local/bin/ 2>/dev/null || true
cp /tmp/v2ray_install/geosite.dat /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/v2ray
```

5. 清理临时文件：
```bash
rm -rf /tmp/v2ray_install
```

6. 继续使用脚本配置 V2Ray：
```bash
v2ray
```

## 3. 使用指南

### 3.1 主菜单

执行 `v2ray` 命令后，您将看到以下主菜单：

```
==========================================================
                V2Ray 一键安装脚本 & 管理脚本
==========================================================
  1. 安装 V2Ray
  2. 卸载 V2Ray
  3. 添加配置
  4. 修改配置
  5. 删除配置
  6. 查看配置
  7. 查看配置详情
  8. 导出配置
  9. 查看状态
 10. 启动服务
 11. 停止服务
 12. 重启服务
 13. 更新 V2Ray
 14. 设置
  0. 退出
==========================================================
请选择：
```

### 3.2 安装 V2Ray

选择菜单中的 `1. 安装 V2Ray` 或执行 `v2ray install` 命令，脚本将自动安装 V2Ray 并创建一个默认的 VMess-TCP 配置。

安装完成后，脚本会显示配置信息和 VMess 链接，您可以使用该链接在客户端中添加配置。

#### 安装故障排除

如果安装过程中遇到下载失败的问题，脚本会自动尝试从多个镜像源下载。如果所有源都失败，您可以：

1. 检查网络连接
2. 尝试使用代理或VPN
3. 按照"手动安装"部分的步骤进行安装
4. 如果您的服务器位于中国大陆，可能需要使用国内镜像源

### 3.3 添加配置

选择菜单中的 `3. 添加配置` 或执行 `v2ray add` 命令，您将看到协议选择菜单：

```
请选择协议：
  1. VMess 协议
  2. VLESS 协议
  3. Trojan 协议
  4. Shadowsocks 协议
==========================================================
请选择：
```

选择协议后，您将看到传输方式选择菜单：

```
请选择传输方式：
  1. TCP 传输
  2. WebSocket 传输
  3. HTTP/2 传输
  4. gRPC 传输
  5. mKCP 传输
  6. QUIC 传输
==========================================================
请选择：
```

根据选择的协议和传输方式，脚本会引导您设置相关参数，如端口、UUID、密码、路径等。

对于需要 TLS 的传输方式（如 WebSocket + TLS），您需要提供一个已解析到服务器 IP 的域名，脚本会自动配置 TLS 证书。

配置添加完成后，脚本会显示配置信息和对应的链接，您可以使用该链接在客户端中添加配置。

### 3.4 修改配置

选择菜单中的 `4. 修改配置` 或执行 `v2ray modify` 命令，您将看到配置列表：

```
配置列表：
1. vmess-tcp (10086)
2. vmess-ws-tls (example.com:443)
==========================================================
请选择：
```

选择要修改的配置后，您将看到参数选择菜单：

```
请选择要修改的参数：
  1. 端口
  2. UUID / 密码
  3. 路径
  4. 域名
  5. 加密方式
  0. 返回
==========================================================
请选择：
```

根据选择的参数，脚本会引导您设置新的值。修改完成后，脚本会自动应用新配置并重启服务。

### 3.5 查看配置

选择菜单中的 `6. 查看配置` 或执行 `v2ray list` 命令，脚本会显示所有配置的列表：

```
配置列表：
1. vmess-tcp (10086)
2. vmess-ws-tls (example.com:443)
```

### 3.6 查看配置详情

选择菜单中的 `7. 查看配置详情` 或执行 `v2ray info` 命令，您需要先从配置列表中选择一个配置，然后脚本会显示该配置的详细信息：

```
==========================================================
                  配置详情：vmess-ws-tls
==========================================================
协议：vmess
传输：ws
TLS：true
端口：443
UUID：05aa1c8d-8a6f-4e1a-b3b7-740e1a7f45f7
域名：example.com
路径：/ws
创建时间：2025-05-21 17:30:00
更新时间：2025-05-21 17:30:00
==========================================================
VMess 链接：vmess://eyJhZGQiOiJleGFtcGxlLmNvbSIsImFpZCI6IjAiLCJob3N0IjoiZXhhbXBsZS5jb20iLCJpZCI6IjA1YWExYzhkLThhNmYtNGUxYS1iM2I3LTc0MGUxYTdmNDVmNyIsIm5ldCI6IndzIiwicGF0aCI6Ii93cyIsInBvcnQiOiI0NDMiLCJwcyI6InZtZXNzLXdzLXRscyIsInRscyI6InRscyIsInR5cGUiOiJub25lIiwidiI6IjIifQ==
==========================================================
```

### 3.7 导出配置

选择菜单中的 `8. 导出配置` 或执行 `v2ray export` 命令，您需要先从配置列表中选择一个配置，然后选择导出格式：

```
请选择导出格式：
  1. URL 链接
  2. 二维码
  3. 客户端配置
==========================================================
请选择：
```

根据选择的格式，脚本会生成相应的导出内容：

- URL 链接：显示可直接导入客户端的链接
- 二维码：生成包含链接的二维码图片
- 客户端配置：生成客户端使用的 JSON 配置文件

### 3.8 删除配置

选择菜单中的 `5. 删除配置` 或执行 `v2ray delete` 命令，您需要先从配置列表中选择一个配置，然后确认删除操作。

### 3.9 服务管理

- **启动服务**：选择菜单中的 `10. 启动服务` 或执行 `v2ray start` 命令
- **停止服务**：选择菜单中的 `11. 停止服务` 或执行 `v2ray stop` 命令
- **重启服务**：选择菜单中的 `12. 重启服务` 或执行 `v2ray restart` 命令
- **查看状态**：选择菜单中的 `9. 查看状态` 或执行 `v2ray status` 命令

### 3.10 更新 V2Ray

选择菜单中的 `13. 更新 V2Ray` 或执行 `v2ray update` 命令，脚本会自动下载并安装最新版本的 V2Ray，同时保留现有配置。

如果更新过程中遇到下载失败的问题，脚本会自动尝试从多个镜像源下载。

### 3.11 设置

选择菜单中的 `14. 设置`，您将看到设置菜单：

```
设置
  1. 语言设置
  2. BBR
  3. 屏蔽 BT
  4. 屏蔽中国 IP
  0. 返回
==========================================================
请选择：
```

- **语言设置**：目前仅支持简体中文
- **BBR**：启用 BBR 加速（需要内核支持）
- **屏蔽 BT**：启用 BT 下载屏蔽
- **屏蔽中国 IP**：启用中国 IP 屏蔽

### 3.12 卸载 V2Ray

选择菜单中的 `2. 卸载 V2Ray` 或执行 `v2ray uninstall` 命令，脚本会停止服务并删除所有 V2Ray 相关文件。

## 4. 命令行参数

脚本支持以下命令行参数：

```
用法: v2ray [命令] [选项]

命令:
  install         安装 V2Ray
  uninstall       卸载 V2Ray
  add             添加配置
  modify          修改配置
  delete          删除配置
  list            列出所有配置
  info            查看配置详情
  export          导出配置
  start           启动服务
  stop            停止服务
  restart         重启服务
  status          查看服务状态
  update          更新 V2Ray
  help            显示帮助信息
  version         显示版本信息

示例:
  v2ray install      安装 V2Ray
  v2ray add          添加配置
  v2ray info         查看配置详情
```

## 5. 常见问题

### 5.1 安装失败

**问题**：执行安装命令后提示安装失败。

**解决方案**：
1. 确保您使用的是 root 用户或具有 sudo 权限的用户
2. 检查服务器是否能够访问互联网
3. 检查服务器的防火墙设置，确保不会阻止脚本下载和安装过程
4. 尝试手动安装依赖：`apt update && apt install -y curl wget unzip` 或 `apk update && apk add curl wget unzip`
5. 如果下载 V2Ray 失败，可以尝试手动下载并安装，详见"手动安装"部分

### 5.2 下载 V2Ray 失败

**问题**：安装过程中提示"下载 V2Ray 失败"。

**解决方案**：
1. 脚本会自动尝试从多个镜像源下载，如果仍然失败，可能是网络问题
2. 如果您的服务器位于中国大陆，可能需要使用代理或VPN
3. 尝试手动下载 V2Ray 并放置在临时目录中：
   ```bash
   mkdir -p /tmp/v2ray_install
   # 使用代理或其他方式下载 V2Ray
   # 将下载的文件重命名为 v2ray.zip 并放置在 /tmp/v2ray_install 目录中
   # 然后重新运行安装脚本
   ```
4. 如果以上方法都不行，请参考"手动安装"部分的步骤

### 5.3 无法连接

**问题**：V2Ray 安装成功，但客户端无法连接。

**解决方案**：
1. 检查服务器防火墙是否开放了对应端口
2. 使用 `v2ray status` 命令检查 V2Ray 服务是否正在运行
3. 使用 `netstat -tuln | grep <端口>` 命令检查端口是否被监听
4. 检查客户端配置是否与服务器配置一致
5. 如果使用 TLS，检查域名是否正确解析到服务器 IP

### 5.4 TLS 证书配置失败

**问题**：添加需要 TLS 的配置时，证书配置失败。

**解决方案**：
1. 确保域名已正确解析到服务器 IP
2. 确保服务器的 80 和 443 端口未被占用
3. 检查是否安装了 certbot：`apt install -y certbot` 或 `apk add certbot`
4. 手动获取证书：`certbot certonly --standalone --agree-tos --email admin@example.com -d example.com`

### 5.5 BBR 启用失败

**问题**：尝试启用 BBR 时失败。

**解决方案**：
1. 检查内核版本是否支持 BBR（需要 4.9 或更高版本）：`uname -r`
2. 如果内核版本过低，需要先升级内核
3. 手动启用 BBR：
   ```bash
   echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
   echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
   sysctl -p
   ```

### 5.6 Alpine 系统特殊问题

**问题**：在 Alpine 系统上安装或使用时遇到问题。

**解决方案**：
1. 确保已启用 Community 源：编辑 `/etc/apk/repositories` 文件，取消注释 Community 源
2. 更新软件包索引：`apk update`
3. 安装必要依赖：`apk add curl wget unzip openssl ca-certificates`
4. 如果服务管理有问题，检查 OpenRC 服务：`rc-status`

### 5.7 脚本下载失败

**问题**：安装脚本本身下载失败。

**解决方案**：
1. 脚本会自动尝试从多个镜像源下载，如果仍然失败，可能是网络问题
2. 尝试使用其他下载工具：
   ```bash
   curl -O https://raw.githubusercontent.com/user/v2ray_script/master/install.sh
   ```
3. 如果您的服务器位于中国大陆，可能需要使用代理或VPN
4. 尝试手动下载脚本并上传到服务器

## 6. 安全建议

1. **定期更新**：使用 `v2ray update` 命令定期更新 V2Ray 核心，以获取最新的安全修复
2. **使用 TLS**：尽可能使用带有 TLS 的传输方式，如 WebSocket + TLS、HTTP/2 + TLS 或 gRPC + TLS
3. **更改默认端口**：避免使用默认端口，以减少被检测的风险
4. **启用 BBR**：启用 BBR 可以提高网络性能
5. **设置防火墙**：只开放必要的端口，限制 IP 访问
6. **定期更换 UUID/密码**：定期使用 `v2ray modify` 命令更换 UUID 或密码
7. **监控日志**：定期检查 V2Ray 日志，位于 `/var/log/v2ray/` 目录

## 7. 客户端配置

本脚本生成的配置可以在多种客户端中使用：

### 7.1 Windows 客户端

- **V2RayN**：支持导入 VMess、VLESS、Trojan 和 Shadowsocks 链接
- **Qv2ray**：支持导入客户端配置文件

### 7.2 macOS 客户端

- **V2RayX**：支持导入客户端配置文件
- **ClashX**：支持导入 VMess、VLESS、Trojan 和 Shadowsocks 链接

### 7.3 Android 客户端

- **V2RayNG**：支持扫描二维码或导入链接
- **Clash for Android**：支持导入链接

### 7.4 iOS 客户端

- **Shadowrocket**：支持扫描二维码或导入链接
- **Quantumult X**：支持导入链接

## 8. 脚本更新与维护

本脚本会定期更新以支持最新的 V2Ray 功能和修复问题。您可以通过以下方式获取更新：

1. 重新下载并执行安装脚本
2. 关注项目 GitHub 页面获取最新版本

## 9. 贡献与反馈

如果您发现任何问题或有改进建议，请通过以下方式提供反馈：

1. 在 GitHub 项目页面提交 Issue
2. 提交 Pull Request 贡献代码
3. 发送邮件至维护者邮箱

感谢您使用 V2Ray 一键安装脚本 & 管理脚本！
