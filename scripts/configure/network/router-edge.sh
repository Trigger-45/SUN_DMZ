#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Edge Router"

ROUTER_EDGE_CONTAINER="clab-${LAB_NAME}-router-edge"

sudo docker exec -i \
    -e ROUTER_EDGE_ETH1_IP="${ROUTER_EDGE_ETH1_IP}" \
    -e ROUTER_EDGE_ETH2_IP="${ROUTER_EDGE_ETH2_IP}" \
    -e SUBNET_INTERNAL="${SUBNET_INTERNAL}" \
    -e SUBNET_INTERNET="${SUBNET_INTERNET}" \
    -e EXT_FW_NAT_IP="${EXT_FW_NAT_IP}" \
    -e EXT_FW_ETH2_IP="${EXT_FW_ETH2_IP}" \
    -e ROUTER_INTERNET_ETH2_IP="${ROUTER_INTERNET_ETH2_IP}" \
    -e SUBNET_EDGE_2="${SUBNET_EDGE_2}" \
    "${ROUTER_EDGE_CONTAINER}" sh << 'EOF'
set -e
# Interfaces
ip addr add ${ROUTER_EDGE_ETH1_IP} dev eth1  # from router-internet
ip addr add ${ROUTER_EDGE_ETH2_IP} dev eth2  # to External_FW
ip link set eth1 up
ip link set eth2 up

echo 1 > /proc/sys/net/ipv4/ip_forward

# --- Allow ping from attacker ---
iptables -C INPUT -p icmp -s ${SUBNET_INTERNET} --icmp-type echo-request -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p icmp -s ${SUBNET_INTERNET} --icmp-type echo-request -j ACCEPT

# Flush rules
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow NEW traffic to/from Internet via eth1/eth2
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# --- Prevent Internal → Attacker (eth1) directly
iptables -I FORWARD 1 -s ${SUBNET_INTERNAL} -d ${SUBNET_INTERNET} -m conntrack --ctstate NEW -j DROP

ip route add ${SUBNET_INTERNAL} via ${ROUTER_EDGE_ETH1_IP%/*} || true
ip route add ${SUBNET_INTERNET} dev eth1 || true
ip route add ${SUBNET_EDGE_2} via ${ROUTER_EDGE_ETH1_IP%/*} dev eth2 || true

# Routing
ip route replace ${SUBNET_INTERNAL} via ${EXT_FW_ETH2_IP%/*}
ip route replace ${SUBNET_INTERNET} via ${ROUTER_INTERNET_ETH2_IP%/*}
ip route add ${EXT_FW_NAT_IP} via ${EXT_FW_ETH2_IP%/*} dev eth2 || true
EOF

log_ok "router-edge configured"