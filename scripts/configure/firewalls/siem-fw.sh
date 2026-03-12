#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring Siem Firewall"

SIEM_FW_CONTAINER="clab-${LAB_NAME}-SIEM_FW"


sudo docker exec -i \
    -e SIEM_FW_ETH1_IP="${SIEM_FW_ETH1_IP}" \
    -e SIEM_FW_ETH2_IP="${SIEM_FW_ETH2_IP}" \
    -e SIEM_FW_ETH3_IP="${SIEM_FW_ETH3_IP}" \
    -e SIEM_FW_ETH4_IP="${SIEM_FW_ETH4_IP}" \
    -e SIEM_FW_ETH5_IP="${SIEM_FW_ETH5_IP}" \
    -e SIEM_FW_ETH6_IP="${SIEM_FW_ETH6_IP}" \
    -e SIEM_FW_ETH7_IP="${SIEM_FW_ETH7_IP}" \
    -e SIEM_FW_ETH8_IP="${SIEM_FW_ETH8_IP}" \
    -e SIEM_FW_ETH9_IP="${SIEM_FW_ETH9_IP}" \
    -e SIEM_PC_ETH1_IP="${SIEM_PC_ETH1_IP}" \
    -e SIEM_KIBANA_ETH2_IP="${SIEM_KIBANA_ETH2_IP}" \
    -e SIEM_ELASTIC_ETH1_IP="${SIEM_ELASTIC_ETH1_IP}" \
    -e SIEM_ELASTIC_ETH2_IP="${SIEM_ELASTIC_ETH2_IP}" \
    -e SIEM_ELASTIC_ETH3_IP="${SIEM_ELASTIC_ETH3_IP}" \
    -e INT_FW_ETH4_IP="${INT_FW_ETH4_IP}" \
    -e SIEM_LOGSTASH_ETH1_IP="${SIEM_LOGSTASH_ETH1_IP}" \
    -e EXT_FW_ETH3_IP="${EXT_FW_ETH3_IP}" \
    -e SIEM_KIBANA_ETH1_IP="${SIEM_KIBANA_ETH1_IP}" \
    -e IDS_DMZ_ETH2_IP="${IDS_DMZ_ETH2_IP}" \
    -e DMZ_WAF_ETH3_IP="${DMZ_WAF_ETH3_IP}" \
 "${SIEM_FW_CONTAINER}" bash <<'EOF'
set -e

apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends \
		iptables \
		iproute2 \
		iputils-ping

echo "[OK] Packages installed"

echo "Configuring SIEM_FW interfaces and routing..."

ip addr add "${SIEM_FW_ETH1_IP}" dev eth1 2>/dev/null || true
ip addr add "${SIEM_FW_ETH2_IP}" dev eth2 2>/dev/null || true
ip addr add "${SIEM_FW_ETH3_IP}" dev eth3 2>/dev/null || true
ip addr add "${SIEM_FW_ETH4_IP}" dev eth4 2>/dev/null || true
ip addr add "${SIEM_FW_ETH5_IP}" dev eth5 2>/dev/null || true
ip addr add "${SIEM_FW_ETH6_IP}" dev eth6 2>/dev/null || true
ip addr add "${SIEM_FW_ETH8_IP}" dev eth8 2>/dev/null || true
ip addr add "${SIEM_FW_ETH9_IP}" dev eth9 2>/dev/null || true
ip addr add "${SIEM_FW_ETH7_IP}" dev eth7 2>/dev/null || true
# Activate Interfaces
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
ip link set eth5 up
ip link set eth6 up
ip link set eth7 up
ip link set eth8 up
ip link set eth9 up

# Activate IP Forwarding
# Activate IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[OK] Network configured"

# Disable ICMP redirects
sysctl -w net.ipv4.conf.all.send_redirects=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.send_redirects=0 >/dev/null 2>&1 || true

# Disable rp_filter for flexible routing
# Disable rp_filter for flexible routing
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true

# Flush all rules
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X 2>/dev/null || true

# Default DROP policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# INPUT Chain - allow management
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/sec -j ACCEPT

# FORWARD Chain - Explicit Allow Rules

# 1. Admin_PC → Kibana (Port 5601)
iptables -A FORWARD -s "${SIEM_PC_ETH1_IP%/*}" -d "${SIEM_KIBANA_ETH2_IP%/*}" -p tcp --dport 5601 -m conntrack --ctstate NEW -j ACCEPT

# 2.  Admin_PC → Elasticsearch (Port 9200)
iptables -A FORWARD -s "${SIEM_PC_ETH1_IP%/*}" -d "${SIEM_ELASTIC_ETH3_IP%/*}" -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${SIEM_PC_ETH1_IP%/*}" -d "${SIEM_ELASTIC_ETH1_IP%/*}" -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT

# 3.  Firewall-Filebeats → Logstash (Port 5044)
iptables -A FORWARD -s "${INT_FW_ETH4_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p tcp --dport 5044 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${INT_FW_ETH4_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p icmp -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${EXT_FW_ETH3_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p tcp --dport 5044 -m conntrack --ctstate NEW -j ACCEPT

# 4.  Logstash → Elasticsearch (Port 9200)
iptables -A FORWARD -s "${SIEM_LOGSTASH_ETH1_IP%/*}" -d "${SIEM_ELASTIC_ETH1_IP%/*}" -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT

# 5. Kibana → Elasticsearch (Port 9200)
iptables -A FORWARD -s "${SIEM_KIBANA_ETH1_IP%/*}" -d "${SIEM_ELASTIC_ETH1_IP%/*}" -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${SIEM_KIBANA_ETH2_IP%/*}" -d "${SIEM_ELASTIC_ETH1_IP%/*}" -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT

# 6. IDS → Logstash (Port 5045 for IDS/suricata logs)
iptables -A FORWARD -s "${IDS_DMZ_ETH2_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p tcp --dport 5045 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${SIEM_KIBANA_ETH1_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p tcp --dport 5045 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "${DMZ_WAF_ETH3_IP%/*}" -d "${SIEM_LOGSTASH_ETH1_IP%/*}" -p tcp --dport 5045 -m conntrack --ctstate NEW -j ACCEPT

# 7.  Established/Related connections
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 8. Log dropped packets
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "[SIEM_FW-DROP] " --log-level 7

EOF

log_ok "SIEM_FW configured"