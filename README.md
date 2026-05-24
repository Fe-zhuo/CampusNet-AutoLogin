# Fe_z
🛡️ CampusNet-AutoLogin | 专为 GDUF 校园网（10.82.0.0/16）Dr.COM 认证打造的永不掉线脚本，支持小米 4C / AX3000T，自动改 MAC 重连。 Anti-drop script for GDUF campus network, auto MAC-change &amp; re-login.


以下是为 GitHub 开源准备的**校园网不掉线全自动方案**通用说明书。所有涉及真实网络环境的信息均已替换为占位符，并附有完整的抓包指引。

---

# 🛡️ CampusNet-AutoLogin

让你的小米路由器（4C / AX3000T）在校园网环境下**永不失联**。  
定时检测外网，一旦被强制下线，自动修改 MAC 并重新认证，全程无需人工干预。

- **智能日志**：仅记录状态变化，长期运行不会撑爆存储。
- **双设备适配**：提供小米4C（OpenWrt/Kwrt）和小米AX3000T（原厂固件）两种脚本。
- **安全开源**：所有敏感参数均需自行抓包填写，不留任何个人信息。

---

## 📡 抓包指南（获取你的认证参数）

脚本需要你的校园网认证接口信息，通过浏览器 F12 即可轻松获取。

1. 连接校园网，**确保当前未登录**（注销或断开重连）。
2. 浏览器打开认证页面（通常会弹出或手动访问认证地址），**按 F12** 打开开发者工具。
3. 切换到 **Network（网络）** 标签，勾选 **Preserve log（保留日志）**。
4. 在页面中输入你的学号和密码，点击登录。
5. 在 Network 中筛选请求：
   - 过滤框输入 `login` 或 `portal` 等关键词。
   - 找到**类型为 `GET`** 的请求（通常含有 `callback` 参数）。
6. 点击该请求，查看 **Request URL** 或 **Payload**。
7. 复制完整的请求 URL 和参数，填入脚本开头的对应变量中。

> 💡 **关键变量解释**：
> - `AUTH_HOST`：认证服务器 IP（不带端口）
> - `LOGIN_BASE` + `LOGIN_PATH`：登录接口的协议 + 路径
> - `USER_ACCOUNT`：学号（注意逗号 `,` 需编码为 `%2C`）
> - `USER_PASSWORD`：你的校园网密码
> - `AC_IP`：固定不变的 AC 地址（从请求参数中找 `wlan_ac_ip`）
> - `SUCCESS_STRING`：登录成功后返回内容中的特征关键词（如“认证成功”）

---

## 📦 小米4C 脚本（适用于已刷 OpenWrt/Kwrt）

### 1. 脚本内容
将以下代码保存为 `/root/check_net.sh`，并**替换开头的参数**。

```bash
#!/bin/sh
#===========================================================
# 小米4C 校园网自动登录脚本 (OpenWrt/Kwrt)
# 请先通过抓包修改以下 [ ] 包围的参数
#===========================================================

# ---------- 必须修改的参数 ----------
AUTH_HOST="[认证服务器IP]"                       # 例如 10.82.0.66
LOGIN_BASE="http://[认证服务器IP]:[端口]"
LOGIN_PATH="/[认证路径]"
USER_ACCOUNT="[学号]"                           # 逗号编码为 %2C
USER_PASSWORD="[校园网密码]"
AC_IP="[AC地址]"                                # 例如 10.82.82.1
SUCCESS_STRING="[登录成功关键词]"                 # 如 Portal协议认证成功！
WAN_IF="eth0.2"                                 # 4C的WAN口，可通过ifconfig确认
LOG_FILE="/var/log/auto_login.log"
STATE_FILE="/tmp/check_net_state"
# ------------------------------------

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOG_FILE; }
timestamp() { date '+%Y-%m-%d %H:%M'; }
random_mac() { printf "00:11:22:%02X:%02X:%02X" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)); }
get_ip() { ifconfig $WAN_IF 2>/dev/null | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}'; }
get_mac() { ifconfig $WAN_IF 2>/dev/null | grep 'HWaddr' | awk '{print $5}' | tr -d ':'; }

check_online() {
    curl -s --connect-timeout 5 --max-time 5 "http://www.baidu.com" | grep -q "baidu"
}

check_auth_server() {
    curl -s --connect-timeout 3 --max-time 3 "http://${AUTH_HOST}/" > /dev/null 2>&1
}

read_state() {
    [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "init|0|0|"
}
save_state() { echo "$1|$2|$3|$4" > "$STATE_FILE"; }
ts2str() { date -d @$1 '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown"; }

# ---------- 主流程 ----------
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

LOCK_FILE="/tmp/check_net.lock"
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

log "${NOW_STR} 检测到认证失效，开始修复..."
NEW_MAC=$(random_mac)
ifconfig $WAN_IF down
ifconfig $WAN_IF hw ether $NEW_MAC
ifconfig $WAN_IF up

killall udhcpc 2>/dev/null
udhcpc -i $WAN_IF -q &
sleep 8

IP=$(get_ip)
[ -z "$IP" ] && sleep 5 && IP=$(get_ip)

if [ -z "$IP" ]; then
    log "获取IP失败。"
    save_state "offline" "$NOW" "1" "获取IP失败"
    exit 1
fi
log "获取IP: $IP"

if ! check_auth_server; then
    log "认证服务器不可达。"
    save_state "offline" "$NOW" "1" "认证服务器不可达"
    exit 1
fi

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
```

### 2. 部署步骤（SSH 连接后执行）
```bash
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
```

---

## 📦 小米AX3000T 脚本（原厂固件，已开启SSH）

⚠️ **前提**：你必须已经通过工具解锁并固化 SSH，且将 WAN 口固定为单一网口（后台 → 网口自定义）。

### 1. 脚本内容
存放路径：`/data/check_net.sh`（原厂 `/root` 只读）。同样请先修改开头的抓包参数。

```bash
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
```

### 2. 部署步骤（SSH 连接后执行）
```bash
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
```

---

## 🧪 测试与维护

- **首次运行测试**：
  ```bash
  # 删除状态文件，模拟首次启动
  rm -f /tmp/check_net_state        # 4C
  rm -f /data/check_net_state       # AX3000T
  /root/check_net.sh                # 或 /data/check_net.sh
  cat /var/log/auto_login.log       # 查看日志
  ```

- **模拟断网测试**（仅限4C，AX3000T会重启）：
  拔掉 WAN 口网线，手动运行脚本，观察是否成功修改 MAC 并认证。

- **查看实时状态**：
  ```bash
  tail -f /var/log/auto_login.log   # 4C
  tail -f /data/auto_login.log      # AX3000T
  ```

- **关闭脚本**：删除 crontab 中的对应行，并删除开机启动项（AX3000T：`/etc/init.d/auto_login disable`）。

---

## 🧰 常见问题

**Q：为什么脚本运行后没有日志？**  
A：这是智能合并机制，只有网络状态发生变化（离线/恢复）才会记录。首次运行会强制输出“守护进程启动”，之后在线时静默。若想验证，请删除状态文件后再运行。

**Q：修改 MAC 后还是无法上网？**  
A：检查 WAN 口名称是否正确（`ifconfig` 查看），确认校园网端口支持 DHCP，并确保 MAC 修改成功（AX3000T 务必重启）。

**Q：我的认证请求是 POST 而不是 GET？**  
A：将脚本中 `curl` 的 GET 请求改为 `-d "参数"` 的 POST 方式即可，参数从抓包 Payload 中获取。

---

**📜 开源许可**：MIT  
**✨ 欢迎 Star & Fork**，让更多校园网用户告别掉线烦恼！