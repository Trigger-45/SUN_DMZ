#!/bin/bash

set -e  # Exit on error

# Detect OS (Debian or Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Fehler: Kann Betriebssystem nicht erkennen"
    exit 1
fi

if [ "$OS" != "debian" ] && [ "$OS" != "ubuntu" ]; then
    echo "Fehler: Nur Debian und Ubuntu werden unterstützt"
    exit 1
fi

echo "=== Erkanntes System: $OS ==="

echo "=== Docker Installation ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/$OS/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/$OS
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
sudo docker run hello-world

echo "=== Containerlab Installation ==="
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"
containerlab version check

echo "=== PostgreSQL Installation ==="
sudo apt-get install -y postgresql postgresql-client
sudo systemctl start postgresql
sudo systemctl enable postgresql

echo "=== DMZ.sh ausführbar machen ==="
[ -f "DMZ.sh" ] && sudo chmod +x DMZ.sh || echo "DMZ.sh nicht gefunden"

echo ""
echo "✓ Installation abgeschlossen!"
echo "Tipp: sudo usermod -aG docker $USER"