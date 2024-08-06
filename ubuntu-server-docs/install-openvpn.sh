#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Update and upgrade the system
apt update && apt upgrade -y

# Install OpenVPN and Easy-RSA
apt install openvpn easy-rsa -y

# Install and configure SSH
apt install openssh-server -y
ufw allow OpenSSH

# Set up Easy-RSA CA
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Configure vars
cat << EOF > vars
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "Gleecus"
set_var EASYRSA_REQ_EMAIL      "sunny@gleecus.com"
set_var EASYRSA_REQ_OU         "Development"
set_var EASYRSA_ALGO           "rsa"
set_var EASYRSA_KEY_SIZE       2048
EOF

# Build the CA
source vars
./clean-all
./build-ca --batch

# Generate server certificate and key
./build-key-server --batch server

# Generate Diffie-Hellman parameters
./build-dh

# Generate a TLS key
openvpn --genkey --secret keys/ta.key

# Generate client certificates and keys
./build-key --batch client1
./build-key --batch client2

# Configure OpenVPN server
cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem
tls-auth /etc/openvpn/ta.key 0
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
server 10.8.0.0 255.255.255.0
persist-key
persist-tun
keepalive 10 120
topology subnet
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
explicit-exit-notify 1
comp-lzo
status openvpn-status.log
verb 3
EOF

# Copy certificates and keys to OpenVPN directory
cp ~/openvpn-ca/keys/{server.crt,server.key,ca.crt,ta.key,dh2048.pem} /etc/openvpn/

# Enable IP forwarding
sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p

# Configure UFW for OpenVPN
ufw allow 1194/udp
ufw enable

# Start and enable OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server

# Display public IP
echo "Your public IP address is: $(curl -s ifconfig.me)"

echo "OpenVPN and SSH installation and configuration completed on Ubuntu Server 24.04."
