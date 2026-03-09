#!/bin/bash

# ====================== 【只改这里 5 个参数】======================
MAIN_IP4="50.114.74.241"
GW_IP4="50.114.74.1"
GW_IP6="2605:e440:3a::1"
PREFIX="/118"
DNS1="1.1.1.1"
DNS2="8.8.4.4"
DNS6_1="2001:4860:4860::8888"
DNS6_2="2400:3200::1"
# ==================================================================

# 卸载模式
if [ "$1" = "uninstall" ]; then
  echo "⚠️  开始一键卸载清理..."

  systemctl stop ipv6-auto.service 2>/dev/null
  systemctl disable ipv6-auto.service 2>/dev/null
  rm -f /etc/systemd/system/ipv6-auto.service
  rm -f /root/ipv6_apply.sh
  rm -f /root/ipv6_list.txt
  systemctl daemon-reload

  NIC=$(ip -4 route ls | grep 'default' | grep -Po '(?<=dev )(\S+)' | head -1)
  for ip in $(ip -6 addr show $NIC | grep scope global | awk '{print $2}'); do
    ip -6 addr del $ip dev $NIC 2>/dev/null
  done

  echo "🗑️  卸载完成！"
  exit 0
fi

# 自动识别网卡
NIC=$(ip -4 route ls | grep 'default' | grep -Po '(?<=dev )(\S+)' | head -1)
echo "✅ 自动识别网卡：$NIC"

# 清理旧配置
systemctl stop ipv6-auto.service 2>/dev/null
systemctl disable ipv6-auto.service 2>/dev/null
rm -f /etc/systemd/system/ipv6-auto.service
rm -f /root/ipv6_apply.sh
rm -f /root/ipv6_list.txt
systemctl daemon-reload

# IPv6 列表
cat >/root/ipv6_list.txt <<EOF
2605:e440:3a::151
2605:e440:3a::153
2605:e440:3a::154
2605:e440:3a::15c
2605:e440:3a::15f
2605:e440:3a::16a
2605:e440:3a::1:11
2605:e440:3a::1:18
2605:e440:3a::1:22
2605:e440:3a::1:2e
2605:e440:3a::1:32
2605:e440:3a::1:37
2605:e440:3a::1:38
2605:e440:3a::1:39
2605:e440:3a::1:3d
2605:e440:3a::1:43
2605:e440:3a::1:45
2605:e440:3a::1:46
2605:e440:3a::1:47
2605:e440:3a::1:4a
2605:e440:3a::1:4c
2605:e440:3a::1:4d
2605:e440:3a::1:4e
2605:e440:3a::1:4f
2605:e440:3a::1:50
2605:e440:3a::1:51
2605:e440:3a::1:52
2605:e440:3a::1:53
2605:e440:3a::1:54
2605:e440:3a::1:55
2605:e440:3a::1:56
2605:e440:3a::1:57
2605:e440:3a::1:58
2605:e440:3a::1:59
2605:e440:3a::1:5a
2605:e440:3a::1:5b
2605:e440:3a::1:5c
2605:e440:3a::1:5d
2605:e440:3a::1:5e
2605:e440:3a::1:5f
2605:e440:3a::1:60
2605:e440:3a::1:61
2605:e440:3a::1:63
2605:e440:3a::1:68
2605:e440:3a::1:6c
2605:e440:3a::1:6d
2605:e440:3a::1:6e
2605:e440:3a::1:70
2605:e440:3a::1:72
2605:e440:3a::1:73
2605:e440:3a::1c8
2605:e440:3a::1d0
2605:e440:3a::1f
2605:e440:3a::218
2605:e440:3a::226
2605:e440:3a::235
2605:e440:3a::281
2605:e440:3a::2c7
2605:e440:3a::2cf
2605:e440:3a::3d0
2605:e440:3a::3f2
2605:e440:3a::54
2605:e440:3a::62
EOF

# 生成带 DNS 的脚本
cat >/root/ipv6_apply.sh <<'EOF'
#!/bin/bash
MAIN_IP4="$1"
GW_IP4="$2"
GW_IP6="$3"
PREFIX="$4"
NIC="$5"
DNS1="$6"
DNS2="$7"
DNS6_1="$8"
DNS6_2="$9"

# 清空旧IPv6
for ip in $(ip -6 addr show "$NIC" 2>/dev/null | grep 'scope global' | awk '{print $2}'); do
  ip -6 addr del "$ip" dev "$NIC" 2>/dev/null
done

# 批量添加IPv6
while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | xargs)
  [[ -z "$line" || "$line" == \#* ]] && continue
  ip -6 addr add "${line}${PREFIX}" dev "$NIC"
done < /root/ipv6_list.txt

# 网关
ip -6 route del default via "$GW_IP6" 2>/dev/null
ip -6 route add default via "$GW_IP6"
ip route replace default via "$GW_IP4"

# 写入 DNS
cat >/etc/resolv.conf <<EOF2
nameserver $DNS1
nameserver $DNS2
nameserver $DNS6_1
nameserver $DNS6_2
EOF2

EOF

chmod +x /root/ipv6_apply.sh

# 立即执行
/root/ipv6_apply.sh "$MAIN_IP4" "$GW_IP4" "$GW_IP6" "$PREFIX" "$NIC" "$DNS1" "$DNS2" "$DNS6_1" "$DNS6_2"

# 开机自启服务
cat >/etc/systemd/system/ipv6-auto.service <<EOF
[Unit]
Description=IPv6+DNS 开机自动配置
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/root/ipv6_apply.sh "$MAIN_IP4" "$GW_IP4" "$GW_IP6" "$PREFIX" "$NIC" "$DNS1" "$DNS2" "$DNS6_1" "$DNS6_2"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ipv6-auto
systemctl start ipv6-auto

echo ""
echo "🎉 安装完成！"
echo "✅ 重启自动绑定 IPv6 + DNS"
echo "✅ 以后改 DNS 只改脚本顶部即可"
echo "🗑️  卸载：./$(basename "$0") uninstall"
