#!/bin/bash
# Ubuntu Server Setup Script
# This script configures Ubuntu server with:
# - Users: ommae and zootsuit
# - SSH on port 18765 (disable port 22)
# - Disable root login
# - Install Docker system-wide

set -e

echo "========================================="
echo "Ubuntu Server Configuration Script"
echo "========================================="

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Create users
echo "Creating user accounts..."
useradd -m -s /bin/bash ommae
echo 'ommae:Nolbu0728!' | chpasswd
usermod -aG sudo ommae

useradd -m -s /bin/bash zootsuit
echo 'zootsuit:Nolbu0728!' | chpasswd
usermod -aG sudo zootsuit

echo "Users created: ommae and zootsuit"

# Configure SSH
echo "Configuring SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Change SSH port to 18765 and disable root login
sed -i 's/^#Port 22/Port 18765/' /etc/ssh/sshd_config
sed -i 's/^Port 22/Port 18765/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Ensure password authentication is enabled
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Configure firewall
echo "Configuring firewall..."
apt-get install -y ufw
ufw allow 18765/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3306/tcp
ufw --force enable

# Restart SSH service
echo "Restarting SSH service..."
systemctl restart sshd

# Install Docker
echo "Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add users to docker group
usermod -aG docker ommae
usermod -aG docker zootsuit

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

# Install Docker Compose standalone (optional, as plugin is already installed)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create Docker directory structure
mkdir -p /opt/docker
chown root:docker /opt/docker
chmod 775 /opt/docker

# Verify installations
echo ""
echo "========================================="
echo "Installation Summary:"
echo "========================================="
echo "Users created: ommae, zootsuit"
echo "SSH port changed to: 18765"
echo "Root login: Disabled"
echo "Docker version:"
docker --version
echo "Docker Compose version:"
docker compose version
echo ""
echo "Docker installed at: /opt/docker/"
echo ""
echo "IMPORTANT: SSH is now running on port 18765"
echo "Connect using: ssh -p 18765 ommae@<server-ip>"
echo "or: ssh -p 18765 zootsuit@<server-ip>"
echo "========================================="