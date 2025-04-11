#!/bin/bash
sudo apt update && sudo apt upgrade -y

# Nagios Core Auto Installer Script
# Tested on Ubuntu-based systems

set -e

# Update system
echo "[+] Updating system packages..."
sudo apt update

# Install required dependencies
echo "[+] Installing required packages..."
sudo apt install -y wget unzip curl openssl build-essential libgd-dev libssl-dev libapache2-mod-php php-gd php apache2 nagios-plugins nagios-nrpe-server

# Variables
NAGIOS_VERSION="4.4.6"
NAGIOS_PLUGIN_VERSION="2.3.3"
NAGIOS_USER="nagios"
NAGIOS_GROUP="nagios"
ADMIN_USER="admin"
NAGIOS_DOWNLOAD_URL="https://assets.nagios.com/downloads/nagioscore/releases/nagios-${NAGIOS_VERSION}.tar.gz"
PLUGIN_DOWNLOAD_URL="https://nagios-plugins.org/download/nagios-plugins-${NAGIOS_PLUGIN_VERSION}.tar.gz"

# Download and extract Nagios Core
echo "[+] Downloading Nagios Core..."
wget $NAGIOS_DOWNLOAD_URL -O nagios.tar.gz
sudo tar -zxvf nagios.tar.gz
cd nagios-${NAGIOS_VERSION}

# Configure and build Nagios
echo "[+] Configuring Nagios..."
sudo ./configure
sudo make all
sudo make install-groups-users
sudo usermod -a -G nagios www-data
sudo make install
sudo make install-init
sudo make install-commandmode
sudo make install-config
sudo make install-webconf

# Enable Apache modules and restart Apache
echo "[+] Enabling Apache modules..."
sudo a2enmod rewrite
sudo a2enmod cgi
sudo systemctl restart apache2

# Create Nagios admin user
echo "[+] Creating Nagios web user (admin)..."
sudo htpasswd -cb /usr/local/nagios/etc/htpasswd.users $ADMIN_USER "admin"

# Install Nagios Plugins
cd ~/
echo "[+] Downloading Nagios Plugins..."
wget $PLUGIN_DOWNLOAD_URL -O plugins.tar.gz
sudo tar -zxvf plugins.tar.gz
cd nagios-plugins-${NAGIOS_PLUGIN_VERSION}
sudo ./configure --with-nagios-user=$NAGIOS_USER --with-nagios-group=$NAGIOS_GROUP
sudo make
sudo make install

# Verify Nagios configuration
echo "[+] Verifying Nagios configuration..."
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Start and enable Nagios
echo "[+] Starting and enabling Nagios service..."
sudo systemctl start nagios
sudo systemctl enable nagios

echo -e "\n[✓] Nagios Core installation completed!"
echo "Access the Nagios Web Interface at: http://<your_server_ip>/nagios"
echo "Login with username: admin and password: admin"

# Setup remote host template
echo "[+] Creating remote host config template..."
sudo mkdir -p /usr/local/nagios/etc/servers
cat << 'EOF' | sudo tee /usr/local/nagios/etc/servers/host.cfg >/dev/null
define host {
        use                             linux-server
        host_name                       yourhost
        alias                           My first Apache server
        address                         1.2.3.4
        max_check_attempts              5
        check_period                    24x7
        notification_interval           30
        notification_period             24x7
}
EOF

# Include the custom host config in nagios.cfg if not already included
if ! grep -q "^cfg_dir=/usr/local/nagios/etc/servers" /usr/local/nagios/etc/nagios.cfg; then
    echo "cfg_dir=/usr/local/nagios/etc/servers" | sudo tee -a /usr/local/nagios/etc/nagios.cfg >/dev/null
fi

# Reload Nagios
echo "[+] Reloading Nagios to apply configuration..."
sudo service nagios reload

echo -e "\n[✓] Remote host template added. Modify /usr/local/nagios/etc/servers/host.cfg to suit your setup."
echo -e "[!] Remember to update the 'address' and 'host_name' fields with your actual host details.\n"
