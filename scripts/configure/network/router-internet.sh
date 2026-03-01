#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Internet Router"

ROUTER_INTERNET_CONTAINER="clab-${LAB_NAME}-router-internet"

log_info "Configuring router-internet"
sudo docker exec -i \
    -e ROUTER_INTERNET_ETH1_IP="${ROUTER_INTERNET_ETH1_IP}" \
    -e ROUTER_INTERNET_ETH2_IP="${ROUTER_INTERNET_ETH2_IP}" \
    -e SUBNET_INTERNAL="${SUBNET_INTERNAL}" \
    -e SUBNET_INTERNET="${SUBNET_INTERNET}" \
    -e SUBNET_EDGE_2="${SUBNET_EDGE_2}" \
    -e ROUTER_EDGE_ETH1_IP="${ROUTER_EDGE_ETH1_IP}" \
    -e ROUTER_EDGE_ETH2_IP="${ROUTER_EDGE_ETH2_IP}" \
    "${ROUTER_INTERNET_CONTAINER}" sh << 'EOF'
set -e
# ensure tooling
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping iptables curl >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils iptables curl >/dev/null 2>&1 || true
fi

# Interfaces: eth1 <-> Attacker, eth2 <-> router-edge
ip addr add "${ROUTER_INTERNET_ETH1_IP}" dev eth1 || true
ip addr add "${ROUTER_INTERNET_ETH2_IP}" dev eth2 || true

ip link set eth1 up
ip link set eth2 up

# Activate forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward || true


iptables -P FORWARD ACCEPT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT


ip route add "${SUBNET_INTERNAL}" via "${ROUTER_EDGE_ETH1_IP%/*}" || true
ip route add "${SUBNET_INTERNET}" dev eth1 || true
ip route add "${SUBNET_EDGE_2}" via "${ROUTER_EDGE_ETH2_IP%/*}" dev eth2 || true
EOF

log_ok "router-internet configured"