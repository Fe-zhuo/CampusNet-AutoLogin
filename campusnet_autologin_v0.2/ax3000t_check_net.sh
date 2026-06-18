#!/bin/sh
#===========================================================
# 小米AX3000T 校园网自动登录脚本 (原厂固件)
# 请先通过抓包修改以下 [ ] 包围的参数
# 使用进程检测防重复，永不卡锁
#===========================================================

# ---------- 必须修改的参数 ----------
AUTH_HOST="[认证服务器IP]"
LOGIN_BASE="http://[认证服务器IP]:[端口]"
LOGIN_PATH="/[认证路径]"
USER_ACCOUNT="[学号]"
USER_PASSWORD="[校园网密码]"
AC_IP="[AC地址]"
SUCCESS_STRING="[登录成功关键词]"
WAN_IF="eth0.1"                                 # 固定WAN口后通常为 eth0.1
LOG_FILE="/data/auto_login.log"
STATE_FILE="/data/check_net_state"

# ---------- 固定备选 MAC 池 ----------
# 建议 MAC1 填写当前 WAN 口真实 MAC，MAC2 为其变体
MAC1="[你的真实MAC]"                             # 查看命令：ifconfig eth0.1 | grep HWaddr
MAC2="[备选MAC]"                                 # 修改 MAC1 的最后一位
MAC_POOL="$MAC1 $MAC2"
MAC_IDX_FILE="/data/mac_idx"
# ------------------------------------

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOG_FILE; }
timestamp() { date '+%Y-%m-%d %H:%M'; }

get_next_mac() {
    idx=$(cat "$MAC_IDX_FILE" 2>/dev/null || echo 0)
    set -- $MAC_POOL
    if [ "$idx" = "0" ]; then
        echo "$MAC1"
        echo 1 > "$MAC_IDX_FILE"
    else
        echo "$MAC2"
        echo 0 > "$MAC_IDX_FILE"
    fi
}

get_ip() { ifconfig $WAN_IF 2>/dev/null | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}'; }
get_mac() { ifconfig $WAN_IF 2>/dev/null | grep 'HWaddr' | awk '{print $5}' | tr -d ':'; }

check_online() {
    curl -s --connect-timeout 5 --max-time 5 "http://www.baidu.com" | grep -q "baidu"
}

read_state() { [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "init|0|0|"; }
save_state() { echo "$1|$2|$3|$4" > "$STATE_FILE"; }
ts2str() { date -d @$1 '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown"; }

# ========== 防重复运行 (进程检测，无文件锁) ==========
MY_PID=$$
if ps | grep check_net.sh | grep -v grep | grep -v "$MY_PID" | grep -q check_net; then
    exit 0
fi

# ========== 主流程 ==========
OLD_STATE=$(read_state)
OLD_TYPE=$(echo "$OLD_STATE" | cut -d'|' -f1)
OLD_START=$(echo "$OLD_STATE" | cut -d'|' -f2)
OLD_COUNT=$(echo "$OLD_STATE" | cut -d'|' -f3)
OLD_CAUSE=$(echo "$OLD_STATE" | cut -d'|' -f4)
NOW=$(date +%s)

if check_online; then CURRENT_TYPE="online"; else CURRENT_TYPE="offline"; fi

if [ "$OLD_TYPE" = "init" ] || [ "$OLD_START" = "0" ] || [ ! -f "$STATE_FILE" ]; then
    log "$(timestamp) 守护进程启动，当前状态：$CURRENT_TYPE"
    save_state "$CURRENT_TYPE" "$NOW" "1" ""
    if [ "$CURRENT_TYPE" = "offline" ]; then
        log "检测到初始网络异常，立即修复..."
    else
        exit 0
    fi
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

log "${NOW_STR} 检测到认证失效，使用固定备选MAC修复..."
NEW_MAC=$(get_next_mac)
ifconfig $WAN_IF down
ifconfig $WAN_IF hw ether $NEW_MAC
ifconfig $WAN_IF up
sleep 5

IP=$(get_ip)
if [ -z "$IP" ]; then
    sleep 10
    IP=$(get_ip)
fi

if [ -z "$IP" ]; then
    log "获取IP失败，放弃本次修复。"
    save_state "offline" "$NOW" "1" "获取IP失败"
    exit 1
fi

log "成功获取IP: $IP，准备登录..."
MAC=$(get_mac)
LOGIN_URL="${LOGIN_BASE}${LOGIN_PATH}?callback=dr1003&login_method=1&user_account=${USER_ACCOUNT}&user_password=${USER_PASSWORD}&wlan_user_ip=${IP}&wlan_user_ipv6=&wlan_user_mac=${MAC}&wlan_ac_ip=${AC_IP}&wlan_ac_name=&jsVersion=4.2.1&terminal_type=1&lang=zh-cn&v=6008&lang=zh"
RESULT=$(curl -s --connect-timeout 5 "$LOGIN_URL")
if echo "$RESULT" | grep -q "$SUCCESS_STRING"; then
    log "登录成功！"
    sleep 3
    if check_online; then
        log "外网已恢复。"
        save_state "online" "$NOW" "1" ""
    else
        log "登录返回成功但外网仍不通。"
        save_state "offline" "$NOW" "1" "登录成功但无外网"
    fi
else
    log "登录失败，返回: $RESULT"
    save_state "offline" "$NOW" "1" "登录失败"
fi
exit 0