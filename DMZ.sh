#!/bin/bash
set -euo pipefail

# =========================
# Terminal Color Setup
# =========================
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

log_info()    { echo -e "${BLUE}[ INFO ]${ENDCOLOR} $1"; }
log_ok()      { echo -e "${GREEN}[  OK  ]${ENDCOLOR} $1"; }
log_error()   { echo -e "${RED}[ERROR ]${ENDCOLOR} $1"; }

# =========================
# Variables
# =========================
file_name="DMZ.yml"
filebeat_config="filebeat.yml"
Internal_Client1_ip="192.168.10.10/24"
Internal_Client2_ip="192.168.10.11/24"

# =========================
# Cleanup old environment
# =========================
log_info "Cleaning up previous containers and data..."

# Destroy containerlab setup if exists
sudo containerlab destroy --topo "$file_name" || true

# Remove Docker leftover containers, volumes, networks
sudo docker container prune -f || true
sudo docker network prune -f || true
sudo docker volume prune -f || true

# Remove previous data directories
sudo rm -rf /tmp/filebeat-simulated-logs /tmp/filebeat-data ./dbdata || true

log_ok "Previous environment cleaned"

# =========================
# Create topology file
# =========================
log_info "Creating topology file: ${file_name}"
cat << 'EOF' > "$file_name"
name: MaJuVi
mgmt:
  network: mgmt-net
  ipv4-subnet: 172.20.20.0/24
topology:
  nodes:
    # --- Interne Hosts ---
    Internal_Switch:
      kind: linux
      image: frrouting/frr:latest
      type: bridge
      group: switch
      cap-add:
        - NET_ADMIN
        - NET_RAW
    Internal_Client1:
      kind: linux
      image: alpine:latest
      type: host
      group: server
      cap-add:
        - NET_ADMIN
    Internal_Client2:
      kind: linux
      image: alpine:latest
      type: host
      group: server
      cap-add:
        - NET_ADMIN
    Internal_FW:
      kind: linux
      image: frrouting/frr:latest
      type: host
      group: firewall
      ports:
        - "8080:8080"
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW
    # --- DMZ Hosts ---
    DMZ_Switch:
      kind: linux
      image: frrouting/frr:latest
      type: bridge
      group: switch
      cap-add:
        - NET_ADMIN
        - NET_RAW
    Proxy_WAF:
      kind: linux
      image: nginx:latest
      group: proxy
      ports:
        - "80:80"
      cap-add:
        - NET_ADMIN
    Webserver:
      kind: linux
      image: nginx:alpine
      group: server
      cap-add:
        - NET_ADMIN
      env:
        LISTEN_PORT: "8080"
    Database:
      kind: linux
      image: postgres:16
      group: server
      env:
        POSTGRES_USER: admin_use
        POSTGRES_PASSWORD: strongpassword
        POSTGRES_DB: mydatabase
      binds:
        - ./dbdata:/var/lib/postgresql/data
      ports:
        - "5432:5432"
    IDS:
      kind: linux
      image: jasonish/suricata:latest
      group: IDS
      cmd: suricata -i eth1 -i eth2 --af-packet
      cap-add:
        - NET_ADMIN
        - NET_RAW
        - SYS_NICE
    IDS2:
      kind: linux
      image: jasonish/suricata:latest
      group: IDS
      cmd: suricata -i eth1 -i eth2 --af-packet
      cap-add:
        - NET_ADMIN
        - NET_RAW
        - SYS_NICE
    # --- Filebeat ---
    filebeat:
      kind: linux
      image: docker.elastic.co/beats/filebeat:9.2.0
      group: filebeat
      binds:
        - ./filebeat.yml:/usr/share/filebeat/filebeat.yml
        - /tmp/filebeat-simulated-logs:/tmp/filebeat-simulated-logs
      cmd: filebeat -e -c /usr/share/filebeat/filebeat.yml
      cap-add:
        - NET_ADMIN
    elasticsearch:
      kind: linux
      image: docker.elastic.co/elasticsearch/elasticsearch:8.10.1
      group: siem
      env:
        discovery.type: single-node
        ES_JAVA_OPTS: "-Xms1g -Xmx1g"
        xpack.security.enabled: "false"
      ports:
        - "9200:9200"
      cap-add:
        - NET_ADMIN
    kibana:
      kind: linux
      image: docker.elastic.co/kibana/kibana:8.10.1
      group: siem
      env:
        ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
        SERVER_NAME: "kibana"
      ports:
        - "5601:5601"
      cap-add:
        - NET_ADMIN
    External_FW:
      kind: linux
      image: frrouting/frr:latest
      type: host
      group: firewall
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW
    router-edge:
      kind: linux
      image: frrouting/frr:latest
      type: host
      group: router
      cap-add:
        - NET_ADMIN
        - NET_RAW
    router-internet:
      kind: linux
      image: frrouting/frr:latest
      type: host
      group: router
      cap-add:
        - NET_ADMIN
        - NET_RAW
    Attacker:
      kind: linux
      image: alpine:latest
      type: host
      group: server
      cap-add:
        - NET_ADMIN
  links:
    - endpoints: ["Internal_Client1:eth1", "Internal_Switch:eth1"]
    - endpoints: ["Internal_Client2:eth1", "Internal_Switch:eth2"]
    - endpoints: ["Internal_Switch:eth3", "Internal_FW:eth1"]
    - endpoints: ["Internal_FW:eth2", "DMZ_Switch:eth1"]
    - endpoints: ["DMZ_Switch:eth2", "External_FW:eth1"]
    - endpoints: ["Proxy_WAF:eth1", "DMZ_Switch:eth3"]
    - endpoints: ["Database:eth1", "DMZ_Switch:eth4"]
    - endpoints: ["Database:eth2", "Webserver:eth2"]
    - endpoints: ["Proxy_WAF:eth2", "Webserver:eth1"]
    - endpoints: ["IDS:eth1", "DMZ_Switch:eth5"]
    - endpoints: ["IDS:eth2", "filebeat:eth1"]
    - endpoints: ["filebeat:eth2", "elasticsearch:eth1"]
    - endpoints: ["elasticsearch:eth2", "kibana:eth1"]
    - endpoints: ["Attacker:eth1", "router-internet:eth1"]
    - endpoints: ["router-internet:eth2", "router-edge:eth1"]
    - endpoints: ["router-edge:eth2", "External_FW:eth2"]
    - endpoints: ["IDS2:eth1", "Internal_Switch:eth4"]
    - endpoints: ["IDS2:eth2", "filebeat:eth3"]
    - endpoints: ["filebeat:eth4", "Internal_FW:eth3"]
    - endpoints: ["filebeat:eth5", "External_FW:eth3"]
    - endpoints: ["filebeat:eth6", "Proxy_WAF:eth3"]
EOF
log_ok "Topology file '${file_name}' created successfully"

# =========================
# Filebeat configuration (aktualisiert: zwei inputs, eins für allgemeine logs, eins für firewall logs)
# =========================
log_info "Creating filebeat configuration..."
cat << EOF > "$filebeat_config"
filebeat.inputs:
- type: filestream
  id: "dummy-logs"
  enabled: true
  paths:
    - /tmp/filebeat-simulated-logs/*.log
  scan_frequency: 5s
  harvester_limit: 0

# Separates Input für Firewall-Logs mit einem zusätzlichen Feld
- type: filestream
  id: "firewall-logs"
  enabled: true
  paths:
    - /tmp/filebeat-simulated-logs/fw_*.log
  scan_frequency: 5s
  harvester_limit: 0
  fields:
    log_type: firewall
  fields_under_root: true

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]

path.data: /tmp/filebeat-data
EOF
log_ok "Filebeat configuration '${filebeat_config}' created"

# =========================
# Prepare database directories
# =========================
mkdir -p ./dbdata
sudo chmod 0777 ./dbdata

# =========================
# Prepare log directories
# =========================
log_info "Preparing /tmp/filebeat-simulated-logs..."
sudo mkdir -p /tmp/filebeat-simulated-logs
sudo chmod 0777 /tmp/filebeat-simulated-logs
sudo touch /tmp/filebeat-simulated-logs/test.log
sudo chmod 0666 /tmp/filebeat-simulated-logs/test.log
# firewall logs
sudo touch /tmp/filebeat-simulated-logs/fw_internal.log
sudo touch /tmp/filebeat-simulated-logs/fw_external.log
sudo chmod 0666 /tmp/filebeat-simulated-logs/fw_*.log
log_ok "Host log directory ready"

log_info "Seeding initial dummy logs..."
for i in $(seq 1 20); do
  echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - Dummy log entry number $i" | sudo tee -a /tmp/filebeat-simulated-logs/test.log >/dev/null
done
log_ok "Initial logs seeded"

# =========================
# Deploy containerlab
# =========================
log_info "Deploying containerlab..."
sudo containerlab deploy --reconfigure --topo "$file_name"
log_ok "Containerlab deployed"

# =========================
# Wait for Elasticsearch to be ready
# =========================
log_info "Waiting for Elasticsearch to be ready (this can take a minute)..."
until sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; do
  sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health || true
  sleep 5
done
log_ok "Elasticsearch cluster reports green"

# =========================
# Push Filebeat config into place and start Filebeat
# =========================
log_info "Copying filebeat.yml into working directory for containerlab..."
# ensure we have the file in current dir (containerlab topology references ./filebeat.yml)
# (already written above)

# Remove possible Filebeat lockfile if container already exists
if sudo docker ps -a --format '{{.Names}}' | grep -q 'clab-MaJuVi-filebeat'; then
  log_info "Removing possible Filebeat lockfile inside container..."
  sudo docker exec -it clab-MaJuVi-filebeat rm -f /usr/share/filebeat/data/filebeat.lock || true
fi

log_info "Restarting Filebeat to pick up new configuration..."
# If container exists, restart it; otherwise containerlab will have created and launched it
sudo docker restart clab-MaJuVi-filebeat || true
# ensure filebeat runs with explicit command (relaunch if necessary)
sudo docker exec -d clab-MaJuVi-filebeat sh -c 'filebeat -e -c /usr/share/filebeat/filebeat.yml' || true
log_ok "Filebeat (re)started"

# =========================
# Continuous dummy log generation inside Filebeat container
# =========================
log_info "Starting continuous dummy log generation..."
sudo docker exec -d clab-MaJuVi-filebeat sh -c 'while true; do echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - simulated log entry" >> /tmp/filebeat-simulated-logs/test.log; sleep 5; done'
log_ok "Continuous log generation started"

# =========================
# Firewall: ensure ip forwarding + iptables base rules (Internal_FW)
# =========================
log_info "Configuring Internal Firewall"
sudo docker exec -i clab-MaJuVi-Internal_FW sh <<'EOF'
ip addr add 192.168.10.1/24 dev eth1 || true
ip addr add 10.0.2.1/24 dev eth2 || true
ip link set eth1 up
ip link set eth2 up

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Grundregeln 
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow internal -> DMZ (beachtet: NEW nur in diese Richtung)
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j DROP

# Add a counted logging rule (doesn't log to file, but we will export counters)
iptables -N LOGGING || true
iptables -F LOGGING || true
iptables -A LOGGING -j RETURN

# make sure there are counters to read
iptables -I FORWARD 1 -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT || true
EOF
log_ok "Internal Firewall configured"

# =========================
# Firewall: External_FW
log_info "Configuring External Firewall"
sudo docker exec -i clab-MaJuVi-External_FW sh <<'EOF'
set -e 
apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
ip addr add 10.0.2.2/24 dev eth1 || true
ip addr add 172.168.3.2/30 dev eth2 || true
ip link set eth1 up || true
ip link set eth2 up || true

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward || true

iptables -F
iptables -P FORWARD ACCEPT || true
# ensure counters exist for monitoring
iptables -L -v -n --line-numbers || true

ip route replace 172.168.1.0/24 via 172.168.3.1 || true

EOF
log_ok "External Firewall configured"

# =========================
# Create background host-side tasks that poll iptables/stats from the firewall containers
# and write them into host /tmp/filebeat-simulated-logs/fw_*.log so that Filebeat picks them up.
# This approach is robust for a test lab: the host polls the container and stores the output on the host.
# =========================

log_info "Starting host-side firewall loggers (poll iptables counters and write to host logs)..."

# Internal FW logger (runs on host, polling the firewall container)
sudo bash -c 'nohup bash -c \
"while true; do
  echo \"$(date -u +\"%Y-%m-%d %H:%M:%S UTC\") - >>> INTERNAL_FW IPTABLES FORWARD (top 20 lines)\" >> /tmp/filebeat-simulated-logs/fw_internal.log
  sudo docker exec clab-MaJuVi-Internal_FW iptables -L FORWARD -v -n --line-numbers | sed -n \"1,40p\" >> /tmp/filebeat-simulated-logs/fw_internal.log 2>/dev/null || echo \"(unable to query iptables inside container)\" >> /tmp/filebeat-simulated-logs/fw_internal.log
  echo \"\" >> /tmp/filebeat-simulated-logs/fw_internal.log
  sleep 5
done" >/tmp/fw_internal_logger.out 2>&1 &'

# External FW logger (similar)
sudo bash -c 'nohup bash -c \
"while true; do
  echo \"$(date -u +\"%Y-%m-%d %H:%M:%S UTC\") - >>> EXTERNAL_FW IPTABLES FORWARD (top 20 lines)\" >> /tmp/filebeat-simulated-logs/fw_external.log
  sudo docker exec clab-MaJuVi-External_FW iptables -L FORWARD -v -n --line-numbers | sed -n \"1,40p\" >> /tmp/filebeat-simulated-logs/fw_external.log 2>/dev/null || echo \"(unable to query iptables inside container)\" >> /tmp/filebeat-simulated-logs/fw_external.log
  echo \"\" >> /tmp/filebeat-simulated-logs/fw_external.log
  sleep 5
done" >/tmp/fw_external_logger.out 2>&1 &'

log_ok "Firewall loggers started (host-side pollers writing into /tmp/filebeat-simulated-logs/)"

# =========================
# Internal Clients (no change)
# =========================
log_info "Configuring Internal Clients..."
sudo docker exec -i clab-MaJuVi-Internal_Client1 sh <<EOF
ip addr add ${Internal_Client1_ip} dev eth1
ip link set eth1 up
ip route replace default via 192.168.10.1
EOF
sudo docker exec -i clab-MaJuVi-Internal_Client2 sh <<EOF
ip addr add ${Internal_Client2_ip} dev eth1
ip link set eth1 up
ip route replace default via 192.168.10.1
EOF
log_ok "Internal Clients configured"

# =========================
# Internal Switch config
# =========================
log_info "Configurating Internal Switch"
sudo docker exec -i clab-MaJuVi-Internal_Switch sh <<'EOF'
set -e
apk add --no-cache iproute2 bridge-utils >/dev/null 2>&1 || true
ip link add name br0 type bridge 2>/dev/null || true
ip link set eth1 master br0 2>/dev/null || true
ip link set eth2 master br0 2>/dev/null || true
ip link set eth3 master br0 2>/dev/null || true
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
EOF

log_ok "Internal Switch configerd"

# =========================
# DMZ Switch config (same as before)
# =========================
log_info "Konfiguriere DMZ Switch (br0) ..."
sudo docker exec -i clab-MaJuVi-DMZ_Switch sh <<'EOF'
set -e
apk add --no-cache iproute2 bridge-utils >/dev/null 2>&1 || true
ip link add name br0 type bridge 2>/dev/null || true
ip link set eth1 master br0 2>/dev/null || true
ip link set eth2 master br0 2>/dev/null || true
ip link set eth3 master br0 2>/dev/null || true
ip link set eth4 master br0 2>/dev/null || true
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
EOF
log_ok "DMZ Switch konfiguriert"

# =========================
# Database config (same)
# =========================
log_info "Configuring Database"
sudo docker exec -i clab-MaJuVi-Database sh <<'EOF'
set -e
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
fi

ip addr add 10.0.2.10/24 dev eth1 || true
ip link set eth1 up
ip route replace default via 10.0.2.1 || true
EOF
log_ok "Database configured"

# =========================
# Attacker (same)
# =========================
log_info "Configuring Attacker"
sudo docker exec -i clab-MaJuVi-Attacker sh <<EOF
set -e
ip addr add 172.168.1.10/24 dev eth1 || true
ip link set eth1 up
ip route replace default via 172.168.1.1 || true
EOF
log_ok "Attacker configured"


log_info "Configuring router-internet"
sudo docker exec -i clab-MaJuVi-router-internet sh <<'EOF'
set -e
# sicherstellen, dass iproute2 vorhanden ist
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
fi

# Interfaces: eth1 <-> Attacker, eth2 <-> router-edge
ip addr add 172.168.1.1/24 dev eth1 || true
ip addr add 172.168.2.1/30 dev eth2 || true

ip link set eth1 up
ip link set eth2 up

# forwarding aktivieren
echo 1 > /proc/sys/net/ipv4/ip_forward || true

# Kleine Firewall-Grundregeln (erlaubt established/related)
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# Route: DMZ (10.0.2.0/24) via router-edge (172.168.2.2)
ip route replace 10.0.2.0/24 via 172.168.2.2 || true
EOF
log_ok "router-internet configured"

log_info "Configuring router-edge"
sudo docker exec -i clab-MaJuVi-router-edge sh <<'EOF'
set -e
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
fi

# Interfaces: eth1 <-> router-internet, eth2 <-> External_FW
ip addr add 172.168.2.2/30 dev eth1 || true
ip addr add 172.168.3.1/30 dev eth2 || true

ip link set eth1 up
ip link set eth2 up

# forwarding aktivieren
echo 1 > /proc/sys/net/ipv4/ip_forward || true

# Firewall-Grundregeln
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# Routen:
# - Netzwerk zum Attacker (172.168.1.0/24) via router-internet
ip route replace 172.168.1.0/24 via 172.168.2.1 || true
# - DMZ (10.0.2.0/24) via External_FW (172.168.3.2)
ip route replace 10.0.2.0/24 via 172.168.3.2 || true
EOF
log_ok "router-edge configured"

log_ok "### Lab deployment and configuration completed"
