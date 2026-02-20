#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/config/variables.sh"

log_section "SECTION 3: Deploying Containerlab Topology"

# Generate configuration files
log_info "Generating configuration files..."
bash "${SCRIPT_DIR}/topology/topology-generator.sh"

# Deploy containerlab
log_info "Deploying containerlab topology..."
cd "${SCRIPT_DIR}"

if [ -f "topology/${TOPO_FILE}" ]; then
    sudo containerlab deploy --reconfigure --topo "topology/${TOPO_FILE}"
elif [ -f "${TOPO_FILE}" ]; then
    sudo containerlab deploy --reconfigure --topo "${TOPO_FILE}"
else
    log_error "Topology file not found!"
    exit 1
fi

log_ok "Containerlab topology deployed successfully"

# Verify deployment
log_info "Verifying deployment..."
TOTAL_CONTAINERS=$(sudo docker ps -a --filter "name=clab-${LAB_NAME}" --format "{{.Names}}" | wc -l)
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=clab-${LAB_NAME}" --format "{{.Names}}" | wc -l)

echo ""
log_info "Total containers created: ${TOTAL_CONTAINERS}"
log_info "Running containers: ${RUNNING_CONTAINERS}"

if [ "$TOTAL_CONTAINERS" -eq "$RUNNING_CONTAINERS" ] && [ "$TOTAL_CONTAINERS" -gt 0 ]; then
    log_ok "All containers are running! ✓"
else
    log_warn "Some containers may not be running"
    log_info "Check with: sudo docker ps -a --filter 'name=clab-${LAB_NAME}'"
fi

echo ""
log_ok "Topology deployment completed!"
log_info "View topology: sudo containerlab inspect --topo topology/${TOPO_FILE}"