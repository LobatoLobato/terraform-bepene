#!/bin/bash

cd "$(dirname "$0")/.." || exit 1

PLAYER_NAME=$1
PLATFORM=$2
IP_MAP_FILE="keys/ip_mappings.txt"

if [ -z "$PLAYER_NAME" ]; then
    echo "Usage: $0 <player_name>"
    exit 1
fi

if [ -d "keys/$PLAYER_NAME" ]; then
    echo "Error: Directory keys/$PLAYER_NAME already exists. Please choose a different player name."
    exit 1
fi

if [ -z "$PLATFORM" ]; then
    echo "Warning: No platform specified. Defaulting to 'windows'."
    PLATFORM="windows"
fi
    
if [ ! -f "$IP_MAP_FILE" ]; then
    touch "$IP_MAP_FILE"
fi

NEXT_IP=2
while grep -q "^10.0.0.$NEXT_IP " "$IP_MAP_FILE"; do
    NEXT_IP=$((NEXT_IP + 1))
done


# Player directory, keys, IP config
mkdir keys/$PLAYER_NAME
wg genkey | tee keys/$PLAYER_NAME/private.key | wg pubkey > keys/$PLAYER_NAME/public.key

# Assign IP
echo "10.0.0.$NEXT_IP $PLAYER_NAME" >> "$IP_MAP_FILE"


SERVER_PUB=$(cat keys/server_public.key)

DOMAIN=$(cat main.tfvars | grep "[[:space:]]domain[[:space:]]" | head -1 | cut -d '"' -f 2)
SUBDOMAIN=$(cat main.tfvars | grep "[[:space:]]subdomain[[:space:]]" | head -1 | cut -d '"' -f 2)
domain="$SUBDOMAIN.$DOMAIN"

FOLDERS_ONLY=$(find keys -mindepth 1 -maxdepth 1 -type d)

for folder in $FOLDERS_ONLY; do
    CLIENT_NAME=$(basename $folder)
    CLIENT_IP=$(grep " $CLIENT_NAME$" "$IP_MAP_FILE" | cut -d' ' -f1 | cut -d'.' -f4)
    
    if [ -z "$CLIENT_IP" ]; then
        echo "Warning: No IP mapping found for $CLIENT_NAME, skipping..."
        continue
    fi
    if [ "$PLATFORM" == "windows" ]; then
            cat <<EOF > "$folder/$CLIENT_NAME.conf"
[Interface]
PrivateKey = $(cat $folder/private.key)
Address = 10.0.0.$CLIENT_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $domain:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    else

                cat <<EOF > "$folder/$CLIENT_NAME.sh"
#!/bin/bash
ADDRESS=10.0.0.$CLIENT_IP/32
PRIVATE_KEY=$(cat $folder/private.key)
PUBLIC_KEY=$SERVER_PUB
ENDPOINT=$domain
EOF
        
        cat <<'EOF' >> "$folder/$CLIENT_NAME.sh"

# If you dont know what is going on don't mess with these variables
MTU="1420"
CGROUP="skel0vpn"
CGROUP_PATH="/sys/fs/cgroup/net_cls/$CGROUP"
CLASSID="0x10001"
PROFILE="fg"
MARK="11"
TABLE="1221"

if [ "$EUID" -ne 0 ] && [ "$1" != "run" ]; then
   exec sudo "$0" "$@"
fi

WIREGUARD_CONFIG="
[Interface]
Address = $ADDRESS
DNS = 1.1.1.1
Table = off
MTU = $MTU
PrivateKey = $PRIVATE_KEY

[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $ENDPOINT:443
PersistentKeepalive = 25
"

CGROUP_SERVICE="
[Unit]
Description=Setup skel0vpn cgroup hierarchy
After=local-fs.target
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
# Ensure the directory exists
ExecStartPre=/usr/bin/mkdir -p /sys/fs/cgroup/net_cls
# Explicitly mount with v1 options, ignoring errors if already mounted
ExecStartPre=/usr/bin/sh -c '/usr/bin/mountpoint -q /sys/fs/cgroup/net_cls || /usr/bin/mount -t cgroup -o net_cls net_cls /sys/fs/cgroup/net_cls'

# Create the specific branch
ExecStart=/usr/bin/mkdir -p $CGROUP_PATH
# Use tee for reliable writing
ExecStart=/usr/bin/sh -c 'echo $CLASSID | /usr/bin/tee $CGROUP_PATH/net_cls.classid'
ExecStart=/usr/bin/chown -R $SUDO_USER:$SUDO_USER $CGROUP_PATH

[Install]
WantedBy=multi-user.target
"

if [ $1 == "install" ]; then
  echo "Installing configuration and setting up cgroup"

  # Install Wireguard configuration
  echo "$WIREGUARD_CONFIG" > /etc/wireguard/$PROFILE.conf

  # Create CGroup initialization service
  echo "$CGROUP_SERVICE" > /etc/systemd/system/$CGROUP-cgroup.service
  systemctl daemon-reload
  systemctl enable $CGROUP-cgroup.service
  systemctl start $CGROUP-cgroup.service

  # Make skel0vpn command available
  cp $(realpath "$0") /usr/local/bin/skel0vpn
  chmod +x /usr/local/bin/skel0vpn
elif [ $1 == "uninstall" ]; then
  echo "Uninstalling VPN."
  # Remove CGroup initialization service
  systemctl stop $CGROUP-cgroup.service 2>/dev/null
  systemctl disable $CGROUP-cgroup.service 2>/dev/null
  rm -f /etc/systemd/system/$CGROUP-cgroup.service
  systemctl daemon-reload

  # Remove .conf file and command
  rm -f /etc/wireguard/$PROFILE.conf
  rm -f /usr/local/bin/skel0vpn

  echo "VPN uninstalled."
elif [ $1 == "up" ]; then
    echo "Bringing up VPN..."
    sudo wg-quick up $PROFILE

    # Packet Filters
      # Add mark on packets originating from the cgroup
      iptables -t mangle -A OUTPUT -m cgroup --cgroup $CLASSID -j MARK --set-mark $MARK
      # Set MSS to MTU-40 to stop packets from being dropped
      iptables -t mangle -I OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $(($MTU - 40))
      # Configure NAT
      iptables -t nat -A POSTROUTING -o $PROFILE -j MASQUERADE

    # Routing Rules
      # Packets with mark will go through the configured table
      ip rule add fwmark $MARK priority 500 table $TABLE
      # Route vpn server's ip to main so it doesnt get routed to itself
      ip rule add to $ENDPOINT priority 400 table main
      # Set the table as a route to the vpn
      ip route add default dev $PROFILE table $TABLE

    ip route flush cache

    machine_vpn_ip=$(curl -4 --interface $PROFILE ifconfig.me)
    cg_machine_vpn_ip=$(cgexec -g net_cls:$CGROUP curl -4 ifconfig.me)

    echo "Tunnel IP: $machine_vpn_ip | Cgroup IP: $cg_machine_vpn_ip"
    ip route show table $TABLE

    if [ "$machine_vpn_ip" == "$cg_machine_vpn_ip" ] && [ -n "$machine_vpn_ip" ]; then
      echo "Verification Success. VPN is up and running."
    else
      echo "Verification Failed. Check 'wg show'."
    fi
elif [ $1 == "down" ]; then
  echo "Tearing down VPN..."

  # Remove routing rules
  ip route flush table $TABLE
  ip rule del fwmark $MARK priority 500 2>/dev/null
  ip rule del to $ENDPOINT priority 400 2>/dev/null

  # Remove packet filters
  iptables -t mangle -D OUTPUT -m cgroup --cgroup $CLASSID -j MARK --set-mark $MARK 2>/dev/null
  iptables -t mangle -D OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $(($MTU - 40)) 2>/dev/null
  iptables -t nat -D POSTROUTING -o $PROFILE -j MASQUERADE 2>/dev/null

  sudo wg-quick down $PROFILE

  ip route flush cache
  echo "Cleanup complete."
elif [ $1 == "run" ]; then
  shift
  if [ -d "$CGROUP_PATH" ]; then
    exec cgexec -g net_cls:$CGROUP "$@"
  else
    exec "$@"
  fi
elif [ "$1" == "status" ]; then
    echo "#--- VPN Status ---#"

    if [ -d "$CGROUP_PATH" ]; then
        echo "[CGROUP] $CGROUP is active (ClassID: $(cat $CGROUP_PATH/net_cls.classid))"
    else
        echo "[CGROUP] $CGROUP is missing"
    fi

    if ip link show $PROFILE >/dev/null 2>&1; then
        echo "[VPN] Interface $PROFILE is UP"
        wg show $PROFILE | grep -E "transfer|latest handshake"
        echo "#--- Latency Check ---#"
        ping -c 3 -W 1 1.1.1.1 | tail -1 | awk '{print "ISP Latency: " $4}'
        cgexec -g net_cls:$CGROUP ping -c 3 -W 1 1.1.1.1 | tail -1 | awk '{print "VPN Latency: " $4}'
    else
        echo "[VPN] Interface $PROFILE is DOWN"
    fi
elif [ $1 == "monitor" ]; then
    if ip link show $PROFILE >/dev/null 2>&1; then
        sudo nethogs $PROFILE
    else
        echo "[VPN] Interface $PROFILE is DOWN"
    fi
else
    echo "Usage: $0 {install|uninstall|up|down|run|status|monitor}"
fi
EOF
    fi

done

echo "Created client '$PLAYER_NAME' with IP 10.0.0.$NEXT_IP"

./keys/update_setup_script.sh
