#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

Internal_Switch_CONTAINER="clab-${LAB_NAME}-Internal_Switch"
DMZ_Switch_CONTAINER="clab-${LAB_NAME}-DMZ_Switch"

log_info "Configuring Internal Switch"

sudo docker exec -i "${Internal_Switch_CONTAINER}" sh <<'EOF'
set -e
apk add --no-cache iproute2 bridge-utils >/dev/null 2>&1 || true
ip link add name br0 type bridge 2>/dev/null || true
ip link set eth1 master br0 2>/dev/null || true
ip link set eth2 master br0 2>/dev/null || true
ip link set eth3 master br0 2>/dev/null || true
# ip link set eth4 master br0 2>/dev/null || true
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
# ip link set eth4 up
tc qdisc add dev eth1 ingress
#tc filter add dev eth1 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4
tc qdisc add dev eth2 ingress
#tc filter add dev eth2 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4
tc qdisc add dev eth3 ingress
#tc filter add dev eth3 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4

EOF

log_info "Configuring DMZ Switch"

sudo docker exec -i "${DMZ_Switch_CONTAINER}" sh <<'EOF'
set -e
apk add --no-cache iproute2 bridge-utils >/dev/null 2>&1 || true
ip link add name br0 type bridge 2>/dev/null || true
ip link set eth1 master br0 2>/dev/null || true
ip link set eth2 master br0 2>/dev/null || true
ip link set eth3 master br0 2>/dev/null || true
#ip link set eth4 master br0 2>/dev/null || true
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
#ip link set eth4 up
tc qdisc add dev eth1 ingress
#tc filter add dev eth1 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4
tc qdisc add dev eth2 ingress
#tc filter add dev eth2 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4
tc qdisc add dev eth3 ingress
#tc filter add dev eth3 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth4
EOF