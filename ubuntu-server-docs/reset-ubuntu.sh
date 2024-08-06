#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Stop and disable OpenVPN and SSH services
echo "Stopping and disabling OpenVPN and SSH services..."
systemctl stop openvpn@server
systemctl disable openvpn@server
systemctl stop ssh
systemctl disable ssh

# Uninstall OpenVPN, Easy-RSA, and SSH
echo "Uninstalling OpenVPN, Easy-RSA, and SSH..."
apt remove --purge openvpn easy-rsa openssh-server -y
apt autoremove -y

# Delete configuration and certificate files
echo "Deleting OpenVPN configuration and certificate files..."
rm -rf /etc/openvpn
rm -rf ~/openvpn-ca

# Revert network settings and firewall rules
echo "Reverting network settings and firewall rules..."
sed -i '/^net.ipv4.ip_forward=1/c\#net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p

# Reset UFW to default
echo "Resetting UFW to default settings..."
ufw --force reset
ufw enable

# Notify the user to reboot the server
echo "Server reset completed. It's recommended to reboot the server."
echo "Reboot now? (y/n)"
read -r REBOOT

if [ "$REBOOT" == "y" ]; then
  echo "Rebooting..."
  reboot
else
  echo "Please remember to reboot the server later to ensure all changes take effect."
fi
