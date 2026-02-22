#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

Database_Container="clab-${LAB_NAME}-Database"

log_info "Configuring Database"
sudo docker exec -i \
    -e DMZ_DB_ETH1_IP="${DMZ_DB_ETH1_IP}" \
    -e INT_FW_ETH2_IP="${INT_FW_ETH2_IP}" \
    "${Database_Container}" sh << 'EOF'
    
set -e
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
fi

ip addr add ${DMZ_DB_ETH1_IP} dev eth1 || true
ip link set eth1 up
ip route replace default via ${INT_FW_ETH2_IP%/*} || true
EOF