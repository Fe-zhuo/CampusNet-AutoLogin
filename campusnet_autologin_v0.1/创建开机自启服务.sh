cat > /etc/init.d/auto_login << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    (sleep 40; /data/check_net.sh) &
}
EOF
chmod +x /etc/init.d/auto_login
/etc/init.d/auto_login enable