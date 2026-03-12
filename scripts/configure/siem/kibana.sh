#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Siem Kibana"

SIEM_KIBANA_CONTAINER="clab-${LAB_NAME}-kibana"


log_info "Configuring Kibana network via nsenter..."

KIBANA_PID=$(sudo docker inspect -f '{{.State.Pid}}' ${SIEM_KIBANA_CONTAINER})
sudo nsenter -t $KIBANA_PID -n ip addr add ${SIEM_KIBANA_ETH1_IP} dev eth1 || true
sudo nsenter -t $KIBANA_PID -n ip addr add ${SIEM_KIBANA_ETH2_IP} dev eth2 || true
sudo nsenter -t $KIBANA_PID -n ip link set eth1 up
sudo nsenter -t $KIBANA_PID -n ip link set eth2 up
sudo nsenter -t $KIBANA_PID -n ip route replace default via ${SIEM_FW_ETH5_IP%/*} dev eth2 || true
sudo nsenter -t $KIBANA_PID -n ip route add ${SIEM_ELASTIC_ETH1_IP} via ${SIEM_ELASTIC_ETH2_IP%/*} dev eth1 || true

echo "=== Kibana Network Configuration ==="
sudo nsenter -t $KIBANA_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $KIBANA_PID -n ip route show || true

log_info "Writing Kibana configuration..."
ES_MGMT_HOST="clab-${LAB_NAME}-elasticsearch"
sudo docker exec -i -e ES_MGMT_HOST="${ES_MGMT_HOST}" "${SIEM_KIBANA_CONTAINER}" sh << 'EOF'
cat > /usr/share/kibana/config/kibana.yml << KIBANA_CONFIG
server.host: 0.0.0.0
server.name: kibana
elasticsearch.hosts: ["http://${ES_MGMT_HOST}:9200"]
elasticsearch.requestTimeout: 120000
elasticsearch.pingTimeout: 30000
xpack.encryptedSavedObjects.encryptionKey: "a7e4c9f2b8d3e1a6c5f8b2d9e4a7c1f3"
xpack.reporting.encryptionKey: "b8f3d2e9a1c7f4e6d3b9a2c8f1e5d7a4"
xpack.security.encryptionKey: "c1f8e3d7a9b4f2e6c8d1a5f9e2b7c4d3"
telemetry.optIn: false
KIBANA_CONFIG
EOF

log_info "Restarting Kibana..."
sudo docker restart "${SIEM_KIBANA_CONTAINER}" >/dev/null

log_info "Waiting for Kibana to become available..."
for _ in {1..60}; do
	if sudo docker logs "${SIEM_KIBANA_CONTAINER}" 2>&1 | tail -n 200 | grep -q "Kibana is now available"; then
		log_ok "Kibana is available"
		break
	fi
	sleep 2
done

log_ok "Kibana configured"