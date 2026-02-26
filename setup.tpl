#!/bin/bash

# Update and install
apt-get update -y
apt-get install wireguard iptables -y

# Enable IP Forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Generate Keys
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key


wg genkey | tee client_private.key | wg pubkey > client_public.key
wg genkey | tee client2_private.key | wg pubkey > client2_public.key
wg genkey | tee client3_private.key | wg pubkey > client3_public.key

# Read keys (Normal bash syntax, Terraform will ignore these)
SERVER_PRIV=$(cat server_private.key)
SERVER_PUB=$(cat server_public.key)


CLIENT_PRIV=$(cat client_private.key)
CLIENT_PUB=$(cat client_public.key)
CLIENT2_PRIV=$(cat client2_private.key)
CLIENT2_PUB=$(cat client2_public.key)
CLIENT3_PRIV=$(cat client3_private.key)
CLIENT3_PUB=$(cat client3_public.key)

# Create Server Config
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.0.1/24
ListenPort = 443
PrivateKey = $SERVER_PRIV

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.0.0.2/32

[Peer]
PublicKey = $CLIENT2_PUB
AllowedIPs = 10.0.0.3/32

[Peer]
PublicKey = $CLIENT3_PUB
AllowedIPs = 10.0.0.4/32
EOF

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Auto-Generate Windows Client
cat <<EOF > /home/ubuntu/windows_client_1.conf
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${domain}:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

cat <<EOF > /home/ubuntu/windows_client_2.conf
[Interface]
PrivateKey = $CLIENT2_PRIV
Address = 10.0.0.3/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${domain}:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

cat <<EOF > /home/ubuntu/windows_client_3.conf
[Interface]
PrivateKey = $CLIENT3_PRIV
Address = 10.0.0.4/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${domain}:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF


chown ubuntu:ubuntu /home/ubuntu/windows_client_1.conf
chown ubuntu:ubuntu /home/ubuntu/windows_client_2.conf
chown ubuntu:ubuntu /home/ubuntu/windows_client_3.conf