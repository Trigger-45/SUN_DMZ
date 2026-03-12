#!/bin/bash
set -euo pipefail

# Get base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up paths for different components
export SCRIPTS_DIR="${BASE_DIR}/scripts"
export CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

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
        bash "${SCRIPTS_DIR}/setup/01-cleanup.sh" --purge
    else
        bash "${SCRIPTS_DIR}/setup/01-cleanup.sh"
    fi
    exit 0
fi

# =========================
# Main Deployment Flow
# =========================
log_section "Starting SUN_DMZ Deployment"

if [ "$SKIP_CLEANUP" = false ]; then
    log_info "Running cleanup phase..."
    bash "${SCRIPTS_DIR}/setup/01-cleanup.sh"
else
    log_warn "Skipping cleanup phase"
fi

log_info "Preparing Docker environment..."
bash "${SCRIPTS_DIR}/setup/02-docker-prep.sh"

log_info "Generating SSL certificates for webserver..."
cd "${CONFIG_DIR}" && bash config.sh
cd "${BASE_DIR}"

log_info "Deploying topology..."
bash "${SCRIPTS_DIR}/setup/03-deploy-topology.sh"

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


    log_subsection "Waiting for Elasticsearch to be ready"
    log_info "Waiting for Elasticsearch to be ready (this may take a couple of minutes)..."
    until sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; do
    sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health || true
    sleep 2
    done

    echo ""
    log_ok "Elasticsearch cluster reports green"

    log_info "Configuring firewalls..."
    bash "${SCRIPTS_DIR}/configure/firewalls/internal-fw.sh"
    bash "${SCRIPTS_DIR}/configure/firewalls/external-fw.sh"
    bash "${SCRIPTS_DIR}/configure/firewalls/waf.sh"
    bash "${SCRIPTS_DIR}/configure/firewalls/siem-fw.sh"

    # log_info "Configuring IDS..."
    bash "${SCRIPTS_DIR}/configure/ids/ids-dmz.sh"
    bash "${SCRIPTS_DIR}/configure/ids/ids-internal.sh"

    log_info "Configuring clients..."
    bash "${SCRIPTS_DIR}/configure/clients/internal-clients.sh"
    # bash "${SCRIPTS_DIR}/configure/clients/attacker.sh"
    
    
    log_info "Configuring network components..."
    bash "${SCRIPTS_DIR}/configure/network/switches.sh"
    bash "${SCRIPTS_DIR}/configure/network/router-edge.sh"
    bash "${SCRIPTS_DIR}/configure/network/router-internet.sh"
    
    
    log_info "Configuring DMZ services..."
    bash "${SCRIPTS_DIR}/configure/dmz/database.sh"
    bash "${SCRIPTS_DIR}/configure/dmz/webserver.sh"
    bash "${SCRIPTS_DIR}/configure/dmz/proxy.sh"
    
    
    log_info "Configuring SIEM stack..."
    bash "${SCRIPTS_DIR}/configure/siem/logstash.sh"
    bash "${SCRIPTS_DIR}/configure/siem/elasticsearch.sh"
    bash "${SCRIPTS_DIR}/configure/siem/kibana.sh"
    bash "${SCRIPTS_DIR}/configure/siem/siem-pc.sh"


    
    log_section "Full Deployment Complete!"
fi

# =========================
# Final Summary
# =========================
echo ""
log_ok "Deployment finished successfully!"
log_info "View topology: sudo containerlab inspect --topo topology/${TOPO_FILE}"
log_info "Run tests: bash ${SCRIPTS_DIR}/tests/test-connectivity.sh"
log_info "Destroy lab: $0 --destroy"
log_info "Purge all (including images): $0 --purge"
echo ""