#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Flask Webserver"

DMZ_WEB_CONTAINER="clab-${LAB_NAME}-Flask_Webserver"


log_info "Configuring Flask Webserver"
sudo docker exec -i --user root ${DMZ_WEB_CONTAINER} mkdir -p /app
sudo docker cp ${CONFIG_DIR}/webserver-details/app.py ${DMZ_WEB_CONTAINER}:/app/app.py
sudo docker exec -i --user root \
    -e DMZ_WEB_ETH1_IP="${DMZ_WEB_ETH1_IP}" \
    -e DMZ_WEB_ETH2_IP="${DMZ_WEB_ETH2_IP}" \
    -e DMZ_WAF_ETH2_IP="${DMZ_WAF_ETH2_IP}" \
    -e DMZ_DB_ETH1_IP="${DMZ_DB_ETH1_IP}" \
    "${DMZ_WEB_CONTAINER}" sh << 'EOF'
set -e

#install dependencies
echo "[1/2] Installing dependencies..."
apt-get update && \
apt-get install -y --no-install-recommends \
    iproute2 \
    iputils-ping \
    python3 \
    python3-flask \
    python3-psycopg2 \
    libpq-dev \
    build-essential \
    openssl \
    2>&1 | tail -10

echo "[OK] Dependencies installed"
#start webserver on port 5000
cd /app && python3 app.py &

ip addr add "${DMZ_WEB_ETH1_IP}" dev eth1 || true
ip addr add "${DMZ_WEB_ETH2_IP}" dev eth2 || true
ip link set eth1 up
ip link set eth2 up

ip route replace default via "${DMZ_WAF_ETH2_IP%/*}" || true
ip route add "${DMZ_DB_ETH1_IP%/*}" via "${DMZ_WEB_ETH2_IP%/*}" dev eth2 || true

EOF
echo "[OK] Flask Webserver started"
echo ""
log_ok "DMZ configured"