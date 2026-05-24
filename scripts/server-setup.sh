#!/bin/bash
# =============================================================
# AI Resume Analyzer — EC2 Server Setup Script
# =============================================================
# Run this script on a fresh Ubuntu 22.04 EC2 instance to
# install Docker, Docker Compose, configure firewall, and
# prepare for deployment.
#
# Usage: chmod +x scripts/server-setup.sh && sudo ./scripts/server-setup.sh
# =============================================================

set -e

echo "========================================="
echo "🚀 AI Resume Analyzer — Server Setup"
echo "========================================="

# ---- Step 1: System Update ----
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# ---- Step 2: Install Docker Engine ----
echo "🐳 Installing Docker..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group (so docker commands don't need sudo)
usermod -aG docker ubuntu

echo "✅ Docker installed: $(docker --version)"

# ---- Step 3: Install Docker Compose v2 ----
echo "🐳 Installing Docker Compose..."
mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "✅ Docker Compose installed: $(docker compose version)"

# ---- Step 4: Configure UFW Firewall ----
echo "🔒 Configuring UFW firewall..."
apt install -y ufw

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3001/tcp  # Grafana (restrict to your IP in production)
ufw --force enable

echo "✅ UFW firewall configured and enabled"

# ---- Step 5: Install Fail2Ban (Brute-Force Protection) ----
echo "🛡️ Installing Fail2Ban..."
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "✅ Fail2Ban installed and running"

# ---- Step 6: Install Certbot (SSL Certificates) ----
echo "🔐 Installing Certbot for SSL..."
apt install -y certbot

echo "✅ Certbot installed"
echo ""
echo "To generate SSL certificates, run:"
echo "  sudo certbot certonly --standalone -d yourdomain.com --non-interactive --agree-tos --email your@email.com"
echo ""

# ---- Step 7: Configure Docker Logging (Log Rotation) ----
echo "📋 Configuring Docker log rotation..."
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker
echo "✅ Docker log rotation configured (10MB max, 3 files)"

# ---- Step 8: Clone Repository ----
echo "📂 Setting up project directory..."
if [ ! -d "/home/ubuntu/ai-resume-analyzer" ]; then
    cd /home/ubuntu
    git clone https://github.com/YOUR_USERNAME/ai-resume-analyzer.git
    chown -R ubuntu:ubuntu ai-resume-analyzer
    echo "✅ Repository cloned"
else
    echo "ℹ️  Repository already exists at /home/ubuntu/ai-resume-analyzer"
fi

echo ""
echo "========================================="
echo "✅ Server setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group to take effect)"
echo "  2. cd ~/ai-resume-analyzer"
echo "  3. Update .env with your settings"
echo "  4. Point your domain DNS A record to this server's Elastic IP"
echo "  5. Run: sudo certbot certonly --standalone -d yourdomain.com"
echo "  6. Copy certs: mkdir -p certbot/conf && sudo cp -rL /etc/letsencrypt/* certbot/conf/"
echo "  7. Enable HTTPS block in docker/nginx/default.conf"
echo "  8. Run: docker compose up -d --build"
echo "  9. Open http://YOUR_IP to verify the app"
echo " 10. Open http://YOUR_IP:3001 for Grafana (admin/admin)"
echo ""
