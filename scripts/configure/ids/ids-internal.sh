#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Internal IDS"

INTERNAL_IDS_CONTAINER="clab-${LAB_NAME}-Internal_IDS"

# Download and copy Filebeat RPM
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.10.0-x86_64.rpm
sudo docker cp filebeat-8.10.0-x86_64.rpm ${INTERNAL_IDS_CONTAINER}:/tmp/filebeat.rpm

sudo docker exec -i \
    -e SIEM_LOGSTASH_ETH1_IP="${SIEM_LOGSTASH_ETH1_IP}" \
    -e SUBNET_BACKEND="${SUBNET_BACKEND}" \
    -e DMZ_WEB_ETH1_IP="${DMZ_WEB_ETH1_IP}" \
    -e IDS_INT_ETH2_IP="${IDS_INT_ETH2_IP}" \
    -e SIEM_FW_ETH8_IP="${SIEM_FW_ETH8_IP}" \
    "${INTERNAL_IDS_CONTAINER}" bash << 'EOF'
set -e

# ============================================
# Install Filebeat
# ============================================
echo "[1/3] Installing Filebeat..."

cd /tmp
rpm -ivh --force filebeat.rpm

echo "[OK] Filebeat installed"

# ============================================
# Configure Filebeat
# ============================================
echo "[2/3] Configuring Filebeat..."
cat > /etc/filebeat/filebeat.yml << 'FILEBEAT_CONFIG'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/suricata/eve.json
  json.keys_under_root: true
  json.add_error_key: true
  fields:
    ids: internal
    log_type: ids
  fields_under_root: true

output.logstash:
  hosts: ["${SIEM_LOGSTASH_ETH1_IP%/*}:5044"]

path.data: /var/lib/filebeat
logging.level: warning
FILEBEAT_CONFIG

chmod 644 /etc/filebeat/filebeat.yml

# Start Filebeat
nohup filebeat -e -c /etc/filebeat/filebeat.yml > /var/log/filebeat.log 2>&1 &
sleep 2

echo "[OK] Filebeat started"

# ============================================
# Configure network interfaces
# ============================================
echo "[3/3] Configuring network interfaces..."
ip addr add ${DMZ_WEB_ETH1_IP} dev eth1 || true
ip addr add ${IDS_INT_ETH2_IP} dev eth2 || true
ip link set eth1 up
ip link set eth2 up
ip route add ${SUBNET_BACKEND} via ${SIEM_FW_ETH8_IP%/*} dev eth2 || true

echo "[OK] Network interfaces configured"

EOF

log_ok "Internal IDS configured"