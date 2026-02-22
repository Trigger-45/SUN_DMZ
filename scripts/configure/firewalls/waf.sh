#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring WAF"

# Container reference using LAB_NAME variable
WAF_CONTAINER="clab-${LAB_NAME}-Proxy_WAF"

sudo docker exec -u 0 -i \
    -e DMZ_WAF_ETH1_IP="${DMZ_WAF_ETH1_IP}" \
    -e DMZ_WAF_ETH2_IP="${DMZ_WAF_ETH2_IP}" \
    -e DMZ_WAF_ETH3_IP="${DMZ_WAF_ETH3_IP}" \
    -e SIEM_LOGSTASH_ETH1_IP="${SIEM_LOGSTASH_ETH1_IP}" \
	-e SUBNET_DMZ="${SUBNET_DMZ}" \
	-e SUBNET_BACKEND="${SUBNET_BACKEND}" \
	-e SUBNET_INTERNET="${SUBNET_INTERNET}" \
	-e EXT_FW_NAT_IP="${EXT_FW_NAT_IP}" \
    "${WAF_CONTAINER}" bash << 'EOF'
set -e

# ============================================
# Install packages
# ============================================
echo "[1/3] Installing packages..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends \
	iptables \
	iproute2 \
	iputils-ping \
	net-tools \
	ulogd2 \
	ulogd2-json \
	wget \
	curl \
	bash \
	procps \
	gnupg \
	openssl \
	ca-certificates \
	2>&1 | tail -10

# Install Filebeat
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update -qq
apt-get install -y filebeat 2>&1 | tail -10

echo "[OK] Packages installed"

# ============================================
# Create log directories
# ============================================
echo "[2/3] Creating log directories..."
mkdir -p /var/log/audit
mkdir -p /var/log/modsecurity
mkdir -p /var/log/filebeat
chmod 777 /var/log/audit
chmod 777 /var/log/modsecurity

# Create initial log file
touch /var/log/audit/audit.log
chmod 666 /var/log/audit/audit.log

echo "[OK] Log directories created"

# Restart nginx/modsecurity um neue Log-Konfiguration zu laden
echo "Restarting nginx to apply logging configuration..."
if pgrep nginx >/dev/null; then
    nginx -s reload 2>/dev/null || true
fi
sleep 2

echo "[OK] Nginx reloaded"

# ============================================
# Configure Filebeat
# ============================================
echo "[Configuring Filebeat..."

cat > /etc/filebeat/filebeat.yml << FILEBEAT_CONFIG
filebeat.inputs:
- type: log
	enabled: true
	paths:
		- /var/log/audit/audit.log
	fields:
		firewall: waf
		log_type: firewall
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

echo "[OK] Filebeat configured and started"

# ============================================
# Configure network interfaces
# ============================================
echo "[Configuring network interfaces..."
ip addr add ${DMZ_WAF_ETH3_IP} dev eth3 || true
ip link set eth3 up
ip route add ${SUBNET_BACKEND} via ${DMZ_WAF_GW%/*} dev eth3 || true

echo "[OK] Network interfaces configured"

EOF

log_ok "WAF configured"
