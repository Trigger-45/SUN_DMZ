#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/config/variables.sh"

log_section "SECTION 2: Docker Environment Preparation"

# =========================
# Step 1: Verify Docker Installation
# =========================
log_step "1/7" "Verifying Docker installation..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed!"
    log_error "Please install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! sudo docker ps &> /dev/null; then
    log_error "Docker daemon is not running or you don't have permissions!"
    log_error "Start Docker: sudo systemctl start docker"
    exit 1
fi

DOCKER_VERSION=$(sudo docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
log_ok "Docker is running (Version: ${DOCKER_VERSION})"

# =========================
# Step 2: Verify Containerlab Installation
# =========================
log_step "2/7" "Verifying Containerlab installation..."

if ! command -v containerlab &> /dev/null; then
    log_error "Containerlab is not installed!"
    log_error "Install with: bash ${SCRIPT_DIR}/install_dependencies.sh"
    exit 1
fi

CLAB_VERSION=$(containerlab version | grep "version:" | awk '{print $2}' 2>/dev/null || echo "unknown")
log_ok "Containerlab is installed (Version: ${CLAB_VERSION})"

# =========================
# Step 3: Pull Required Docker Images
# =========================
log_step "3/7" "Pulling required Docker images..."

IMAGES=(
    "${IMG_ALPINE}"
    "${IMG_UBUNTU}"
    "${IMG_DEBIAN}"
    "${IMG_FRR}"
    "${IMG_NGINX}"
    "${IMG_POSTGRES}"
    "${IMG_SURICATA}"
    "${IMG_KALI}"
    "${IMG_MODSECURITY}"
    "${IMG_ELASTICSEARCH}"
    "${IMG_LOGSTASH}"
    "${IMG_KIBANA}"
)

TOTAL_IMAGES=${#IMAGES[@]}
CURRENT=0

for IMAGE in "${IMAGES[@]}"; do
    CURRENT=$((CURRENT + 1))
    
    if sudo docker image inspect "${IMAGE}" &> /dev/null; then
        log_info "[${CURRENT}/${TOTAL_IMAGES}] ✓ ${IMAGE}"
    else
        log_info "[${CURRENT}/${TOTAL_IMAGES}] Pulling: ${IMAGE}"
        sudo docker pull "${IMAGE}" || log_warn "Failed to pull: ${IMAGE}"
    fi
done

log_ok "Docker images prepared"

# =========================
# Step 4: Create Required Directories
# =========================
log_step "4/7" "Creating required directories..."

REQUIRED_DIRS=(
    "${LOG_DIR}"
    "${TOPOLOGY_DIR}"
    "${CONFIG_DIR}/logstash/config"
    "${CONFIG_DIR}/logstash/pipeline"
    "${CONFIG_DIR}/suricata/rules"
    "${CONFIG_DIR}/suricata/logs-dmz"
    "${CONFIG_DIR}/suricata/logs-internal"
    "${CONFIG_DIR}/webserver-details"
    "${CONFIG_DIR}/db-init"
)

for DIR in "${REQUIRED_DIRS[@]}"; do
    mkdir -p "${DIR}" 2>/dev/null || true
done

sudo chmod -R 777 "${CONFIG_DIR}/logstash" 2>/dev/null || true
sudo chmod -R 777 "${CONFIG_DIR}/suricata/logs-dmz" 2>/dev/null || true
sudo chmod -R 777 "${CONFIG_DIR}/suricata/logs-internal" 2>/dev/null || true

log_ok "Required directories created"

# =========================
# Step 5: Ensure Configuration Files Exist
# =========================
log_step "5/7" "Ensuring base configuration files exist..."

REQUIRED_FILES=(
    "${CONFIG_DIR}/db-init/init-users.sql"
    "${CONFIG_DIR}/webserver-details/app.py"
    "${CONFIG_DIR}/suricata/suricata.yml"
    "${CONFIG_DIR}/suricata/rules/local.rules"
    "${CONFIG_DIR}/logstash/config/logstash.yml"
    "${CONFIG_DIR}/logstash/pipeline/firewall.conf"
    "${CONFIG_DIR}/logstash/pipeline/ids.conf"
)

for FILE in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${FILE}" ]; then
        log_error "Missing required file: ${FILE}"
        log_error "Please restore it in ${CONFIG_DIR}"
        exit 1
    fi
done

CERT_DIR="${CONFIG_DIR}/webserver-details"
if [ ! -f "${CERT_DIR}/server.crt" ] || [ ! -f "${CERT_DIR}/server.key" ]; then
    log_info "Generating self-signed SSL certificates..."
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "${CERT_DIR}/server.key" \
        -out "${CERT_DIR}/server.crt" \
        -subj "/CN=example.local"
    chmod 0777 "${CERT_DIR}/server.crt" "${CERT_DIR}/server.key"
fi

log_ok "Configuration files verified"

# =========================
# Step 5: Set System Parameters for Elasticsearch
# =========================
log_step "6/7" "Setting system parameters for Elasticsearch..."

CURRENT_VM_MAX=$(sysctl vm.max_map_count 2>/dev/null | awk '{print $3}' || echo "0")
REQUIRED_VM_MAX=262144

if [ "${CURRENT_VM_MAX}" -lt "${REQUIRED_VM_MAX}" ]; then
    log_info "Setting vm.max_map_count to ${REQUIRED_VM_MAX}"
    sudo sysctl -w vm.max_map_count=${REQUIRED_VM_MAX} &> /dev/null || true
    
    # Make persistent
    if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
        echo "vm.max_map_count=${REQUIRED_VM_MAX}" | sudo tee -a /etc/sysctl.conf > /dev/null || true
    fi
fi

log_ok "System parameters configured (vm.max_map_count: $(sysctl vm.max_map_count 2>/dev/null | awk '{print $3}'))"

# =========================
# Step 6: Summary
# =========================
log_step "7/7" "Preparation summary..."

echo ""
log_section "Preparation Summary"
echo ""
echo "✓ Docker Version:        ${DOCKER_VERSION}"
echo "✓ Containerlab Version:  ${CLAB_VERSION}"
echo "✓ Images Prepared:       ${TOTAL_IMAGES}"
echo "✓ vm.max_map_count:      $(sysctl vm.max_map_count 2>/dev/null | awk '{print $3}')"
echo ""

log_ok "Docker environment preparation completed"