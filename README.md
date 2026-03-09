安装

chmod +x auto_ipv6.sh
./auto_ipv6.sh

卸载

./auto_ipv6.sh uninstall

查看dns

cat /etc/resolv.conf

一键连通

ip -6 addr show | grep global | awk '{print $2}' | cut -d/ -f1 | while read ip; do
  ping6 -c1 -W1 $ip >/dev/null 2>&1
  if [ $? -eq 0 ]; then echo "✅ $ip 通"; else echo "❌ $ip 不通"; fi
done


MAIN_IP4="50.114.74.241"      # 1. 你的主IP（IPv4）
GW_IP4="50.114.74.1"          # 2. 你的IPv4网关
GW_IP6="2605:e440:3a::1"      # 3. 你的IPv6网关
PREFIX="/118"                 # 4. 子网掩码（前缀长度）


一键ipv6脚本


#!/bin/bash

# ====================== 【只改这里 5 个参数】======================
MAIN_IP4="50.114.74.241"
GW_IP4="50.114.74.1"
GW_IP6="2605:e440:3a::1"
PREFIX="/118"
DNS1="8.8.8.8"
DNS2="223.5.5.5"
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





一键脚本


#!/bin/bash

# ====================== 【只改这里 4 个】======================
MAIN_IP4="50.114.74.241"
GW_IP4="50.114.74.1"
GW_IP6="2605:e440:3a::1"
PREFIX="/118"
# ==============================================================

# 自动识别网卡
NIC=$(ip -4 route ls | grep 'default' | grep -Po '(?<=dev )(\S+)' | head -1)
echo "✅ 自动识别网卡：$NIC"

# 识别系统
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
fi

# 清理旧文件
rm -f /root/ipv6_list.txt
rm -f /root/ipv6_apply.sh
rm -f /etc/netplan/00-ipv6-ALL.yaml
rm -f /etc/systemd/system/ipv6-auto.service
systemctl daemon-reload

# 写入 IPv6 列表
cat >/root/ipv6_list.txt <<'EOF'
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

# 生成执行脚本
cat >/root/ipv6_apply.sh <<'EOF'
#!/bin/bash
MAIN_IP4="$1"
GW_IP4="$2"
GW_IP6="$3"
PREFIX="$4"
NIC="$5"

# 先清空旧IPv6
for ip in $(ip -6 addr show "$NIC" 2>/dev/null | grep 'scope global' | awk '{print $2}'); do
  ip -6 addr del "$ip" dev "$NIC" 2>/dev/null
done

# 批量添加IPv6
while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | xargs)
  [[ -z "$line" || "$line" == \#* ]] && continue
  ip -6 addr add "${line}${PREFIX}" dev "$NIC"
done < /root/ipv6_list.txt

# 设置网关
ip -6 route del default via "$GW_IP6" 2>/dev/null
ip -6 route add default via "$GW_IP6"

ip route replace default via "$GW_IP4"
EOF

chmod +x /root/ipv6_apply.sh

# 立即执行一次
/root/ipv6_apply.sh "$MAIN_IP4" "$GW_IP4" "$GW_IP6" "$PREFIX" "$NIC"

# 生成 systemd 服务
cat >/etc/systemd/system/ipv6-auto.service <<'EOF'
[Unit]
Description=IPv6 auto config
After=network-online.target NetworkManager.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/root/ipv6_apply.sh "MAIN_IP4" "GW_IP4" "GW_IP6" "PREFIX" "NIC"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 替换真实参数到服务里
sed -i "s|MAIN_IP4|$MAIN_IP4|g" /etc/systemd/system/ipv6-auto.service
sed -i "s|GW_IP4|$GW_IP4|g" /etc/systemd/system/ipv6-auto.service
sed -i "s|GW_IP6|$GW_IP6|g" /etc/systemd/system/ipv6-auto.service
sed -i "s|PREFIX|$PREFIX|g" /etc/systemd/system/ipv6-auto.service
sed -i "s|NIC|$NIC|g" /etc/systemd/system/ipv6-auto.service

systemctl daemon-reload
systemctl enable ipv6-auto
systemctl restart ipv6-auto

echo ""
echo "🎉 安装完成！重启后 100% 自动绑定 IPv6"
echo "✅ 无自检、无后台、最干净"
echo "🗑️  卸载命令：systemctl disable ipv6-auto && rm -f /root/ipv6_* /etc/systemd/system/ipv6-auto.service"




一键脚本3卸载




#!/bin/bash

# ====================== 【只改这里 4 个】======================
MAIN_IP4="50.114.74.241"
GW_IP4="50.114.74.1"
GW_IP6="2605:e440:3a::1"
PREFIX="/118"
# ==============================================================

# 卸载模式
if [ "$1" = "uninstall" ]; then
  echo "⚠️  开始一键卸载清理..."

  systemctl stop ipv6-auto.service 2>/dev/null
  systemctl disable ipv6-auto.service 2>/dev/null
  rm -f /etc/systemd/system/ipv6-auto.service
  rm -f /root/ipv6_apply.sh
  rm -f /root/ipv6_list.txt
  systemctl daemon-reload

  # 卸载后清空网卡上的IPv6（可选，保留系统原本的IP）
  NIC=$(ip -4 route ls | grep 'default' | grep -Po '(?<=dev )(\S+)' | head -1)
  for ip in $(ip -6 addr show $NIC | grep scope global | awk '{print $2}'); do
    ip -6 addr del $ip dev $NIC 2>/dev/null
  done

  echo "🗑️  卸载完成！所有文件、自启、IPv6 已清理干净。"
  exit 0
fi

# ==================== 安装 ====================
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

# 执行脚本
cat >/root/ipv6_apply.sh <<'EOF'
#!/bin/bash
MAIN_IP4="$1"
GW_IP4="$2"
GW_IP6="$3"
PREFIX="$4"
NIC="$5"

for ip in $(ip -6 addr show "$NIC" 2>/dev/null | grep 'scope global' | awk '{print $2}'); do
  ip -6 addr del "$ip" dev "$NIC" 2>/dev/null
done

while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | xargs)
  [[ -z "$line" || "$line" == \#* ]] && continue
  ip -6 addr add "${line}${PREFIX}" dev "$NIC"
done < /root/ipv6_list.txt

ip -6 route del default via "$GW_IP6" 2>/dev/null
ip -6 route add default via "$GW_IP6"
ip route replace default via "$GW_IP4"
EOF

chmod +x /root/ipv6_apply.sh
/root/ipv6_apply.sh "$MAIN_IP4" "$GW_IP4" "$GW_IP6" "$PREFIX" "$NIC"

# 开机自启
cat >/etc/systemd/system/ipv6-auto.service <<EOF
[Unit]
Description=IPv6 开机自动配置
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/root/ipv6_apply.sh "$MAIN_IP4" "$GW_IP4" "$GW_IP6" "$PREFIX" "$NIC"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ipv6-auto
systemctl start ipv6-auto

echo ""
echo "🎉 安装完成！重启自动绑定所有 IPv6"
echo "✅ 全系统通用（Ubuntu/Debian/CentOS/Rocky）"
echo "✅ 无自检、无后台"
echo ""
echo "🗑️  一键卸载：./$(basename "$0") uninstall"
echo "👉 查看IP：ip -6 addr"


安装
chmod +x auto_ipv6.sh
./auto_ipv6.sh





