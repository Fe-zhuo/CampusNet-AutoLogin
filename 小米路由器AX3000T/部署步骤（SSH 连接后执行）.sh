# 1. 写入脚本
cat > /data/check_net.sh << 'EOF'
... 将上面完整的脚本内容粘贴进来 ...
EOF
chmod +x /data/check_net.sh

# 2. 创建开机自启服务
cat > /etc/init.d/auto_login << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    (sleep 40; /data/check_net.sh) &
}
EOF
chmod +x /etc/init.d/auto_login
/etc/init.d/auto_login enable

# 3. 定时任务兜底
echo "*/15 * * * * /data/check_net.sh" >> /etc/crontabs/root
/etc/init.d/cron restart

# 4. 可选：日志清理
cat > /data/clean_log.sh << 'EOF'
#!/bin/sh
LOG_FILE="/data/auto_login.log"
MAX_LINES=500
if [ -f "$LOG_FILE" ]; then
    tail -n $MAX_LINES $LOG_FILE > /tmp/auto_login.tmp
    mv /tmp/auto_login.tmp $LOG_FILE
    echo "$(date '+%Y-%m-%d %H:%M:%S') 日志已清理。" >> $LOG_FILE
fi
EOF
chmod +x /data/clean_log.sh
echo "0 3 1 * * /data/clean_log.sh" >> /etc/crontabs/root
/etc/init.d/cron restart