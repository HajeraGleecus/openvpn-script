#!/bin/bash

# Variables
XCP_NG_IP="192.168.1.10"
XCP_NG_GATEWAY="192.168.1.1"
XCP_NG_NETMASK="255.255.255.0"
DNS1="8.8.8.8"
DNS2="8.8.4.4"
ROUTER_IP="192.168.1.1"
ROUTER_USER="ubnt"
PUBLIC_IP="your-public-ip"
LOCAL_USER="sunny"
XCP_NG_USER="sunny"
SSH_PORT="22"
TUNNEL_PORT="2222"

# Step 1: Assign Static IP to XCP-ng Server
echo "Configuring static IP for XCP-ng server..."
cat <<EOL | sudo tee /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
IPADDR=$XCP_NG_IP
NETMASK=$XCP_NG_NETMASK
GATEWAY=$XCP_NG_GATEWAY
DNS1=$DNS1
DNS2=$DNS2
EOL

# Restart Network Service
echo "Restarting network service..."
sudo systemctl restart network

# Step 2: Configure DMZ on EdgeRouter
echo "Configuring DMZ on EdgeRouter..."
ssh $ROUTER_USER@$ROUTER_IP <<EOF
configure
set service nat rule 5000 description 'DMZ for XCP-ng'
set service nat rule 5000 destination address $XCP_NG_IP
set service nat rule 5000 inbound-interface eth0
set service nat rule 5000 inside-address address $XCP_NG_IP
set service nat rule 5000 inside-address port $SSH_PORT
set service nat rule 5000 protocol tcp_udp
set service nat rule 5000 type destination
commit
save
exit
EOF

# Step 3: Configure Firewall Rules for SSH Access
echo "Setting up firewall rules for SSH access..."
ssh $ROUTER_USER@$ROUTER_IP <<EOF
configure
set firewall name WAN_LOCAL rule 20 action accept
set firewall name WAN_LOCAL rule 20 description 'Allow SSH'
set firewall name WAN_LOCAL rule 20 destination port $SSH_PORT
set firewall name WAN_LOCAL rule 20 protocol tcp
commit
save
exit
EOF

# Verification Instructions
echo "Setup complete."
echo "To connect to your XCP-ng server via SSH tunnel, remote users should use the following command:"
echo "ssh -L $TUNNEL_PORT:$XCP_NG_IP:$SSH_PORT sunny@$PUBLIC_IP"
echo "Then connect using: ssh -p $TUNNEL_PORT $XCP_NG_USER@localhost"
