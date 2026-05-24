#!/bin/sh
#===========================================================
# 小米AX3000T 校园网自动登录脚本 (原厂固件)
# 请先通过抓包修改以下 [ ] 包围的参数
#===========================================================

# ---------- 必须修改的参数 ----------
AUTH_HOST="[认证服务器IP]"
LOGIN_BASE="http://[认证服务器IP]:[端口]"
LOGIN_PATH="/[认证路径]"
USER_ACCOUNT="[学号]"
USER_PASSWORD="[校园网密码]"
AC_IP="[AC地址]"
SUCCESS_STRING="[登录成功关键词]"
WAN_IF="eth0.1"                                 # AX3000T固定WAN口后通常为 eth0.1
LOG_FILE="/data/auto_login.log"
STATE_FILE="/data/check_net_state"
LOCK_FILE="/data/check_net.lock"
# ------------------------------------

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOG_FILE; }
timestamp() { date '+%Y-%m-%d %H:%M'; }
random_mac() { printf "00:11:22:%02X:%02X:%02X" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)); }
get_ip() { ifconfig $WAN_IF 2>/dev/null | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}'; }
get_mac() { ifconfig $WAN_IF 2>/dev/null | grep 'HWaddr' | awk '{print $5}' | tr -d ':'; }

check_online() {
    curl -s --connect-timeout 5 --max-time 5 "http://www.baidu.com" | grep -q "baidu"
}

read_state() { [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "init|0|0|"; }
save_state() { echo "$1|$2|$3|$4" > "$STATE_FILE"; }
ts2str() { date -d @$1 '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown"; }

# ---------- 主流程 ----------
[ -e $LOCK_FILE ] && exit 0
touch $LOCK_FILE
trap "rm -f $LOCK_FILE" EXIT

OLD_STATE=$(read_state)
OLD_TYPE=$(echo "$OLD_STATE" | cut -d'|' -f1)
OLD_START=$(echo "$OLD_STATE" | cut -d'|' -f2)
OLD_COUNT=$(echo "$OLD_STATE" | cut -d'|' -f3)
OLD_CAUSE=$(echo "$OLD_STATE" | cut -d'|' -f4)
NOW=$(date +%s)

if check_online; then CURRENT_TYPE="online"; else CURRENT_TYPE="offline"; fi

if [ "$OLD_TYPE" = "init" ] || [ "$OLD_START" = "0" ]; then
    log "$(timestamp) 守护进程启动，当前状态：$CURRENT_TYPE"
    save_state "$CURRENT_TYPE" "$NOW" "1" ""
    exit 0
fi

if [ "$CURRENT_TYPE" = "$OLD_TYPE" ]; then
    NEW_COUNT=$((OLD_COUNT + 1))
    save_state "$CURRENT_TYPE" "$OLD_START" "$NEW_COUNT" "$OLD_CAUSE"
    if [ "$CURRENT_TYPE" = "offline" ] && [ $((NEW_COUNT % 10)) -eq 0 ]; then
        log "[预警] 已连续异常 ${NEW_COUNT} 次"
    fi
    exit 0
fi

OLD_START_STR=$(ts2str $OLD_START)
NOW_STR=$(timestamp)
if [ "$OLD_TYPE" = "online" ] && [ "$OLD_COUNT" -gt 0 ]; then
    log "${OLD_START_STR} 至 ${NOW_STR} 网络已认证，无需重连。"
elif [ "$OLD_TYPE" = "offline" ] && [ "$OLD_COUNT" -gt 0 ]; then
    if [ "$OLD_COUNT" -ge 10 ]; then
        log "[异常报告] ${OLD_START_STR} 至 ${NOW_STR} 连续异常 ${OLD_COUNT} 次，原因：${OLD_CAUSE}。"
    else
        log "${OLD_START_STR} 至 ${NOW_STR} 检测到认证失效，共 ${OLD_COUNT} 次。"
    fi
fi

if [ "$CURRENT_TYPE" = "online" ]; then
    save_state "online" "$NOW" "1" ""
    exit 0
fi

# 修改 MAC 并强制重启（原厂固件接口操作受限，重启最可靠）
log "${NOW_STR} 检测到认证失效，修改MAC并强制重启..."
uci set network.wan.macaddr="$(random_mac)"
uci commit network
save_state "offline" "$NOW" "1" "修改MAC并重启"
sync
/sbin/reboot -f 2>/dev/null || busybox reboot -f 2>/dev/null || echo b > /proc/sysrq-trigger