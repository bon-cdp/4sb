#!/bin/bash
# 4sb Terminal VM Startup Script
# Simple, fast, works.

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== 4sb Terminal VM Starting ==="

# Install essentials
apt-get update
apt-get install -y \
    git \
    python3 \
    python3-pip \
    curl \
    vim \
    nano \
    tmux \
    htop \
    build-essential

# Install ttyd (single binary web terminal - battle tested)
curl -sL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd

# Create user
useradd -m -s /bin/bash user 2>/dev/null || true
echo "user:user" | chpasswd
mkdir -p /home/user
chown user:user /home/user

# Nice prompt for users
cat >> /home/user/.bashrc << 'EOF'
export PS1='\[\033[1;32m\]\u@4sb\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]$ '
echo ""
echo "  Welcome to 4sb.io - Your cloud terminal"
echo "  ----------------------------------------"
echo "  git, python3, vim, nano - all ready"
echo ""
EOF

# Create systemd service for ttyd
cat > /etc/systemd/system/ttyd.service << 'EOF'
[Unit]
Description=4sb Web Terminal
After=network.target

[Service]
Type=simple
User=user
WorkingDirectory=/home/user
ExecStart=/usr/local/bin/ttyd -p 8080 -W bash
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ttyd
systemctl start ttyd

echo "=== 4sb Terminal Ready on :8080 ==="
