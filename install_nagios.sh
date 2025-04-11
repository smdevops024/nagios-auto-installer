#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
LOGFILE="/var/log/nagios_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

NAGIOS_VERSION="4.4.6"
PLUGIN_VERSION="2.3.3"
NAGIOS_USER="nagios"
NAGIOS_GROUP="nagios"
ADMIN_USER="admin"
ADMIN_PASS="admin"
NAGIOS_URL="https://assets.nagios.com/downloads/nagioscore/releases/nagios-${NAGIOS_VERSION}.tar.gz"
PLUGIN_URL="https://nagios-plugins.org/download/nagios-plugins-${PLUGIN_VERSION}.tar.gz"
NRPE_URL="https://github.com/NagiosEnterprises/nrpe/archive/refs/tags/4.1.0.tar.gz"
CHECK_DOCKER_URL="https://github.com/Grimthorr/check_docker/archive/refs/heads/master.zip"
REMOTE_CFG_DIR="/usr/local/nagios/etc/servers"
HOST_CFG="${REMOTE_CFG_DIR}/host.cfg"
NAGIOS_CFG="/usr/local/nagios/etc/nagios.cfg"

trap 'echo -e "\n[✗] Error occurred on line $LINENO. See $LOGFILE for details."' ERR

# === UTILITIES ===
retry() {
  local n=1
  local max=3
  local delay=5
  until "$@"; do
    if (( n >= max )); then
      echo "[✗] Command failed after $n attempts: $*" >&2
      return 1
    else
      echo "[!] Attempt $n failed. Retrying in $delay sec..."
      sleep $delay
      ((n++))
    fi
  done
}

fix_missing_deps() {
  echo "[*] Fixing broken packages if any..."
  sudo apt --fix-broken install -y || true
  sudo dpkg --configure -a || true
  sudo apt install -f -y || true
}

check_network() {
  echo "[+] Checking internet connectivity..."
  if ! ping -c 1 8.8.8.8 &>/dev/null; then
    echo "[✗] No internet connection. Please check your network."
    exit 1
  fi
}

ensure_service_running() {
  local svc=$1
  if ! systemctl is-active --quiet "$svc"; then
    echo "[!] $svc not running. Starting..."
    sudo systemctl restart "$svc"
    sudo systemctl enable "$svc"
  fi
}

# === INSTALLATION STEPS ===
install_dependencies() {
  echo "[+] Installing dependencies..."
  retry sudo apt update
  retry sudo apt upgrade -y
  retry sudo apt install -y wget unzip curl openssl build-essential libgd-dev libssl-dev \
    libapache2-mod-php php-gd php apache2 nagios-plugins nagios-nrpe-server
  fix_missing_deps
  echo -e "\e[1;32m[✓] Dependencies installed.\e[0m"
}

install_nagios_core() {
  echo "[+] Installing Nagios Core..."
  cd ~
  retry wget -q "$NAGIOS_URL" -O nagios.tar.gz
  tar -xzf nagios.tar.gz
  cd nagios-${NAGIOS_VERSION}
  retry ./configure
  retry make all
  sudo make install-groups-users
  sudo usermod -aG $NAGIOS_GROUP www-data
  sudo make install
  sudo make install-init
  sudo make install-commandmode
  sudo make install-config
  sudo make install-webconf
  echo -e "\e[1;32m[✓] Nagios Core installed.\e[0m"
}

configure_apache() {
  echo "[+] Configuring Apache..."
  sudo a2enmod rewrite cgi
  ensure_service_running apache2
  sudo htpasswd -cb "/usr/local/nagios/etc/htpasswd.users" $ADMIN_USER $ADMIN_PASS
  echo -e "\e[1;32m[✓] Apache configured and admin user created.\e[0m"
}

install_plugins() {
  echo "[+] Installing Nagios Core Plugins..."
  cd ~
  retry wget -q "$PLUGIN_URL" -O plugins.tar.gz
  tar -xzf plugins.tar.gz
  cd nagios-plugins-${PLUGIN_VERSION}
  retry ./configure --with-nagios-user=$NAGIOS_USER --with-nagios-group=$NAGIOS_GROUP
  retry make
  sudo make install
  echo -e "\e[1;32m[✓] Nagios plugins installed.\e[0m"
}

install_nrpe() {
  echo "[+] Installing NRPE..."
  cd ~
  retry wget -q "$NRPE_URL" -O nrpe.tar.gz
  tar -xzf nrpe.tar.gz
  cd nrpe-4.1.0
  retry ./configure --enable-command-args
  retry make all
  sudo make install
  sudo make install-config
  sudo make install-init
  ensure_service_running nrpe
  echo -e "\e[1;32m[✓] NRPE installed.\e[0m"
}

install_check_docker() {
  echo "[+] Installing Docker plugin..."
  cd /usr/local/nagios/libexec
  retry wget -q "$CHECK_DOCKER_URL" -O check_docker.zip
  unzip -o check_docker.zip
  cp check_docker*/check_docker.py check_docker
  chmod +x check_docker
  echo -e "\e[1;32m[✓] check_docker plugin installed.\e[0m"
}

install_custom_plugins() {
  echo "[+] Installing CPU and Memory check plugins..."
  cd /usr/local/nagios/libexec
  retry wget -q https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_cpu.sh -O check_cpu
  chmod +x check_cpu
  retry wget -q https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_mem.sh -O check_mem
  chmod +x check_mem
  echo -e "\e[1;32m[✓] Custom plugins installed.\e[0m"
}

verify_and_start_nagios() {
  echo "[+] Verifying Nagios configuration..."
  sudo /usr/local/nagios/bin/nagios -v "$NAGIOS_CFG"
  ensure_service_running nagios
  echo -e "\e[1;32m[✓] Nagios running and verified.\e[0m"
}

setup_host_template() {
  echo "[+] Setting up remote host template..."
  sudo mkdir -p "$REMOTE_CFG_DIR"
  cat <<EOF | sudo tee "$HOST_CFG" >/dev/null
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
  grep -q "^cfg_dir=${REMOTE_CFG_DIR}" "$NAGIOS_CFG" || \
    echo "cfg_dir=${REMOTE_CFG_DIR}" | sudo tee -a "$NAGIOS_CFG" >/dev/null
  sudo systemctl reload nagios
  echo -e "\e[1;32m[✓] Host template configured.\e[0m"
}

print_success_banner() {
  SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
  echo -e "\n\e[1;32m============================================\e[0m"
  echo -e "\e[1;32m      🎉 NAGIOS INSTALLATION SUCCESSFUL 🎉     \e[0m"
  echo -e "\e[1;32m============================================\e[0m"
  echo -e "\e[1;34m  Web Interface: http://${SERVER_IP}/nagios\e[0m"
  echo -e "\e[1;34m  Login: $ADMIN_USER / $ADMIN_PASS\e[0m"
  echo -e "\e[1;32m============================================\e[0m"
  echo -e "\n\e[1;33mNext Steps:\e[0m"
  echo -e "  - Update $HOST_CFG with your actual host details"
  echo -e "  - Add service checks as needed"
  echo -e "  - Reload Nagios with: \e[1;37msudo systemctl reload nagios\e[0m"
  echo -e "\n\e[1;32mHappy Monitoring! 🖥️\e[0m"
}

# === MAIN EXECUTION FLOW ===
check_network
install_dependencies
install_nagios_core
configure_apache
install_plugins
install_nrpe
install_check_docker
install_custom_plugins
verify_and_start_nagios
setup_host_template
print_success_banner
exit 0
