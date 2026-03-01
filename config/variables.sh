#!/bin/bash

# ==================================================
# Script Base Directory
# ==================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ==================================================
# Containerlab Configuration
# ==================================================
export LAB_NAME="MaJuVi"
export TOPO_FILE="DMZ.yml"

export MGMT_NETWORK="mgmt-net"
export MGMT_SUBNET="172.20.20.0/24"

# ==================================================
# Docker Images
# ==================================================
export IMG_ALPINE="alpine:latest"
export IMG_UBUNTU="ubuntu:latest"
export IMG_DEBIAN="debian:bookworm-slim"
export IMG_FRR="frrouting/frr:latest"
export IMG_NGINX="nginx:latest"
export IMG_POSTGRES="postgres:16"
export IMG_SURICATA="jasonish/suricata:latest"
export IMG_KALI="kalilinux/kali-rolling"
export IMG_MODSECURITY="owasp/modsecurity-crs:nginx"
export IMG_ELASTICSEARCH="docker.elastic.co/elasticsearch/elasticsearch:9.2.1"
export IMG_LOGSTASH="docker.elastic.co/logstash/logstash:9.2.1"
export IMG_KIBANA="docker.elastic.co/kibana/kibana:9.2.1"

# ==================================================
# Subnets (Documentation / Validation)
# ==================================================
export SUBNET_INTERNAL="192.168.10.0/24"
export SUBNET_BETWEEN_FW="192.168.20.0/24"
export SUBNET_DMZ="10.0.2.0/24"
export SUBNET_BACKEND="10.0.3.0/30"
export SUBNET_INTERNET="200.168.1.0/24"
export SUBNET_EDGE_1="172.168.2.0/30"
export SUBNET_EDGE_2="172.168.3.0/30"

# ==================================================
# Internal Network
# ==================================================
export INT_CLIENT1_ETH1_IP="192.168.10.10/24"
export INT_CLIENT2_ETH1_IP="192.168.10.11/24"

export INT_FW_ETH1_IP="192.168.10.1/24"
export INT_FW_ETH2_IP="10.0.2.1/24"
export INT_FW_ETH3_IP="192.168.20.1/24"
export INT_FW_ETH4_IP="10.0.3.2/30"

export INT_DEFAULT_GW="192.168.10.1"

# ==================================================
# External Firewall
# ==================================================
export EXT_FW_ETH1_IP="10.0.2.2/24"
export EXT_FW_ETH2_IP="172.168.3.2/30"
export EXT_FW_ETH3_IP="10.0.3.6/30"
export EXT_FW_ETH4_IP="192.168.20.2/24"

export EXT_FW_NAT_IP="172.168.3.5"

# ==================================================
# DMZ Systems
# ==================================================
# Proxy / WAF
export DMZ_WAF_ETH1_IP="10.0.2.30/24"
export DMZ_WAF_ETH2_IP="10.0.2.60/24"
export DMZ_WAF_ETH3_IP="10.0.3.34/30"

# Webserver
export DMZ_WEB_ETH1_IP="10.0.2.10/24"
export DMZ_WEB_ETH2_IP="10.0.2.50/24"

# Database
export DMZ_DB_ETH1_IP="10.0.2.70/24"

# ==================================================
# IDS
# ==================================================
# IDS (DMZ)
export IDS_DMZ_ETH2_IP="10.0.3.38/30"
export IDS_DMZ_GW="10.0.3.37"
export IDS_DMZ_ETH1_IP="10.0.2.20/24"

# IDS2 (Internal)
export IDS_INT_ETH2_IP="10.0.3.30/30"
export IDS_INT_GW="10.0.3.29"

# ==================================================
# SIEM Firewall
# ==================================================
export SIEM_FW_ETH1_IP="10.0.3.1/30"
export SIEM_FW_ETH2_IP="10.0.3.5/30"
export SIEM_FW_ETH3_IP="10.0.3.9/30"
export SIEM_FW_ETH4_IP="10.0.3.13/30"
export SIEM_FW_ETH5_IP="10.0.3.17/30"
export SIEM_FW_ETH6_IP="10.0.3.21/30"
export SIEM_FW_ETH7_IP="10.0.3.37/30"
export SIEM_FW_ETH8_IP="10.0.3.29/30"
export SIEM_FW_ETH9_IP="10.0.3.33/30"

# ==================================================
# SIEM Systems
# ==================================================
export SIEM_LOGSTASH_ETH1_IP="10.0.3.10/30"
export SIEM_LOGSTASH_ETH2_IP="10.0.3.25/30"

export SIEM_ELASTIC_ETH1_IP="10.0.3.26/30"
export SIEM_ELASTIC_ETH2_IP="10.0.3.29/30"
export SIEM_ELASTIC_ETH3_IP="10.0.3.14/30"
export SIEM_ELASTIC_GW="10.0.3.25"

export SIEM_KIBANA_ETH1_IP="10.0.3.30/30"
export SIEM_KIBANA_ETH2_IP="10.0.3.18/30"

export SIEM_PC_ETH1_IP="10.0.3.22/30"

# ==================================================
# Internet & Edge
# ==================================================
export INTERNET_ATTACKER_ETH1_IP="200.168.1.10/24"

export ROUTER_INTERNET_ETH1_IP="200.168.1.1/24"
export ROUTER_INTERNET_ETH2_IP="172.168.2.1/30"

export ROUTER_EDGE_ETH1_IP="172.168.2.2/30"
export ROUTER_EDGE_ETH2_IP="172.168.3.1/30"

# ==================================================
# Paths
# ==================================================
export CONFIG_DIR="${SCRIPT_DIR}/config"
export LOG_DIR="${SCRIPT_DIR}/logs"
export TOPOLOGY_DIR="${SCRIPT_DIR}/topology"

export FILEBEAT_CONFIG="${CONFIG_DIR}/filebeat.yml"
export LOGSTASH_CONFIG="${CONFIG_DIR}/logstash/pipeline.conf"

mkdir -p "${LOG_DIR}" "${TOPOLOGY_DIR}" "${CONFIG_DIR}" 2>/dev/null || true