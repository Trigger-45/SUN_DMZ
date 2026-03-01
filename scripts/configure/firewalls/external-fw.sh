#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

log_info "Configuring External Firewall"

EXTERNAL_FW_CONTAINER="clab-${LAB_NAME}-External_FW"


sudo docker exec -i \
    -e EXT_FW_ETH1_IP="${EXT_FW_ETH1_IP}" \
    -e EXT_FW_ETH2_IP="${EXT_FW_ETH2_IP}" \
    -e EXT_FW_ETH3_IP="${EXT_FW_ETH3_IP}" \
    -e EXT_FW_ETH4_IP="${EXT_FW_ETH4_IP}" \
    -e SIEM_LOGSTASH_ETH1_IP="${SIEM_LOGSTASH_ETH1_IP}" \
	-e ROUTER_EDGE_ETH2_IP="${ROUTER_EDGE_ETH2_IP}" \
	-e INT_FW_ETH3_IP="${INT_FW_ETH3_IP}" \
	-e SUBNET_EDGE_1="${SUBNET_EDGE_1}" \
	-e SUBNET_INTERNAL="${SUBNET_INTERNAL}" \
	-e SUBNET_BACKEND="${SUBNET_BACKEND}" \
	-e SUBNET_INTERNET="${SUBNET_INTERNET}" \
	-e SUBNET_DMZ="${SUBNET_DMZ}" \
	-e SUBNET_BETWEEN_FW="${SUBNET_BETWEEN_FW}" \
	-e DMZ_WAF_ETH1_IP="${DMZ_WAF_ETH1_IP}" \
    -e EXT_FW_NAT_IP="${EXT_FW_NAT_IP}" \
	-e SIEM_FW_ETH2_IP="${SIEM_FW_ETH2_IP}" \
    "${EXTERNAL_FW_CONTAINER}" bash << 'EOF'


set -e

# ============================================
# Install packages
# ============================================
echo "[1/7] Installing packages..."
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
	ca-certificates \
	2>&1 | tail -10

echo "[OK] Packages installed"

echo "[2/7] Installing Filebeat..."
# Install Filebeat
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update -qq
apt-get install -y filebeat 2>&1 | tail -10

# Switch to iptables-legacy
echo "[3/7] Switching to iptables-legacy..."
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
echo "[OK] Using: \$(iptables --version)"

# Configure network interfaces
echo "[4/7] Configuring network interfaces..."
ip addr add "${EXT_FW_ETH1_IP}" dev eth1 2>/dev/null || true   # DMZ
ip addr add "${EXT_FW_ETH2_IP}" dev eth2 2>/dev/null || true   # Router Edge
ip addr add "${EXT_FW_ETH3_IP}" dev eth3 2>/dev/null || true   # Internal_FW link
ip addr add "${EXT_FW_ETH4_IP}" dev eth4 2>/dev/null || true               # to SIEM_FW
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "[OK] Network configured"

# Configure ulogd2 for NFLOG
echo "[5/7] Configuring ulogd2..."
mkdir -p /var/log/firewall /var/log/ulogd /etc/ulogd

cat > /etc/ulogd/ulogd.conf << 'ULOGD_CONFIG'
[global]
logfile="/var/log/ulogd/ulogd.log"
loglevel=5

plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_raw2packet_BASE.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IFINDEX.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IP2STR.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_PRINTPKT.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_LOGEMU.so"

stack=log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU

[log1]
group=0

[base1]
[ifi1]
[ip2str1]
[print1]

[emu1]
file="/var/log/firewall/firewall-events.log"
sync=1
ULOGD_CONFIG

# Stop any existing ulogd
pkill ulogd 2>/dev/null || true
sleep 1

# Start ulogd2
ulogd -d -c /etc/ulogd/ulogd.conf &
ULOGD_PID=\$!
sleep 2

# Verify ulogd is running
if pgrep -x ulogd >/dev/null; then
	echo "[OK] ulogd2 running (PID: \$(pgrep -x ulogd))"
else
	echo "[ERROR] ulogd2 failed to start!"
	if [ -f /var/log/ulogd/ulogd.log ]; then
		echo "ulogd log:"
		cat /var/log/ulogd/ulogd.log
	fi
	exit 1
fi

# Configure Filebeat
cat > /etc/filebeat/filebeat.yml << 'FILEBEAT_CONFIG'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/firewall/firewall-events.log
  fields:
    firewall: external
    log_type: firewall
  fields_under_root: true

output.logstash:
  hosts: ["10.0.3.10:5044"]

path.data: /var/lib/filebeat
logging.level: info
FILEBEAT_CONFIG

# Start Filebeat
nohup filebeat -e -c /etc/filebeat/filebeat.yml > /var/log/filebeat.log 2>&1 &
FILEBEAT_PID=\$!
sleep 2

# Configure iptables with NFLOG
echo "[6/7] Configuring iptables with NFLOG..."

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X 2>/dev/null || true

# Set policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ============================================
# INPUT Chain
# ============================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/sec -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s "${SUBNET_DMZ}" -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s "${SUBNET_BETWEEN_FW}" -j ACCEPT

iptables -A INPUT -m limit --limit 1000/min --limit-burst 2000 -j NFLOG \
	--nflog-prefix "[EXT-FW-INPUT-DROP] " --nflog-group 0
iptables -A INPUT -j DROP

# ============================================
# FORWARD Chain
# ============================================

# Invalid
iptables -N LOG_INVALID
iptables -A LOG_INVALID -m limit --limit 1000/min --limit-burst 2000 -j NFLOG \
	--nflog-prefix "[EXT-FW-INVALID] " --nflog-group 0
iptables -A LOG_INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j LOG_INVALID

# Established/Related
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED \
	-m limit --limit 500/min --limit-burst 1000 -j NFLOG \
	--nflog-prefix "[EXT-FW-ESTABLISHED] " --nflog-group 0
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ============================================
# Internet → Webserver (Port 8443) with DDoS Protection
# ============================================

# Per-IP rate limiting: max 20 new connections per minute
iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m conntrack --ctstate NEW \
	-m recent --name webserver_dos --set

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m conntrack --ctstate NEW \
	-m recent --name webserver_dos --update --seconds 60 --hitcount 20 \
	-j NFLOG --nflog-prefix "[EXT-FW-WEB-DOS-BLOCK] " --nflog-group 0

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m conntrack --ctstate NEW \
	-m recent --name webserver_dos --update --seconds 60 --hitcount 20 \
	-j DROP

# Global rate limit: 50 connections/sec per source
iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m conntrack --ctstate NEW \
	-m limit --limit 50/sec --limit-burst 100 \
	-j NFLOG --nflog-prefix "[EXT-FW-WEB-ACCEPT] " --nflog-group 0

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m conntrack --ctstate NEW \
	-m limit --limit 50/sec --limit-burst 100 \
	-j ACCEPT

# Anything over limit gets dropped
iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 \
	-m limit --limit 1000/min --limit-burst 2000 \
	-j NFLOG --nflog-prefix "[EXT-FW-WEB-RATELIMIT-DROP] " --nflog-group 0

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p tcp --dport 8443 -j DROP

# ============================================
# Internet → Webserver (ICMP) with rate limiting
# ============================================

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p icmp --icmp-type echo-request \
	-m limit --limit 10/sec --limit-burst 20 \
	-j NFLOG --nflog-prefix "[EXT-FW-WEB-ICMP-ACCEPT] " --nflog-group 0

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p icmp --icmp-type echo-request \
	-m limit --limit 10/sec --limit-burst 20 \
	-j ACCEPT

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p icmp --icmp-type echo-request \
	-m limit --limit 1000/min --limit-burst 2000 \
	-j NFLOG --nflog-prefix "[EXT-FW-WEB-ICMP-DROP] " --nflog-group 0

iptables -A FORWARD -i eth2 -o eth1 -d "${DMZ_WAF_ETH1_IP%/*}" -p icmp --icmp-type echo-request -j DROP

# ============================================
# SYN Flood Protection
# ============================================

iptables -A FORWARD -i eth2 -p tcp --syn \
	-m limit --limit 30/sec --limit-burst 60 -j ACCEPT

iptables -A FORWARD -i eth2 -p tcp --syn \
	-m limit --limit 1000/min --limit-burst 2000 \
	-j NFLOG --nflog-prefix "[EXT-FW-SYN-FLOOD-DROP] " --nflog-group 0

iptables -A FORWARD -i eth2 -p tcp --syn -j DROP

# ============================================
# Traffic Rules
# ============================================

# Block Interior network pings from internet
iptables -A FORWARD -i eth2 -o eth1 -d "${SUBNET_INTERNAL}" -p icmp \
	-m limit --limit 1000/min --limit-burst 2000 -j NFLOG \
	--nflog-prefix "[EXT-FW-INTERN-ICMP-DROP] " --nflog-group 0
iptables -A FORWARD -i eth2 -o eth1 -d "${SUBNET_INTERNAL}" -p icmp -j DROP

# DMZ → Internet
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW \
	-m limit --limit 10/min --limit-burst 20 -j NFLOG \
	--nflog-prefix "[EXT-FW-DMZ-TO-INET] " --nflog-group 0
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT

# Internal → Internet
iptables -A FORWARD -i eth4 -o eth2 -m conntrack --ctstate NEW \
	-m limit --limit 10/min --limit-burst 20 -j NFLOG \
	--nflog-prefix "[EXT-FW-INTERN-TO-INET] " --nflog-group 0
iptables -A FORWARD -i eth4 -o eth2 -m conntrack --ctstate NEW -j ACCEPT

# Internet → DMZ (other)
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW \
	-m limit --limit 1000/min --limit-burst 2000 -j NFLOG \
	--nflog-prefix "[EXT-FW-INET-TO-DMZ-DROP] " --nflog-group 0
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j DROP

# Internet → Internal
iptables -A FORWARD -i eth2 -o eth4 -m conntrack --ctstate NEW \
	-m limit --limit 1000/min --limit-burst 2000 -j NFLOG \
	--nflog-prefix "[EXT-FW-INET-TO-INTERN-DROP] " --nflog-group 0
iptables -A FORWARD -i eth2 -o eth4 -m conntrack --ctstate NEW -j DROP

# Catch-all
iptables -A FORWARD -m limit --limit 500/min --limit-burst 1000 -j NFLOG \
	--nflog-prefix "[EXT-FW-CATCHALL-DROP] " --nflog-group 0
iptables -A FORWARD -j DROP

# ============================================
# NAT
# ============================================

# ICMP DNAT
iptables -t nat -A PREROUTING -i eth2 -d "${EXT_FW_NAT_IP}" -p icmp --icmp-type echo-request -j DNAT --to-destination ${DMZ_WAF_ETH1_IP%/*}

# HTTPS DNAT
iptables -t nat -A PREROUTING -i eth2 -d "${EXT_FW_NAT_IP}" -p tcp --dport 8443 -j DNAT --to-destination ${DMZ_WAF_ETH1_IP%/*}:8443

# SNAT for responses
iptables -t nat -A POSTROUTING -o eth2 -s "${DMZ_WAF_ETH1_IP%/*}" -j SNAT --to-source ${EXT_FW_NAT_IP}
iptables -t nat -A POSTROUTING -o eth2 -s "${SUBNET_INTERNAL}" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth2 -s "${SUBNET_DMZ}" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth2 -s "${SUBNET_BETWEEN_FW}" -j MASQUERADE

echo "[OK] iptables rules and NAT configured"

# Routing
ip route replace "${SUBNET_EDGE_1}" via "${ROUTER_EDGE_ETH2_IP%/*}" dev eth2 2>/dev/null || true
ip route replace "${SUBNET_INTERNAL}" via "${INT_FW_ETH3_IP%/*}" dev eth4 2>/dev/null || true
ip route add "${SUBNET_BACKEND}" via "${SIEM_FW_ETH2_IP%/*}" dev eth3 2>/dev/null || true
ip route add "${SUBNET_INTERNET}" via "${ROUTER_EDGE_ETH2_IP%/*}" dev eth2 2>/dev/null || true

echo "[OK] Routing configured"
echo "=========================================="

EOF

log_ok "External Firewall configured"
