#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Attacker"
sudo docker exec -i \
    -e INTERNET_ATTACKER_ETH1_IP="${INTERNET_ATTACKER_ETH1_IP}" \
    -e ROUTER_INTERNET_ETH1_IP="${ROUTER_INTERNET_ETH1_IP}" \
    "clab-${LAB_NAME}-Attacker" sh << 'EOF'
    
set -e
apt update >/dev/null 2>&1 || true
apt-get install -y iproute2 iputils-ping curl hping3 python3 >/dev/null 2>&1 || true
ip addr add ${INTERNET_ATTACKER_ETH1_IP} dev eth1 || true
ip link set eth1 up
ip route replace default via ${ROUTER_INTERNET_ETH1_IP%/*} || true
EOF

log_ok "Attacker configured"