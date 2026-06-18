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
##📦 小米 AX3000T 部署 (原厂固件，需已开启 SSH)
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