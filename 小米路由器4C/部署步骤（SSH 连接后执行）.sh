# 上传脚本（用 MobaXterm 拖拽或直接粘贴）
cat > /root/check_net.sh << 'EOF'
... 将上面完整的脚本内容粘贴进来 ...
EOF
chmod +x /root/check_net.sh

# 定时任务，每15分钟检查
crontab -e
# 按 i，添加一行：
*/15 * * * * /root/check_net.sh
# 按 Esc，输入 :wq 保存

# 可选：日志清理（每月清理一次）
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
(crontab -l 2>/dev/null; echo "0 3 1 * * /root/clean_log.sh") | crontab -