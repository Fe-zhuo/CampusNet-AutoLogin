# 首次运行测试
# 删除状态文件，模拟首次启动
rm -f /tmp/check_net_state        # 4C
rm -f /data/check_net_state       # AX3000T
/root/check_net.sh                # 或 /data/check_net.sh
cat /var/log/auto_login.log       # 查看日志
# 模拟断网测试（仅限4C，AX3000T会重启）：
# 拔掉 WAN 口网线，手动运行脚本，观察是否成功修改 MAC 并认证。

# 查看实时状态：
tail -f /var/log/auto_login.log   # 4C
tail -f /data/auto_login.log      # AX3000T
# 关闭脚本：删除 crontab 中的对应行，并删除开机启动项（AX3000T：/etc/init.d/auto_login disable）