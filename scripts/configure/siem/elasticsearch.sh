#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Siem Elasticsearch"

SIEM_elasticsearch_CONTAINER="clab-${LAB_NAME}-elasticsearch"


log_info "Configuring Elasticsearch network via nsenter..."

ELASTICSEARCH_PID=$(sudo docker inspect -f '{{.State.Pid}}' ${SIEM_elasticsearch_CONTAINER})
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add ${SIEM_ELASTIC_ETH1_IP} dev eth1 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add ${SIEM_ELASTIC_ETH2_IP} dev eth2 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add ${SIEM_ELASTIC_ETH3_IP} dev eth3 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth1 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth2 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth3 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip route replace default via ${SIEM_FW_ETH4_IP%/*} dev eth3 || true

echo "=== Elasticsearch Network Configuration ==="
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip route show || true

log_ok "Elasticsearch configured"