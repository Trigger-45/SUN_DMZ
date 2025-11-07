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

# =========================
# Variables
# =========================
file_name="DMZ.yml"
filebeat_config="filebeat.yml"
Internal_Client1_ip="192.168.10.10/24"
Internal_Client2_ip="192.168.10.11/24"

# =========================
# Helper Function for Output
# =========================
log_info()    { echo -e "${BLUE}[ INFO ]${ENDCOLOR} $1"; }
log_ok()      { echo -e "${GREEN}[  OK  ]${ENDCOLOR} $1"; }
log_error()   { echo -e "${RED}[ERROR ]${ENDCOLOR} $1"; }

# =========================
# Begin Setup
# =========================
log_info "Creating topology file: ${file_name}"

if [ -e "$file_name" ]; then
  log_info "File '${file_name}' already exists — removing old version"
  rm -f "$file_name"
fi

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
    - endpoints: ["Database:eth1", "Webserver:eth2"]
    - endpoints: ["Proxy_WAF:eth2", "Webserver:eth1"]
    - endpoints: ["IDS:eth1", "DMZ_Switch:eth4"]
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
# Filebeat Config erstellen
# =========================
log_info "Creating filebeat configuration..."
cat << EOF > "$filebeat_config"
filebeat.inputs:
- type: filestream
  enabled: true
  paths:
    - /tmp/filebeat-simulated-logs/*.log
  scan_frequency: 5s
  harvester_limit: 0

# ILM ok with Elasticsearch 8.x (default)
# If you want to disable ILM uncomment the next line:
# setup.ilm.enabled: false

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]

path.data: /tmp/filebeat-data
EOF
log_ok "Filebeat configuration '${filebeat_config}' created"

# =========================
# Dummy Logs - robust (Permissions)
# =========================
log_info "Preparing /tmp/filebeat-simulated-logs on host (permissions)..."
sudo rm -rf /tmp/filebeat-simulated-logs || true
sudo mkdir -p /tmp/filebeat-simulated-logs
# permissive for lab: both container and host can write
sudo chmod 0777 /tmp/filebeat-simulated-logs
# create initial log file with permissive perms
sudo touch /tmp/filebeat-simulated-logs/test.log
sudo chmod 0666 /tmp/filebeat-simulated-logs/test.log
log_ok "Host log directory ready: /tmp/filebeat-simulated-logs"

log_info "Seeding initial dummy logs..."
for i in $(seq 1 20); do
  echo "$(date) - Dummy log entry number $i: This is some additional text to increase file size." | sudo tee -a /tmp/filebeat-simulated-logs/test.log >/dev/null
done
log_ok "Seeded initial dummy logs (>=1KB)"


# =========================
# Ensure host bind directory exists for Postgres
# =========================
log_info "Checking host directory for Postgres data volume..."
if [ ! -d "./dbdata" ]; then
    log_info "Directory './dbdata' does not exist — creating it..."
    mkdir -p ./dbdata
    chmod 0755 ./dbdata
    log_ok "Host directory './dbdata' created"
else
    log_ok "Host directory './dbdata' already exists — skipping creation"
fi


# =========================
# Deploy Containerlab
# =========================
log_info "Starting containerlab deployment..."
sudo containerlab deploy --reconfigure --topo "$file_name"
log_ok "Containerlab deployment completed successfully"

# =========================
# Wait for Elasticsearch to be ready
# =========================
log_info "Waiting for Elasticsearch to be ready (this can take a minute)..."
# Wait until cluster status is green (or at least reachable). Timeout not strict here.
until sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; do
  # in some environments initial status may be "yellow" for a moment; still continue if reachable
  sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health || true
  sleep 5
done
log_ok "Elasticsearch cluster reports green"

# =========================
# Ensure Filebeat can start cleanly
# =========================
log_info "Removing potential Filebeat lockfile inside the container..."
sudo docker exec -it clab-MaJuVi-filebeat rm -f /usr/share/filebeat/data/filebeat.lock || true
log_ok "Lockfile removed (if present)"

log_info "Starting Filebeat inside container..."
sudo docker exec -d clab-MaJuVi-filebeat filebeat -e -c /usr/share/filebeat/filebeat.yml
log_ok "Filebeat started"

# =========================
# Continuous Dummy Log Generation inside Filebeat container
# =========================
log_info "Starting continuous dummy log generation inside the Filebeat container..."
# run the generator inside the filebeat container so host/container UID conflicts don't matter
sudo docker exec -d clab-MaJuVi-filebeat sh -c 'while true; do echo "$(date) - simulated log and i like ananas" >> /tmp/filebeat-simulated-logs/test.log; sleep 5; done'
log_ok "Continuous generation started inside container"

# =========================
# Basic final checks
# =========================
log_info "Checking if filebeat can talk to Elasticsearch (test output)..."
sudo docker exec -it clab-MaJuVi-filebeat filebeat test output || true

log_info "Listing indices in Elasticsearch (should show filebeat-*)..."
sudo docker exec -it clab-MaJuVi-elasticsearch curl -s 'http://localhost:9200/_cat/indices?v' || true

log_ok "Elasticsearch + Kibana SIEM stack is ready. Access Kibana at http://localhost:5601 and create index pattern 'filebeat-*' (time field @timestamp)."


log_ok "Elasticsearch + Kibana SIEM stack is ready. Access Kibana at http://localhost:5601 and create index pattern 'filebeat-*' to view logs."


log_info "Configurating Internal Clients"
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
log_ok "Internal Clients configerd "

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



log_info "Configurating Internal Firewall"
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
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j DROP

# Sicherstellen, dass ICMP zur Firewall selbst durchkommt (INPUT)
iptables -A INPUT -p icmp -j ACCEPT

EOF

log_ok "Internal Firewall configured"


log_info "Konfiguriere DMZ Switch (br0) ..."
sudo docker exec -i clab-MaJuVi-DMZ_Switch sh <<'EOF'
set -e
apk add --no-cache iproute2 bridge-utils >/dev/null 2>&1 || true
# Erstelle Bridge und füge DMZ-Ports hinzu (eth1..eth5)
ip link add name br0 type bridge 2>/dev/null || true
ip link set eth1 master br0 2>/dev/null || true
ip link set eth2 master br0 2>/dev/null || true
ip link set eth3 master br0 2>/dev/null || true
ip link set eth4 master br0 2>/dev/null || true


# Bring interfaces up
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
EOF
log_ok "DMZ Switch konfiguriert"



#echo "Setze IP auf Webserver (10.0.2.10/24) und Default-Gateway 10.0.2.1 ..."
#sudo docker exec -i clab-MaJuVi-Webserver sh <<'EOF'
#set -e
#ip addr add 10.0.2.10/24 dev eth1 || true
#ip link set eth1 up
# Set default route via Internal_FW DMZ-Seite
#ip route replace default via 10.0.2.1 || true
# Falls nginx noch nicht läuft: ensure container's nginx is running (alpine nginx usually starts on CMD)
# ps aux | grep nginx
#EOF
#echo "Webserver IP gesetzt"



log_info "Configuring Database"
sudo docker exec -i clab-MaJuVi-Database sh <<'EOF'
set -e
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true
fi

# IP auf DMZ-Interface setzen
ip addr add 10.0.2.10/24 dev eth1 || true
ip link set eth1 up

# Default route via FW (DMZ-Seite)
ip route replace default via 10.0.2.1 || true
EOF
log_ok "Database configured"


log_info "Configuring Attacker"
sudo docker exec -i clab-MaJuVi-Attacker sh <<EOF
set -e
ip addr add 172.168.1.10/24 dev eth1 || true
ip link set eth1 up
ip route replace default via 172.168.1.1 || true
EOF
log_ok "Attacker configured"



log_ok "### Lab deployment and configuration completed"

