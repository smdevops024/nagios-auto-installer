# 🔧 Nagios Auto Installer Script

This script provides an **automated setup** of Nagios Core along with necessary plugins and monitoring configuration on a Debian/Ubuntu-based system.

## 📦 Features

- Installs Nagios Core and required dependencies
- Configures Apache for Nagios Web UI
- Adds Nagios plugins
- Sets up monitoring for remote hosts using NRPE
- Includes sample host configuration for quick deployment

---

## 🖥️ Requirements

- Ubuntu/Debian-based Linux system
- Root or sudo privileges
- Internet connection (to download packages and files)

---

## 🚀 How to Use
```bash
git clone https://github.com/smdevops024/nagios-auto-installer.git
cd nagios-auto-installer
chmod +x nagios_install.sh
sudo ./nagios_install.sh

## 🌐 Access Nagios Web UI

After installation, open a browser and navigate to:

```
http://<your-server-ip>/nagios
```

- **Username:** `admin`
- **Password:** (set during installation)

---

## 🧩 Add Remote Hosts

To monitor remote machines:

1. Install NRPE and plugins on the remote host:
   ```bash
   sudo apt-get install nagios-nrpe-server nagios-plugins
   ```

2. Configure `/etc/nagios/nrpe.cfg`:
   - Set `server_address` to remote host IP
   - Set `allowed_hosts` to Nagios server IP

3. Restart NRPE:
   ```bash
   sudo service nagios-nrpe-server restart
   ```

4. Back on the Nagios server, create a host file:
   ```bash
   sudo nano /usr/local/nagios/etc/servers/yourhost.cfg
   ```

5. Reload Nagios:
   ```bash
   sudo service nagios reload
   ```

---

## 📁 Project Structure

```bash
nagios-auto-installer/
├── install_nagios.sh   # Main auto-installation script
└── README.md           # Project documentation (you are here)
```

---

## 🤝 Contributing

Pull requests are welcome! If you have suggestions, feel free to open an issue or fork the repo and submit a PR.

---

## 📜 License

MIT License. Use this freely for personal or commercial use.

---

## 📞 Contact

For support or queries, feel free to reach out via GitHub Issues.
