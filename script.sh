#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install epel-release
yum install epel-release --enablerepo=base,updates -y

# Install openvpn and easy-rsa
yum install openvpn easy-rsa --enablerepo=epel -y

# Generate server keys and certificates
mkdir -p /etc/openvpn/easy-rsa/keys
cp -r /usr/share/easy-rsa/3/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret ta.key

# Copy the generated files to the OpenVPN directory
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ta.key /etc/openvpn/

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

# Enable and start the OpenVPN service
systemctl enable openvpn@server
systemctl start openvpn@server

# Generate client keys and certificates
cd /etc/openvpn/easy-rsa
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1

# Copy client files
mkdir -p /etc/openvpn/client-configs/keys
cp pki/ca.crt pki/issued/client1.crt pki/private/client1.key /etc/openvpn/client-configs/keys/
cp ta.key /etc/openvpn/client-configs/keys/

# Create client configuration file
cat <<EOF > /etc/openvpn/client-configs/client1.ovpn
client
dev tun
proto udp
remote YOUR_SERVER_IP 1194
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

# Enable SSH and OpenVPN traffic in the firewall
firewall-cmd --add-service=ssh --permanent
firewall-cmd --add-port=1194/udp --permanent
firewall-cmd --reload

# Restart SSH service
systemctl restart sshd

# Display network configuration and IP address
ip addr show

echo "OpenVPN installation and configuration complete."
