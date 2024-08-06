#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

echo "Updating and upgrading the system..."
apt update && apt upgrade -y

echo "Installing OpenVPN and Easy-RSA..."
apt install openvpn easy-rsa -y

echo "Installing and configuring SSH..."
apt install openssh-server -y
ufw allow OpenSSH

echo "Setting up Easy-RSA CA directory..."
EASYRSA_DIR=~/easy-rsa
make-cadir "$EASYRSA_DIR"
cd "$EASYRSA_DIR" || exit

echo "Configuring Easy-RSA variables..."
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

echo "Sourcing Easy-RSA variables..."
# Source vars file
source vars

echo "Cleaning any existing keys and certificates..."
# Initialize the PKI and clean any existing keys and certificates
./easyrsa init-pki

echo "Building the Certificate Authority (CA)..."
# Build the CA
./easyrsa build-ca nopass

echo "Generating server certificate and key..."
# Generate the server certificate and key
./easyrsa gen-req server nopass
./easyrsa sign-req server server

echo "Generating Diffie-Hellman parameters..."
# Generate Diffie-Hellman parameters
./easyrsa gen-dh

echo "Generating TLS-Auth key..."
# Generate a TLS-Auth key
openvpn --genkey secret pki/ta.key

echo "Generating client certificates and keys..."
# Generate client certificates and keys
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1

./easyrsa gen-req client2 nopass
./easyrsa sign-req client client2

echo "Copying certificates and keys to the OpenVPN directory..."
# Copy certificates and keys to the OpenVPN directory
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/ta.key pki/dh.pem /etc/openvpn/

echo "Configuring the OpenVPN server..."
# Configure OpenVPN server
cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
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

echo "Enabling IP forwarding..."
# Enable IP forwarding
sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p

echo "Configuring UFW for OpenVPN..."
# Configure UFW for OpenVPN
ufw allow 1194/udp
ufw enable

echo "Starting and enabling the OpenVPN service..."
# Start and enable OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server

echo "Your public IP address is: $(curl -s ifconfig.me)"

echo "OpenVPN and SSH installation and configuration completed on Ubuntu Server 24.04."
