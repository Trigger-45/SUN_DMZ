#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Internal Clients"

# ============================================
# Configure Internal Client 1
# ============================================
log_info "Configuring Internal_Client1"

sudo docker exec -i \
    -e INT_CLIENT1_ETH1_IP="${INT_CLIENT1_ETH1_IP}" \
    -e INT_DEFAULT_GW="${INT_DEFAULT_GW}" \
    -e ROUTER_INTERNET_ETH2_IP="${ROUTER_INTERNET_ETH2_IP}" \
    "clab-${LAB_NAME}-Internal_Client1" sh << 'EOF'
set -e

# Install utilities
apk add --no-cache curl >/dev/null 2>&1 || true

# Configure /etc/hosts
echo "${ROUTER_INTERNET_ETH2_IP%/*}    internet" >> /etc/hosts 2>/dev/null || true
echo ${INT_CLIENT1_ETH1_IP%/*}   
echo ${INT_DEFAULT_GW%/*}

# Configure network interface
ip addr add ${INT_CLIENT1_ETH1_IP} dev eth1 || true
ip link set eth1 up

# Set default route to Internal Firewall
ip route replace default via ${INT_DEFAULT_GW} || true

echo "[OK] Internal_Client1 configured"

EOF

log_ok "Internal_Client1 configured"

# ============================================
# Configure Internal Client 2
# ============================================
log_info "Configuring Internal_Client2"

sudo docker exec -i \
    -e INT_CLIENT2_ETH1_IP="${INT_CLIENT2_ETH1_IP}" \
    -e INT_DEFAULT_GW="${INT_DEFAULT_GW}" \
    -e ROUTER_INTERNET_ETH2_IP="${ROUTER_INTERNET_ETH2_IP}" \
    "clab-${LAB_NAME}-Internal_Client2" sh << 'EOF'
set -e

# Install utilities
apk add --no-cache curl >/dev/null 2>&1 || true

# Configure /etc/hosts
echo "${ROUTER_INTERNET_ETH2_IP%/*}    internet" >> /etc/hosts 2>/dev/null || true

# Configure network interface
ip addr add ${INT_CLIENT2_ETH1_IP} dev eth1 || true
ip link set eth1 up

# Set default route to Internal Firewall
ip route replace default via ${INT_DEFAULT_GW} || true

echo "[OK] Internal_Client2 configured"

EOF

log_ok "Internal_Client2 configured"

