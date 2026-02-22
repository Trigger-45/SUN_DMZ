#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

Proxy_WAF_Container="clab-${LAB_NAME}-Proxy_WAF"


sudo docker exec -i --user root \
    -e DMZ_WAF_ETH1_IP="${DMZ_WAF_ETH1_IP}" \
    -e DMZ_WAF_ETH2_IP="${DMZ_WAF_ETH2_IP}" \
    -e INT_FW_ETH2_IP="${INT_FW_ETH2_IP}" \
    -e EXT_FW_ETH1_IP="${EXT_FW_ETH1_IP}" \
    -e SUBNET_INTERNAL="${SUBNET_INTERNAL}" \
    -e DMZ_WEB_ETH1_IP="${DMZ_WEB_ETH1_IP}" \
    "${Proxy_WAF_Container}" sh << 'EOF'
set -e

ip addr add ${DMZ_WAF_ETH1_IP} dev eth1 || true
ip addr add ${DMZ_WAF_ETH2_IP} dev eth2 || true
ip link set eth1 up
ip link set eth2 up

# IP-Route 
ip route add ${SUBNET_INTERNAL} via ${INT_FW_ETH2_IP%/*} dev eth1 || true
ip route replace default via ${EXT_FW_ETH1_IP%/*} || true
ip route add ${DMZ_WEB_ETH1_IP%/*} via ${DMZ_WAF_ETH2_IP%/*} dev eth2 || true
EOF


