#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Define Easy-RSA and OpenVPN directories
EASYRSA_DIR=~/openvpn-ca
OPENVPN_DIR=/etc/openvpn

# Check if the Easy-RSA directory exists
if [ ! -d "$EASYRSA_DIR" ]; then
  echo "Easy-RSA directory not found. Please ensure Easy-RSA is installed and initialized."
  exit 1
fi

# Navigate to the Easy-RSA directory
cd "$EASYRSA_DIR" || exit

# Backup the existing vars file
cp vars vars.bak

# Edit the vars file to remove elliptic curve settings
sed -i '/^set_var EASYRSA_ALGO/d' vars
sed -i '/^set_var EASYRSA_CURVE/d' vars

# Optionally, add RSA settings if desired
echo 'set_var EASYRSA_ALGO "rsa"' >> vars
echo 'set_var EASYRSA_KEY_SIZE 2048' >> vars

# Source the updated vars file
source vars

# Clean old keys and certificates
./clean-all

# Rebuild the CA
./build-ca --batch

# Generate new server certificate, key, and Diffie-Hellman parameters
./build-key-server --batch server
./build-dh
openvpn --genkey --secret keys/ta.key

# Generate new client certificates and keys
./build-key --batch client1
./build-key --batch client2

# Copy new certificates and keys to the OpenVPN directory
cp keys/{server.crt,server.key,ca.crt,ta.key,dh2048.pem} "$OPENVPN_DIR"

# Restart OpenVPN service to apply new configurations
systemctl restart openvpn@server

# Display status of the OpenVPN service
systemctl status openvpn@server

echo "OpenVPN configuration updated and certificates regenerated successfully."
