# openvpn-script
openvpn-script
Creating a shell script to automate the installation and configuration of openvpn on XCP-ng, and hosting it on GitHub for easy fetching and execution, involves several steps. Below is the step-by-step guide to achieve this:

Step 1: Create the Shell Script
Create a shell script named setup-openvpn.sh with the following content:

bash
Copy code
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
Step 2: Host the Script on GitHub
Create a new repository on GitHub:

Go to GitHub and create a new public repository (e.g., openvpn-setup).
Clone the repository to your local machine.
bash
Copy code
git clone https://github.com/your-username/openvpn-script.git
cd openvpn-setup
Add the script to the repository:

Copy the setup-openvpn.sh script to the repository directory.
bash
Copy code
cp /path/to/setup-openvpn.sh .
Commit and push the script to GitHub:

bash
Copy code
git add setup-openvpn.sh
git commit -m "Add OpenVPN setup script"
git push origin main
Step 3: Fetch, Download, and Run the Script on XCP-ng Server
Fetch the script using wget or curl:

bash
Copy code
# Using wget
wget https://raw.githubusercontent.com/your-username/openvpn-script/main/setup-openvpn.sh

# Using curl
curl -O https://raw.githubusercontent.com/your-username/openvpn-script/main/setup-openvpn.sh
Make the script executable:

bash
Copy code
chmod +x setup-openvpn.sh
Run the script:

bash
Copy code
./setup-openvpn.sh
Summary of Commands
bash
Copy code
# Fetch the script using wget
wget https://raw.githubusercontent.com/HajeraGleecus/openvpn-script/main/setup-openvpn.sh

# Or using curl
curl -O https://raw.githubusercontent.com/HajeraGleecus/openvpn-script/main/setup-openvpn.sh

# Make the script executable
chmod +x setup-openvpn.sh

# Run the script
./setup-openvpn.sh
Replace your-username with your actual GitHub username.

This script will install openvpn and easy-rsa, configure OpenVPN, generate the necessary certificates and keys, set up the server and client configuration files, and enable the required firewall rules. Make sure to replace YOUR_SERVER_IP in the client configuration file with your actual server IP address.
