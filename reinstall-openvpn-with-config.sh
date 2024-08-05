#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to check the exit status of a command and exit if it fails
check_exit_status() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

# Install OpenVPN and Easy-RSA
yum install openvpn easy-rsa -y
check_exit_status "Failed to install OpenVPN and Easy-RSA"

# Set up the Easy-RSA directory
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/3/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa
check_exit_status "Failed to set up Easy-RSA directory"

# Initialize the PKI
./easyrsa init-pki
check_exit_status "Failed to initialize PKI"

# Build the Certificate Authority (CA)
./easyrsa build-ca nopass
check_exit_status "Failed to build CA"

# Generate server certificate and key
./easyrsa gen-req server nopass
check_exit_status "Failed to generate server certificate request"
./easyrsa sign-req server server
check_exit_status "Failed to sign server certificate"

# Generate Diffie-Hellman parameters
./easyrsa gen-dh
check_exit_status "Failed to generate Diffie-Hellman parameters"

# Generate TLS auth key
openvpn --genkey --secret ta.key
check_exit_status "Failed to generate TLS auth key"

# Copy server certificates and keys
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ta.key /etc/openvpn/
check_exit_status "Failed to copy server certificates and keys"

# Create server configuration file
cat <<EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
cipher AES-256-CBC
user nobody
group nobody
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
comp-lzo
persist-key
persist-tun
status openvpn-status.log
log-append /var/log/openvpn.log
verb 3
EOF
check_exit_status "Failed to create server configuration file"

# Enable and start the OpenVPN service
systemctl enable openvpn@server
check_exit_status "Failed to enable OpenVPN service"
systemctl start openvpn@server
check_exit_status "Failed to start OpenVPN service"

# Generate client certificates and keys for client1
./easyrsa gen-req client1 nopass
check_exit_status "Failed to generate client1 certificate request"
./easyrsa sign-req client client1
check_exit_status "Failed to sign client1 certificate"

# Generate client certificates and keys for client2
./easyrsa gen-req client2 nopass
check_exit_status "Failed to generate client2 certificate request"
./easyrsa sign-req client client2
check_exit_status "Failed to sign client2 certificate"

# Create directories for client configurations
mkdir -p /etc/openvpn/client-configs/keys

# Copy client1 certificates and keys
cp pki/ca.crt pki/issued/client1.crt pki/private/client1.key ta.key /etc/openvpn/client-configs/keys/
check_exit_status "Failed to copy client1 certificates and keys"

# Copy client2 certificates and keys
cp pki/ca.crt pki/issued/client2.crt pki/private/client2.key ta.key /etc/openvpn/client-configs/keys/
check_exit_status "Failed to copy client2 certificates and keys"

# Create client1 .ovpn configuration file
cat <<EOF > /etc/openvpn/client-configs/client1.ovpn
client
dev tun
proto udp
remote YOUR_SERVER_PUBLIC_IP 1194
resolv-retry infinite
nobind
user nobody
group nobody
persist-key
persist-tun
ca ca.crt
cert client1.crt
key client1.key
tls-auth ta.key 1
cipher AES-256-CBC
comp-lzo
verb 3
EOF
check_exit_status "Failed to create client1 .ovpn configuration file"

# Create client2 .ovpn configuration file
cat <<EOF > /etc/openvpn/client-configs/client2.ovpn
client
dev tun
proto udp
remote YOUR_SERVER_PUBLIC_IP 1194
resolv-retry infinite
nobind
user nobody
group nobody
persist-key
persist-tun
ca ca.crt
cert client2.crt
key client2.key
tls-auth ta.key 1
cipher AES-256-CBC
comp-lzo
verb 3
EOF
check_exit_status "Failed to create client2 .ovpn configuration file"

echo "OpenVPN has been reinstalled and configured successfully for client1 and client2."
