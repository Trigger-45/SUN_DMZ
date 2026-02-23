#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Logstash"

SIEM_LOGSTASH_CONTAINER="clab-${LAB_NAME}-logstash"


log_info "Configuring Logstash network via nsenter..."

LOGSTASH_PID=$(sudo docker inspect -f '{{.State.Pid}}' ${SIEM_LOGSTASH_CONTAINER})
sudo nsenter -t $LOGSTASH_PID -n ip addr add ${SIEM_LOGSTASH_ETH1_IP} dev eth1 || true
sudo nsenter -t $LOGSTASH_PID -n ip addr add ${SIEM_LOGSTASH_ETH2_IP} dev eth2 || true
sudo nsenter -t $LOGSTASH_PID -n ip link set eth1 up
sudo nsenter -t $LOGSTASH_PID -n ip link set eth2 up
sudo nsenter -t $LOGSTASH_PID -n ip route replace default via ${SIEM_FW_ETH3_IP%/*} dev eth1 || true

echo "=== Logstash Network Configuration ==="
sudo nsenter -t $LOGSTASH_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $LOGSTASH_PID -n ip route show || true

log_ok "Logstash configured"