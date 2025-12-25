#!/bin/bash
# 4sb Terminal VM Startup Script
# This runs when a new VM boots

set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== 4sb Terminal VM Starting ==="

# Install dependencies
apt-get update
apt-get install -y \
    build-essential \
    cmake \
    libboost-system-dev \
    git \
    python3 \
    python3-pip \
    curl \
    vim \
    nano \
    tmux \
    htop

# Create user home directory structure
useradd -m -s /bin/bash user 2>/dev/null || true
mkdir -p /home/user
chown user:user /home/user

# Clone and build the bridge (in production, use pre-built image)
cd /opt
if [ ! -d "4sb" ]; then
    # For now, we'll build from source
    # In production, pull pre-built binary from GCS
    mkdir -p 4sb/bridge
    cat > 4sb/bridge/simple-bridge.cpp << 'BRIDGE_EOF'
// Simplified bridge for initial deployment
// Replace with full bridge after container setup

#include <iostream>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pty.h>
#include <thread>
#include <vector>
#include <algorithm>

int main() {
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(8080);

    bind(server_fd, (sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 10);

    std::cout << "4sb bridge listening on :8080" << std::endl;

    while (true) {
        int client = accept(server_fd, nullptr, nullptr);
        std::cout << "Connection accepted" << std::endl;

        // Simple echo for health checks
        char buf[1024];
        ssize_t n = recv(client, buf, sizeof(buf), 0);
        if (n > 0 && strncmp(buf, "GET /health", 11) == 0) {
            const char* resp = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok";
            send(client, resp, strlen(resp), 0);
        }
        close(client);
    }

    return 0;
}
BRIDGE_EOF

    g++ -o /usr/local/bin/4sb-bridge 4sb/bridge/simple-bridge.cpp -pthread
fi

# Create systemd service
cat > /etc/systemd/system/4sb-bridge.service << 'SERVICE_EOF'
[Unit]
Description=4sb Terminal Bridge
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/4sb-bridge
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable 4sb-bridge
systemctl start 4sb-bridge

# Signal that we're ready (for the pool manager)
curl -s -X POST "http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/4sb/status" \
    -H "Metadata-Flavor: Google" \
    -d "ready" 2>/dev/null || true

echo "=== 4sb Terminal VM Ready ==="
