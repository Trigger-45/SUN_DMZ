#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/scripts/lib/docker.sh"
source "${SCRIPT_DIR}/config/variables.sh"

log_section "Starting SUN_DMZ Deployment"

# Setup Phase
bash "${SCRIPT_DIR}/scripts/setup/01-cleanup.sh"
bash "${SCRIPT_DIR}/scripts/setup/02-docker-prep.sh"
bash "${SCRIPT_DIR}/scripts/setup/03-deploy-topology.sh"

# Configuration Phase
bash "${SCRIPT_DIR}/scripts/configure/firewalls/internal-fw.sh"
bash "${SCRIPT_DIR}/scripts/configure/firewalls/external-fw.sh"
bash "${SCRIPT_DIR}/scripts/configure/firewalls/siem-fw.sh"

bash "${SCRIPT_DIR}/scripts/configure/clients/attacker.sh"
bash "${SCRIPT_DIR}/scripts/configure/clients/internal-clients.sh"

bash "${SCRIPT_DIR}/scripts/configure/dmz/database.sh"
bash "${SCRIPT_DIR}/scripts/configure/dmz/proxy-waf.sh"
bash "${SCRIPT_DIR}/scripts/configure/dmz/webserver.sh"

bash "${SCRIPT_DIR}/scripts/configure/ids/ids-dmz.sh"
bash "${SCRIPT_DIR}/scripts/configure/ids/ids-internal.sh"

bash "${SCRIPT_DIR}/scripts/configure/network/router-edge.sh"
bash "${SCRIPT_DIR}/scripts/configure/network/router-internet.sh"
bash "${SCRIPT_DIR}/scripts/configure/network/switches.sh"

bash "${SCRIPT_DIR}/scripts/configure/siem/siem-pc.sh"
bash "${SCRIPT_DIR}/scripts/configure/siem/kibana.sh"
bash "${SCRIPT_DIR}/scripts/configure/siem/logstash.sh"
bash "${SCRIPT_DIR}/scripts/configure/siem/elasticsearch.sh"
# ... etc

log_ok "Deployment Complete!"