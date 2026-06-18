# 🛡️ CampusNet-AutoLogin

> 专为 **G.D.U.F.** 等高校 `10.82.0.0/16` 网段 Dr.COM 认证设计的全自动不掉线脚本。  
> 支持小米路由器 4C (OpenWrt/Kwrt) 与 AX3000T (原厂固件)，自动修改 MAC 并重新登录，附带多设备共享防检测方案。

[![Platform](https://img.shields.io/badge/platform-OpenWrt%20%7C%20Xiaomi%20Stock-blue)](https://github.com/yourname/campusnet-autologin)
[![License](https://img.shields.io/github/license/yourname/campusnet-autologin)](https://github.com/yourname/campusnet-autologin)

## ✨ 特性

- **智能检测**：通过百度可达性双重判断，避免误判。
- **自动修复**：断网时使用固定备选 MAC 重新认证，**不再随机更换 MAC**，防止被校园网标记为“共享行为”。
- **无锁文件设计 (AX3000T)**：使用进程检测防止并发，**永不卡死**，彻底告别锁文件残留问题。
- **合并日志**：仅记录状态变化，64 MB 内存设备常年运行不卡顿。
- **防死循环 (AX3000T)**：24 小时内最多重启 3 次，避免校园网瘫痪时无限重启。
- **多设备共享防检测**：内置 TTL 统一伪装方案，让路由器下多台设备流量看起来像同一台 Windows 电脑。

## ⚠️ 抓包准备 (必须)

部署前请通过浏览器获取你的校园网认证参数：

1. 连接校园网，**确保未登录**。
2. 浏览器打开认证页面，按 `F12` 打开开发者工具。
3. 切换到 **Network** 标签，勾选 **Preserve log**。
4. 输入账号密码登录，在请求列表过滤 `login` 或 `portal`。
5. 找到 `GET` 请求（通常含 `callback=dr1003`），复制完整 URL 和参数。
6. 将以下信息填入脚本对应变量：
   - `AUTH_HOST`：认证服务器 IP（如 `10.82.0.66`）
   - `LOGIN_BASE`：`http://认证IP:端口`
   - `LOGIN_PATH`：登录路径（如 `/eportal/portal/login`）
   - `USER_ACCOUNT`：学号（逗号 `,` 编码为 `%2C`）
   - `USER_PASSWORD`：密码
   - `AC_IP`：AC 地址（参数中的 `wlan_ac_ip`）
   - `SUCCESS_STRING`：登录成功关键词（如 `Portal协议认证成功！`）

## 📦 小米 4C 部署 (OpenWrt / Kwrt)

1. 将 `mi4c_check_net.sh` 上传至 `/root/check_net.sh` 并赋予执行权限：
   ```bash
   chmod +x /root/check_net.sh
添加定时任务（每 15 分钟）：

bash
echo "*/15 * * * * /root/check_net.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
(可选) 日志清理脚本：

bash
cat > /root/clean_log.sh << 'EOF'
#!/bin/sh
LOG_FILE="/var/log/auto_login.log"
MAX_LINES=500
if [ -f "$LOG_FILE" ]; then
    tail -n $MAX_LINES $LOG_FILE > /tmp/auto_login.tmp
    mv /tmp/auto_login.tmp $LOG_FILE
    echo "$(date '+%Y-%m-%d %H:%M:%S') 日志已清理。" >> $LOG_FILE
fi
EOF
chmod +x /root/clean_log.sh
echo "0 3 1 * * /root/clean_log.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
📦 小米 AX3000T 部署 (原厂固件，需已开启 SSH)
前提：已通过工具（如 XMiR-Patcher）解锁并固化 SSH，且在路由器后台 固定 WAN 口（避免接口名变动）。

将 ax3000t_check_net.sh 上传至 /data/check_net.sh 并赋权：

bash
chmod +x /data/check_net.sh
创建开机自启服务（同时包含 TTL 伪装规则）：

bash
cat > /etc/init.d/auto_login << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    # 多设备伪装：统一 TTL 为 128
    iptables -t mangle -F POSTROUTING
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set 128
    (sleep 40; /data/check_net.sh) &
}
EOF
chmod +x /etc/init.d/auto_login
/etc/init.d/auto_login enable
添加定时任务兜底：

bash
echo "*/30 * * * * /data/check_net.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
(可选) 日志清理（同 4C 逻辑，路径改为 /data）。

🧪 维护命令
操作	小米 4C	小米 AX3000T
查看日志	cat /var/log/auto_login.log	cat /data/auto_login.log
实时监控	tail -f /var/log/auto_login.log	tail -f /data/auto_login.log
手动触发修复	rm -f /tmp/check_net_state && /root/check_net.sh	rm -f /data/check_net_state && /data/check_net.sh
立即设置 TTL 伪装	无需（原生支持）	iptables -t mangle -A POSTROUTING -j TTL --ttl-set 128
💡 多设备共享防检测 (TTL 伪装)
如果你的校园网会在检测到多台设备同时上网时踢你下线，可以启用 TTL 统一伪装。
该功能在 AX3000T 的开机脚本中已自动包含，手动启用命令如下：

bash
iptables -t mangle -F POSTROUTING
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 128
将 128 改为 64 可伪装为 Linux/Android 设备；128 为 Windows 默认值，适合 Windows 主机较多的环境。

此规则重启后失效，请确保已加入开机脚本 /etc/init.d/auto_login。

❓ 常见问题
Q：脚本无反应？
A：AX3000T 使用进程检测防重复，无需手动清理锁文件。若卡死，直接再次运行即可。

Q：修改 MAC 后还是无法上网？
A：检查 WAN 口名称 (ifconfig 确认)，确保校园网端口支持 DHCP，并确认 MAC 池中的地址合法。

Q：我的认证请求是 POST 而不是 GET？
A：修改脚本中的 curl 行为 -d "参数" 的 POST 方式，参数从抓包 Payload 获取。