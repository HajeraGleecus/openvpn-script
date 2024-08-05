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

# Stop the OpenVPN service
systemctl stop openvpn@server
check_exit_status "Failed to stop OpenVPN service"

# Remove OpenVPN and Easy-RSA packages
yum remove openvpn easy-rsa -y
check_exit_status "Failed to remove OpenVPN and Easy-RSA"

# Delete OpenVPN configuration and keys
rm -rf /etc/openvpn
check_exit_status "Failed to remove OpenVPN configuration and keys"

# Remove iptables rules related to OpenVPN
iptables -D INPUT -p udp --dport 1194 -j ACCEPT
check_exit_status "Failed to remove OpenVPN port from iptables"

# Save iptables rules
service iptables save
check_exit_status "Failed to save iptables rules"

# Restart iptables service
systemctl restart iptables
check_exit_status "Failed to restart iptables"

echo "OpenVPN and all associated files have been removed successfully."
