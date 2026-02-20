#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/config/variables.sh"

# Check if purge mode is requested
PURGE_MODE=false
if [[ "${1:-}" == "--purge" ]]; then
    PURGE_MODE=true
    log_section "Purging ${LAB_NAME} Lab (Complete Removal)"
else
    log_section "SECTION 1: Environment Cleanup"
fi

log_step "1/8" "Stopping all running ${LAB_NAME} containers..."
RUNNING=$(sudo docker ps -q --filter "name=clab-${LAB_NAME}" 2>/dev/null || true)
if [ -n "$RUNNING" ]; then
    echo "$RUNNING" | xargs -r sudo docker stop || true
    log_ok "Containers stopped"
else
    log_info "No running containers found"
fi

log_step "2/8" "Destroying containerlab topology..."
sudo containerlab destroy --topo "topology/${TOPO_FILE}" --cleanup 2>/dev/null || true
sudo containerlab destroy --topo "${TOPO_FILE}" --cleanup 2>/dev/null || true
sudo containerlab destroy --all --cleanup 2>/dev/null || true
log_ok "Containerlab destroyed"

log_step "3/8" "Removing all ${LAB_NAME} containers..."
sudo docker ps -a --filter "name=clab-${LAB_NAME}" -q 2>/dev/null | xargs -r sudo docker rm -f || true
sudo docker container prune -f || true
log_ok "All containers removed"

log_step "4/8" "Removing containerlab networks..."
sudo docker network ls --filter "name=clab-${LAB_NAME}" -q 2>/dev/null | xargs -r sudo docker network rm 2>/dev/null || true
sudo docker network ls --filter "name=${MGMT_NETWORK}" -q 2>/dev/null | xargs -r sudo docker network rm 2>/dev/null || true
sudo docker network prune -f || true
log_ok "Networks removed"

log_step "5/8" "Removing all volumes..."
sudo docker volume ls --filter "name=clab-${LAB_NAME}" -q 2>/dev/null | xargs -r sudo docker volume rm 2>/dev/null || true
sudo docker volume prune -f || true
log_ok "Volumes removed"

log_step "6/8" "Removing data directories..."
sudo rm -rf "${SCRIPT_DIR}/config/suricata/logs" 2>/dev/null || true
sudo rm -rf "${SCRIPT_DIR}/config/suricata/logs-dmz" 2>/dev/null || true
sudo rm -rf "${SCRIPT_DIR}/config/suricata/logs-internal" 2>/dev/null || true
sudo rm -f "${SCRIPT_DIR}/topology/${TOPO_FILE}" 2>/dev/null || true
sudo rm -f "${SCRIPT_DIR}/${TOPO_FILE}" 2>/dev/null || true
log_ok "Data directories removed"

log_step "7/8" "Cleaning up bridge interfaces..."
BRIDGES=$(ip link show 2>/dev/null | grep "br-" | awk -F': ' '{print $2}' | grep -v "@" || true)
if [ -n "$BRIDGES" ]; then
    echo "$BRIDGES" | while read -r bridge; do
        sudo ip link set "$bridge" down 2>/dev/null || true
        sudo ip link delete "$bridge" 2>/dev/null || true
    done
    log_ok "Bridge interfaces cleaned"
else
    log_info "No bridge interfaces to clean"
fi

# =========================
# Purge Mode: Remove ALL lab images
# =========================
if [ "$PURGE_MODE" = true ]; then
    log_step "8/8" "Removing all Docker images used by the lab..."
    
    IMAGES=(
        "${IMG_ALPINE}" "${IMG_UBUNTU}" "${IMG_DEBIAN}" "${IMG_FRR}"
        "${IMG_NGINX}" "${IMG_POSTGRES}" "${IMG_SURICATA}" "${IMG_KALI}"
        "${IMG_MODSECURITY}" "${IMG_ELASTICSEARCH}" "${IMG_LOGSTASH}" "${IMG_KIBANA}"
    )
    
    REMOVED=0
    for IMAGE in "${IMAGES[@]}"; do
        if sudo docker image inspect "${IMAGE}" &> /dev/null; then
            log_info "Removing image: ${IMAGE}"
            sudo docker rmi "${IMAGE}" &> /dev/null && REMOVED=$((REMOVED + 1)) || log_warn "Could not remove: ${IMAGE}"
        fi
    done
    
    log_ok "Removed ${REMOVED}/${#IMAGES[@]} Docker images"
    
    # Clean logs
    rm -rf "${LOG_DIR}/"*.log 2>/dev/null || true
    
    log_section "Purge Complete!"
    echo ""
    log_info "Freed disk space:"
    sudo docker system df || true
    echo ""
else
    log_step "8/8" "Final cleanup..."
    sudo docker system prune -f || true
    log_ok "System pruned"
fi

# =========================
# Verification
# =========================
log_subsection "Verifying cleanup..."

REMAINING=$(sudo docker ps -a --filter "name=clab-${LAB_NAME}" -q 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    log_ok "All containers removed ✓"
else
    log_warn "$REMAINING containers still remaining"
fi

REMAINING_NET=$(sudo docker network ls --filter "name=clab-${LAB_NAME}" -q 2>/dev/null | wc -l)
if [ "$REMAINING_NET" -eq 0 ]; then
    log_ok "All networks removed ✓"
else
    log_warn "$REMAINING_NET networks still remaining"
fi

echo ""
if [ "$PURGE_MODE" = true ]; then
    log_ok "Complete purge finished (including Docker images)"
else
    log_ok "Environment cleanup completed (Docker images preserved)"
fi