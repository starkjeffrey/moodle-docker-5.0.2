#!/bin/bash

# Ubuntu 24.04 Development Tools Installation Script
# This script installs Docker, Python development tools, and compilation dependencies

set -e

echo "=========================================="
echo "Ubuntu 24.04 Development Tools Installation"
echo "=========================================="

# Update package repositories
echo "Updating package repositories..."
apt update

# Install build-essential and compilation tools
echo "Installing build-essential and compilation tools..."
apt install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    automake \
    autoconf \
    libtool \
    pkg-config \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Python development tools
echo "Installing Python development tools..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    python-is-python3 \
    pipx

# Install additional Python packages via pip
echo "Installing Python packages..."
pip3 install --upgrade pip
pip3 install \
    virtualenv \
    pipenv \
    poetry \
    black \
    flake8 \
    pylint \
    pytest \
    requests \
    numpy \
    pandas

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."

    # Remove old Docker packages if any
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt remove -y $pkg 2>/dev/null || true
    done

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update apt and install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    echo "Docker installed successfully!"
else
    echo "Docker is already installed"
fi

# Install Docker Compose standalone (in addition to plugin)
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose standalone..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Install Node.js and npm (useful for many development projects)
echo "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Install database clients
echo "Installing database clients..."
apt install -y \
    mysql-client \
    postgresql-client \
    redis-tools

# Install additional useful development tools
echo "Installing additional development tools..."
apt install -y \
    jq \
    yq \
    httpie \
    net-tools \
    dnsutils \
    iputils-ping \
    telnet \
    traceroute \
    nmap \
    tcpdump \
    iftop \
    iotop \
    ncdu \
    tmux \
    screen

# Clean up
echo "Cleaning up..."
apt autoremove -y
apt autoclean

echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Installed tools:"
echo "- Docker $(docker --version 2>/dev/null || echo 'Check installation')"
echo "- Docker Compose $(docker compose version 2>/dev/null || echo 'Check installation')"
echo "- Python $(python3 --version)"
echo "- pip $(pip3 --version)"
echo "- Node.js $(node --version 2>/dev/null || echo 'Check installation')"
echo "- npm $(npm --version 2>/dev/null || echo 'Check installation')"
echo ""
echo "To add current user to docker group (to run docker without sudo):"
echo "  sudo usermod -aG docker \$USER"
echo "  Then log out and log back in"
echo ""
echo "To verify Docker installation:"
echo "  docker run hello-world"
echo ""
echo "To start your Moodle stack:"
echo "  cd /Volumes/Projects/active/moodle-docker-5.0.2"
echo "  docker-compose -f docker-compose.moodle.yml up -d"