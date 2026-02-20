#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# =========================
# Containerlab Configuration
# =========================
export LAB_NAME="MaJuVi"
export TOPO_FILE="DMZ.yml"
export MGMT_NETWORK="mgmt-net"
export MGMT_SUBNET="172.20.20.0/24"

# =========================
# Docker Images
# =========================
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

# =========================
# Network Configuration
# =========================
export INTERNAL_SUBNET="192.168.10.0/24"
export DMZ_SUBNET="10.0.2.0/24"
export SIEM_SUBNET="10.0.3.0/24"
export INTERNET_SUBNET="200.168.1.0/24"
export EDGE_SUBNET_1="172.168.2.0/30"
export EDGE_SUBNET_2="172.168.3.0/30"

# =========================
# IP Addresses - Internal
# =========================
export INTERNAL_CLIENT1_IP="192.168.10.10/24"
export INTERNAL_CLIENT2_IP="192.168.10.11/24"
export INTERNAL_FW_ETH1="192.168.10.1/24"

# =========================
# IP Addresses - DMZ
# =========================
export DATABASE_IP="10.0.2.10/24"
export WEBSERVER_IP="10.0.2.30/24"
export IDS_DMZ_IP="10.0.2.20/24"

# =========================
# IP Addresses - SIEM
# =========================
export ADMIN_PC_IP="10.0.3.22/30"
export ELASTICSEARCH_IP="10.0.3.26"
export LOGSTASH_IP="10.0.3.10"
export KIBANA_IP="10.0.3.30"

# =========================
# IP Addresses - Internet/Edge
# =========================
export ATTACKER_IP="200.168.1.10/24"
export ROUTER_INTERNET_ETH1="200.168.1.1/24"
export ROUTER_EDGE_ETH1="172.168.2.2/30"
export ROUTER_EDGE_ETH2="172.168.3.1/30"

# =========================
# Configuration Files
# =========================
export FILEBEAT_CONFIG="${SCRIPT_DIR}/config/filebeat.yml"
export LOGSTASH_CONFIG="${SCRIPT_DIR}/config/logstash/pipeline.conf"

# =========================
# Directories
# =========================
export LOG_DIR="${SCRIPT_DIR}/logs"
export TOPOLOGY_DIR="${SCRIPT_DIR}/topology"
export CONFIG_DIR="${SCRIPT_DIR}/config"

# Create required directories
mkdir -p "${LOG_DIR}" 2>/dev/null || true
mkdir -p "${TOPOLOGY_DIR}" 2>/dev/null || true