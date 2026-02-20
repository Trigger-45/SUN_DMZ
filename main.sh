#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/config/variables.sh"

# =========================
# Usage Information
# =========================
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

DEPLOYMENT OPTIONS:
    --topology-only     Deploy only the topology without configuration
    --full              Deploy topology and configure all components (default)
    --skip-cleanup      Skip the cleanup phase

CLEANUP OPTIONS:
    --destroy           Destroy the containerlab topology and stop all containers
    --purge             Destroy topology AND remove all Docker images used by the lab
    
GENERAL OPTIONS:
    --help, -h          Show this help message

EXAMPLES:
    $0                      # Full deployment with configuration
    $0 --topology-only      # Deploy bare topology only
    $0 --destroy            # Destroy topology and containers
    $0 --purge              # Destroy everything including Docker images

EOF
    exit 0
}

# =========================
# Parse Arguments
# =========================
TOPOLOGY_ONLY=false
SKIP_CLEANUP=false
FULL_DEPLOY=true
DESTROY_MODE=false
PURGE_MODE=false

if [ $# -eq 0 ]; then
    FULL_DEPLOY=true
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --topology-only) TOPOLOGY_ONLY=true; FULL_DEPLOY=false; shift ;;
        --full) FULL_DEPLOY=true; TOPOLOGY_ONLY=false; shift ;;
        --skip-cleanup) SKIP_CLEANUP=true; shift ;;
        --destroy) DESTROY_MODE=true; shift ;;
        --purge) PURGE_MODE=true; shift ;;
        --help|-h) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

# =========================
# Execute Destroy/Purge if requested
# =========================
if [ "$DESTROY_MODE" = true ] || [ "$PURGE_MODE" = true ]; then
    if [ "$PURGE_MODE" = true ]; then
        bash "${SCRIPT_DIR}/scripts/setup/01-cleanup.sh" --purge
    else
        bash "${SCRIPT_DIR}/scripts/setup/01-cleanup.sh"
    fi
    exit 0
fi

# =========================
# Main Deployment Flow
# =========================
log_section "Starting SUN_DMZ Deployment"

if [ "$SKIP_CLEANUP" = false ]; then
    log_info "Running cleanup phase..."
    bash "${SCRIPT_DIR}/scripts/setup/01-cleanup.sh"
else
    log_warn "Skipping cleanup phase"
fi

log_info "Preparing Docker environment..."
bash "${SCRIPT_DIR}/scripts/setup/02-docker-prep.sh"

log_info "Deploying topology..."
bash "${SCRIPT_DIR}/scripts/setup/03-deploy-topology.sh"

if [ "$TOPOLOGY_ONLY" = true ]; then
    log_section "Topology-Only Deployment Compl<ete!"
    log_info "Containers are running without configuration"
    log_info "To configure components, run: $0 --full"
    log_info "To destroy the lab, run: $0 --destroy"
    exit 0
fi

# =========================
# Configuration Phase (only if --full)
# =========================
if [ "$FULL_DEPLOY" = true ]; then
    log_section "Starting Configuration Phase"
    
    log_info "Configuring network components..."
    bash "${SCRIPT_DIR}/scripts/configure/network/switches.sh"
    bash "${SCRIPT_DIR}/scripts/configure/network/router-edge.sh"
    bash "${SCRIPT_DIR}/scripts/configure/network/router-internet.sh"
    
    log_info "Configuring firewalls..."
    bash "${SCRIPT_DIR}/scripts/configure/firewalls/internal-fw.sh"
    bash "${SCRIPT_DIR}/scripts/configure/firewalls/external-fw.sh"
    bash "${SCRIPT_DIR}/scripts/configure/firewalls/siem-fw.sh"
    
    log_info "Configuring DMZ services..."
    bash "${SCRIPT_DIR}/scripts/configure/dmz/database.sh"
    bash "${SCRIPT_DIR}/scripts/configure/dmz/webserver.sh"
    bash "${SCRIPT_DIR}/scripts/configure/dmz/proxy-waf.sh"
    
    log_info "Configuring IDS..."
    bash "${SCRIPT_DIR}/scripts/configure/ids/ids-dmz.sh"
    bash "${SCRIPT_DIR}/scripts/configure/ids/ids-internal.sh"
    
    log_info "Configuring SIEM stack..."
    bash "${SCRIPT_DIR}/scripts/configure/siem/elasticsearch.sh"
    bash "${SCRIPT_DIR}/scripts/configure/siem/logstash.sh"
    bash "${SCRIPT_DIR}/scripts/configure/siem/kibana.sh"
    bash "${SCRIPT_DIR}/scripts/configure/siem/siem-pc.sh"
    
    log_info "Configuring clients..."
    bash "${SCRIPT_DIR}/scripts/configure/clients/internal-clients.sh"
    bash "${SCRIPT_DIR}/scripts/configure/clients/attacker.sh"
    
    log_section "Full Deployment Complete!"
fi

# =========================
# Final Summary
# =========================
echo ""
log_ok "Deployment finished successfully!"
log_info "View topology: sudo containerlab inspect --topo topology/${TOPO_FILE}"
log_info "Run tests: bash ${SCRIPT_DIR}/scripts/tests/test-connectivity.sh"
log_info "Destroy lab: $0 --destroy"
log_info "Purge all (including images): $0 --purge"
echo ""