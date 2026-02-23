#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Siem_PC"

SIEM_PC_CONTAINER="clab-${LAB_NAME}-siem_pc"



log_info "Configuring Siem_PC"
sudo docker exec -i \
    -e SIEM_PC_ETH1_IP="${SIEM_PC_ETH1_IP}" \
    -e SIEM_FW_ETH6_IP="${SIEM_FW_ETH6_IP}" \
 "${SIEM_PC_CONTAINER}" sh << 'EOF'
set -e
apk add --no-cache curl >/dev/null 2>&1 || true
ip addr add ${SIEM_PC_ETH1_IP} dev eth1 || true
ip link set eth1 up
ip route replace default via ${SIEM_FW_ETH6_IP%/*} || true
EOF

log_ok "Siem_PC configured"