#!/bin/bash
set -euo pipefail

# =========================
# Terminal Color Setup
# =========================
# =========================
# Terminal Color & Logging Setup
# =========================
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"
ENDCOLOR="\e[0m"

# Timestamp-Funktion
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Verbesserte Log-Funktionen
log_section() { 
    echo ""
    echo -e "${BOLD}${CYAN}========================================${ENDCOLOR}"
    echo -e "${BOLD}${CYAN}  $1${ENDCOLOR}"
    echo -e "${BOLD}${CYAN}========================================${ENDCOLOR}"
    echo ""
}

log_subsection() {
    echo -e "${MAGENTA}--- $1 ---${ENDCOLOR}"
}

log_info() { 
    echo -e "${BLUE}[$(get_timestamp)]${ENDCOLOR} ${BLUE}[ INFO ]${ENDCOLOR} $1"
}

log_ok() { 
    echo -e "${GREEN}[$(get_timestamp)]${ENDCOLOR} ${GREEN}[  OK  ]${ENDCOLOR} $1"
}

log_error() { 
    echo -e "${RED}[$(get_timestamp)]${ENDCOLOR} ${RED}[ ERROR ]${ENDCOLOR} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(get_timestamp)]${ENDCOLOR} ${YELLOW}[ WARN ]${ENDCOLOR} $1"
}

log_step() {
    echo -e "${CYAN}[$(get_timestamp)]${ENDCOLOR} ${CYAN}[STEP $1]${ENDCOLOR} $2"
}

# =========================
# Variables
# =========================
file_name="DMZ.yml"
filebeat_config="filebeat.yml"
Internal_Client1_ip="192.168.10.10/24"
Internal_Client2_ip="192.168.10.11/24"
Admin_PC_ip="10.0.3.100/24"
SIEM_subnet="10.0.3.0/24"


# =========================
# SECTION 1: Environment Cleanup
# =========================

log_section "SECTION 1: Environment Cleanup"

log_step "1/3" "Destroying previous containerlab setup..."
sudo containerlab destroy --topo "$file_name" || true
log_ok "Containerlab destroyed"

log_step "2/3" "Removing Docker leftovers..."
sudo docker container prune -f || true
sudo docker network prune -f || true
sudo docker volume prune -f || true
log_ok "Docker resources cleaned"

log_step "3/3" "Removing data directories..."
sudo rm -rf ./db-init ./webserver-details ./logstash || true
log_ok "Data directories removed"

echo ""
log_ok "Environment cleanup completed"


# =========================
# SECTION 2: Create required files and configurations
# =========================
log_section "SECTION 2: Create required files and configurations"

# Create directory structure
mkdir -p ./logstash/config
mkdir -p ./logstash/pipeline
sudo chmod -R 0777 ./logstash
mkdir -p ./webserver-details
mkdir -p ./db-init

log_step "1/3" "Creating Database initialization SQL..."


log_info "Creating init-users.sql for PostgreSQL..."
cat << 'EOF' > ./db-init/init-users.sql
CREATE TABLE IF NOT EXISTS users (
    username VARCHAR(50) PRIMARY KEY,
    password VARCHAR(255) NOT NULL
);

INSERT INTO users (username, password) VALUES
('admin', 'password123'),
('user', 'mypassword')
ON CONFLICT (username) DO NOTHING;

-- Table for storing reports
CREATE TABLE IF NOT EXISTS reports (
    report_id SERIAL PRIMARY KEY,
    title VARCHAR(100) UNIQUE NOT NULL,
    details TEXT NOT NULL
);

-- Mapping users to reports they can access
CREATE TABLE IF NOT EXISTS user_report_access (
    username VARCHAR(50) NOT NULL,
    report_id INT NOT NULL,
    PRIMARY KEY (username, report_id),
    FOREIGN KEY (username) REFERENCES users(username),
    FOREIGN KEY (report_id) REFERENCES reports(report_id)
);

-- Insert sample reports
INSERT INTO reports (title, details) VALUES
('Monthly Sales Summary', 'Sales increased by 8% last month in total revenue.'),
('Confidential Strategy Document', 'Expansion plan includes entering three new markets in Q3.')
ON CONFLICT (title) DO NOTHING;

-- Map normal user to access only "Monthly Sales Summary" report
-- Map admin to access both reports

INSERT INTO user_report_access (username, report_id) VALUES
('user', 1),
('admin', 1),
('admin', 2)
ON CONFLICT DO NOTHING;
EOF

log_ok "Database initialization SQL created."

# =========================
# Create Webserver
# =========================
log_step "2/3" "Creating Webserver Flask app and Dockerfile..."

log_info "Creating start.sh script..."
cat << 'EOF' > ./webserver-details/start.sh
#!/bin/sh
# Starte Flask App im Hintergrund
python3 /app/app.py &

# Starte Nginx im Vordergrund
nginx -g "daemon off;"
EOF

log_info "Creating Nginx configuration..."
cat << 'EOF' > ./webserver-details/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    upstream flaskapp {
        server 127.0.0.1:8080;  # Flask läuft lokal im Container auf 8080
    }

    server {
        listen 80;

        location / {
            proxy_pass http://flaskapp;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
log_ok "Nginx configuration created."

log_info "Creating Flask app..."
cat << 'EOF' > ./webserver-details/app.py
from flask import Flask, request, render_template_string, redirect, url_for, session
import psycopg2
import os

app = Flask(__name__)
app.secret_key = "your-secret-key"  # needed for session management

# DB connection details - use environment variables or defaults
DB_HOST = os.getenv('DB_HOST', 'Database')
DB_NAME = os.getenv('DB_NAME', 'mydatabase')
DB_USER = os.getenv('DB_USER', 'admin_use')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'strongpassword')
DB_PORT = 5432

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

def check_user(username, password):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT password FROM users WHERE username = %s', (username,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        if row and row[0] == password:
            return True
    except Exception as e:
        print(f"DB error: {e}")
    return False

def get_user_reports(username):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT r.title, r.details
            FROM reports r
            INNER JOIN user_report_access ufa ON r.report_id = ufa.report_id
            WHERE ufa.username = %s
            ORDER BY r.title
        """, (username,))
        reports = cur.fetchall()
        cur.close()
        conn.close()
        return reports
    except Exception as e:
        print(f"DB error: {e}")
        return []

login_form = '''
<!doctype html>
<html lang="en">
<head>
  <title>Login</title>
  <style>
    body, html {
      height: 100%;
      margin: 0;
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      background: #f0f2f5;
    }
    .login-container {
      background: white;
      padding: 20px 30px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      width: 300px;
      text-align: center;
    }
    input[type="text"], input[type="password"] {
      width: 90%;
      padding: 8px;
      margin: 10px 0 20px 0;
      border: 1px solid #ccc;
      border-radius: 4px;
    }
    input[type="submit"] {
      background-color: #007bff;
      border: none;
      color: white;
      padding: 10px 20px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 16px;
    }
    input[type="submit"]:hover {
      background-color: #0056b3;
    }
    p.error {
      color: red;
      margin: -15px 0 15px 0;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <h2>Login</h2>
    {% if error %}
      <p class="error">{{ error }}</p>
    {% endif %}
    <form action="{{ url_for('login') }}" method="post">
      <input type="text" name="username" placeholder="Username" required><br/>
      <input type="password" name="password" placeholder="Password" required><br/>
      <input type="submit" value="Log In">
    </form>
  </div>
</body>
</html>
'''

reports_page = '''
<!doctype html>
<html lang="en">
<head>
  <title>Your Reports</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #fafafa;
      margin: 20px;
    }
    h2 {
      color: #333;
    }
    .report {
      background: white;
      padding: 15px;
      margin-bottom: 15px;
      border-radius: 6px;
      box-shadow: 0 1px 5px rgba(0,0,0,0.1);
    }
    .report h3 {
      margin-top: 0;
      color: #007bff;
    }
    .logout {
      margin-top: 20px;
      display: inline-block;
      color: #007bff;
      text-decoration: none;
      font-weight: bold;
    }
    .logout:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h2>Reports Accessible for {{ username }}:</h2>
  {% for title, details in reports %}
    <div class="report">
      <h3>{{ title }}</h3>
      <p>{{ details }}</p>
    </div>
  {% else %}
    <p>No reports available.</p>
  {% endfor %}
  <a href="{{ url_for('logout') }}" class="logout">Logout</a>
</body>
</html>
'''

@app.route('/', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if check_user(username, password):
            session['username'] = username
            return redirect(url_for('reports'))
        else:
            error = 'Invalid username or password'
    return render_template_string(login_form, error=error)

@app.route('/reports')
def reports():
    username = session.get('username')
    if not username:
        return redirect(url_for('login'))
    reports = get_user_reports(username)
    return render_template_string(reports_page, username=username, reports=reports)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF

log_ok "Flask app created."

log_info "Creating Dockerfile for Webserver with WAF..."
cat << 'EOF' > ./webserver-details/Dockerfile
FROM owasp/modsecurity-crs:nginx-alpine

USER root

WORKDIR /app

RUN apk add --no-cache python3 py3-flask py3-psycopg2 postgresql-dev libc-dev gcc

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /app/start.sh
COPY app.py /app/app.py

RUN chmod +x /app/start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
EOF
log_ok "Dockerfile created."


log_step "3/3" "Creating Logstash configuration..."
# Main Logstash configuration
log_info "Creating Logstash main configuration..."
cat << 'EOF' > ./logstash/config/logstash.yml
path.config: /usr/share/logstash/pipeline/*.conf
log.level: info
EOF

log_info "Creating Logstash pipeline for firewall logs..."
cat << 'EOF' > ./logstash/pipeline/firewall.conf
input {
  beats {
    port => 5044
    host => "0.0.0.0"
  }
}

filter {
  if [log_type] == "firewall" {
    grok {
      match => { 
        "message" => ".*\[%{DATA:prefix}\].*SRC=%{IP:src_ip} DST=%{IP:dst_ip}.*PROTO=%{WORD:protocol}.*SPT=%{INT:src_port}.*DPT=%{INT:dst_port}.*"
      }
    }
    
    mutate {
      add_field => { "[@metadata][index]" => "firewall-%{firewall}-%{+YYYY.MM.dd}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://10.0.3.26:9200"]
    index => "%{[@metadata][index]}"
  }
  
  stdout {
    codec => rubydebug
  }
}
EOF
log_ok "Logstash configuration created."

echo ""
log_ok "Creation of required Files completed."


log_subsection "SECTION 3: Building Webserver Docker Image"

log_info "Building Webserver-waf-proxy Docker image...(this may take a minute)"
sudo docker build -t webserver-waf-proxy ./webserver-details
log_ok "Webserver-waf-proxy Docker image built."


log_section "SECTION 4: Deploy Containerlab Topology and Configure Nodes"
# =========================
# Create topology file
# (unchanged, benutze deine bestehende Topologie)
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
    Admin_PC:
      kind: linux
      image: alpine:latest
      type: host
      group: server
      cap-add:
        - NET_ADMIN
    Internal_FW:
      kind: linux
      image: ubuntu:latest
      type: host
      group: firewall
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
    Web_Proxy_WAF:
      kind: linux
      image: webserver-waf-proxy
      group: server
      ports:
        - "8181:8080"
      cap-add:
        - NET_ADMIN
    Database:
      kind: linux
      image: postgres:16
      group: server
      env:
        POSTGRES_USER: admin_use
        POSTGRES_PASSWORD: strongpassword
        POSTGRES_DB: mydatabase
      binds:
        - ./db-init:/docker-entrypoint-initdb.d:ro
      ports:
        - "3636:5432"   
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
    SIEM_FW:
      kind: linux
      image: ubuntu:latest
      type: host
      group: firewall
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW
    logstash:
      kind: linux
      image: elastic/logstash:9.1.7
      group: siem
      binds:
        - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:rw
        - ./logstash/pipeline:/usr/share/logstash/pipeline:rw
      env:
        XPACK_MONITORING_ENABLED: "false"
        LS_JAVA_OPTS: "-Xmx512m -Xms512m"
      cap-add:
        - NET_ADMIN
    elasticsearch:
      kind: linux
      image: elasticsearch:9.2.1
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
      image: kibana:9.2.1
      group: siem
      env:
        ELASTICSEARCH_HOSTS: "http://10.0.3.26:9200"
        SERVER_NAME: "kibana"
      ports:
        - "5601:5601"
      cap-add:
        - NET_ADMIN
    External_FW:
      kind: linux
      image: debian:bookworm
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
    - endpoints: ["Internal_FW:eth3", "External_FW:eth4"]
    - endpoints: ["DMZ_Switch:eth2", "External_FW:eth1"]
    - endpoints: ["Web_Proxy_WAF:eth1", "DMZ_Switch:eth3"]
    - endpoints: ["Database:eth1", "Web_Proxy_WAF:eth2"]
    - endpoints: ["IDS:eth1", "DMZ_Switch:eth4"]
    - endpoints: ["SIEM_FW:eth1", "Internal_FW:eth4"]
    - endpoints: ["SIEM_FW:eth2", "External_FW:eth3"]
    - endpoints: ["SIEM_FW:eth3", "logstash:eth1"]
    - endpoints: ["logstash:eth2", "elasticsearch:eth1"]
    - endpoints: ["elasticsearch:eth2", "kibana:eth1"]
    - endpoints: ["Attacker:eth1", "router-internet:eth1"]
    - endpoints: ["router-internet:eth2", "router-edge:eth1"]
    - endpoints: ["router-edge:eth2", "External_FW:eth2"]
    - endpoints: ["IDS2:eth1", "Internal_Switch:eth4"]
    - endpoints: ["SIEM_FW:eth4", "elasticsearch:eth3"]
    - endpoints: ["SIEM_FW:eth5", "kibana:eth2"]
    - endpoints: ["Admin_PC:eth1", "SIEM_FW:eth6"]
EOF

log_ok "Topology file '${file_name}' created successfully"


# =========================
# Deploy containerlab
# =========================
log_info "Deploying containerlab..."
sudo containerlab deploy --reconfigure --topo "$file_name"
log_ok "Containerlab deployed"

echo ""
log_ok "Containerlab topology deployed successfully"

# =========================
# Wait for Elasticsearch to be ready
# =========================
log_subsection "SECTION 5: Wait for Elasticsearch to be ready"
log_info "Waiting for Elasticsearch to be ready (this may take a couple of minutes)..."
until sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; do
  sudo docker exec clab-MaJuVi-elasticsearch curl -s http://localhost:9200/_cluster/health || true
  sleep 2
done

echo ""
log_ok "Elasticsearch cluster reports green"




log_section "SECTION 6: Configure Internal and External Firewall"
log_step "1/2" "Configuring Internal Firewall..."
log_info "Configuring Internal Firewall"
sudo docker exec -i clab-MaJuVi-Internal_FW bash <<'EOF'
set -e

# ============================================
# Install packages
# ============================================
echo "[1/7] Installing packages..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends \
    iptables \
    iproute2 \
    iputils-ping \
    net-tools \
    ulogd2 \
    ulogd2-json \
    wget \
    curl \
    bash \
    procps \
    gnupg \
    ca-certificates \
    2>&1 | tail -10

echo "[OK] Packages installed"

echo "[2/7] Installing Filebeat..."
# Install Filebeat
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update -qq
apt-get install -y filebeat 2>&1 | tail -10



# ============================================
# Switch to iptables-legacy
# ============================================
echo "[3/7] Switching to iptables-legacy..."
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
echo "[OK] Using: $(iptables --version)"

# ============================================
# Configure network interfaces
# ============================================
echo "[4/7] Configuring network interfaces..."
ip addr add 192.168.10.1/24 dev eth1 2>/dev/null || true   # Internal
ip addr add 10.0.2.1/24 dev eth2 2>/dev/null || true       # DMZ
ip addr add 192.168.20.1/24 dev eth3 2>/dev/null || true   # To External_FW
ip addr add 10.0.3.2/30 dev eth4 || true     # zu SIEM_FW (.2 in .0-.3)
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "[OK] Network configured"

# ============================================
# Configure ulogd2 for NFLOG
# ============================================
echo "[5/7] Configuring ulogd2..."
mkdir -p /var/log/firewall /var/log/ulogd /etc/ulogd

cat > /etc/ulogd/ulogd.conf << 'ULOGD_CONFIG'
[global]
logfile="/var/log/ulogd/ulogd.log"
loglevel=5

plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_raw2packet_BASE.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IFINDEX.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IP2STR.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_PRINTPKT.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_LOGEMU.so"

stack=log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU

[log1]
group=0

[base1]
[ifi1]
[ip2str1]
[print1]

[emu1]
file="/var/log/firewall/firewall-events.log"
sync=1
ULOGD_CONFIG

# Stop any existing ulogd
pkill ulogd 2>/dev/null || true
sleep 1

# Start ulogd2
ulogd -d -c /etc/ulogd/ulogd.conf &
ULOGD_PID=$!
sleep 2

# Verify ulogd is running
if pgrep -x ulogd >/dev/null; then
    echo "[OK] ulogd2 running (PID: $(pgrep -x ulogd))"
else
    echo "[ERROR] ulogd2 failed to start!"
    if [ -f /var/log/ulogd/ulogd.log ]; then
        echo "ulogd log:"
        cat /var/log/ulogd/ulogd.log
    fi
    exit 1
fi

# Configure Filebeat
cat > /etc/filebeat/filebeat.yml << 'FILEBEAT_CONFIG'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/firewall/firewall-events.log
  fields:
    firewall: internal
    log_type: firewall
  fields_under_root: true

output.logstash:
  hosts: ["10.0.3.10:5044"]

path.data: /var/lib/filebeat
logging.level: info
FILEBEAT_CONFIG

# Start Filebeat
nohup filebeat -e -c /etc/filebeat/filebeat.yml > /var/log/filebeat.log 2>&1 &
FILEBEAT_PID=$!
sleep 2


# ============================================
# Configure iptables with NFLOG
# ============================================
echo "[6/7] Configuring iptables with NFLOG..."

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X 2>/dev/null || true

# Set policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ============================================
# INPUT Chain
# ============================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/sec -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 192.168.10.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.2.0/24 -j ACCEPT

# Log INPUT drops
iptables -A INPUT -m limit --limit 5/min -j NFLOG \
  --nflog-prefix "[INT-FW-INPUT-DROP] " \
  --nflog-group 0

# ============================================
# FORWARD Chain
# ============================================

# Invalid packets
iptables -N LOG_INVALID
iptables -A LOG_INVALID -m limit --limit 10/min --limit-burst 20 -j NFLOG \
  --nflog-prefix "[INT-FW-INVALID-DROP] " \
  --nflog-group 0
iptables -A LOG_INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j LOG_INVALID

# Established/Related
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Internal → DMZ
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[INT-FW-INTERN-TO-DMZ] " \
  --nflog-group 0
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT

# DMZ → Internal (blocked)
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[INT-FW-DMZ-TO-INTERN-DROP] " \
  --nflog-group 0
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j DROP

# Internal → Internet
iptables -A FORWARD -i eth1 -o eth3 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[INT-FW-INTERN-TO-INET] " \
  --nflog-group 0
iptables -A FORWARD -i eth1 -o eth3 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth3 -o eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Catch-all
iptables -A FORWARD -m limit --limit 5/min -j NFLOG \
  --nflog-prefix "[INT-FW-FORWARD-DROP] " \
  --nflog-group 0

# ============================================
# Routing
# ============================================
ip route replace 172.168.2.0/30 via 192.168.20.2 dev eth3 2>/dev/null || true
ip route replace 172.168.3.0/30 via 192.168.20.2 dev eth3 2>/dev/null || true
ip route add 10.0.3.0/24 via 10.0.3.1 dev eth4 || true

echo "[OK] iptables rules configured"

# ============================================
# Create helper scripts
# ============================================
echo "[7/7] Creating helper scripts..."

cat > /usr/local/bin/fw-stats << 'STATS_SCRIPT'
#!/bin/bash
echo "=========================================="
echo "Internal Firewall Statistics"
echo "=========================================="
echo ""
echo "Logging Method: NFLOG + ulogd2"
echo "iptables: $(iptables --version)"
echo ""

# ulogd status
if pgrep -x ulogd >/dev/null; then
    echo "ulogd2 Status:   RUNNING (PID: $(pgrep -x ulogd))"
else
    echo "ulogd2 Status:   NOT RUNNING"
fi
echo ""

echo "--- Last 20 Firewall Events ---"
if [ -f /var/log/firewall/firewall-events.log ] && [ -s /var/log/firewall/firewall-events.log ]; then
    tail -20 /var/log/firewall/firewall-events.log
else
    LOG_SIZE=$(stat -c%s /var/log/firewall/firewall-events.log 2>/dev/null || echo "0")
    echo "No events logged yet"
    echo "Log file size: $LOG_SIZE bytes"
    echo ""
    if [ "$LOG_SIZE" == "0" ] && ! pgrep -x ulogd >/dev/null; then
        echo "   WARNING: ulogd2 is not running!"
        echo "   Restart it with: ulogd -d -c /etc/ulogd/ulogd.conf &"
    fi
fi

echo ""
echo "--- Event Summary ---"
if [ -f /var/log/firewall/firewall-events.log ]; then
    TOTAL=$(wc -l < /var/log/firewall/firewall-events.log)
    echo "Total events: $TOTAL"
    
    if [ $TOTAL -gt 0 ]; then
        echo ""
        echo "Events by type:"
        grep -o 'INT-FW-[A-Z-]*' /var/log/firewall/firewall-events.log 2>/dev/null | sort | uniq -c | sort -rn || true
    fi
fi

echo ""
echo "--- iptables Rule Counters ---"
iptables -L -v -n | grep -E "Chain|NFLOG|pkts" | head -30

echo ""
echo "=========================================="
STATS_SCRIPT

cat > /usr/local/bin/fw-logs-live << 'LIVE_SCRIPT'
#!/bin/bash
echo "=== Live Internal Firewall Logs (NFLOG) ==="
echo "Press CTRL+C to stop"
echo ""

if [ -f /var/log/firewall/firewall-events.log ]; then
    tail -f /var/log/firewall/firewall-events.log
else
    echo "ERROR: Log file not found"
    exit 1
fi
LIVE_SCRIPT

cat > /usr/local/bin/fw-search << 'SEARCH_SCRIPT'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: fw-search <search_term>"
    echo "Example: fw-search '192.168.10.10'"
    echo "Example: fw-search 'DMZ-TO-INTERN'"
    exit 1
fi

echo "Searching for: $1"
echo ""

if [ -f /var/log/firewall/firewall-events.log ]; then
    grep -i "$1" /var/log/firewall/firewall-events.log || echo "No matches found"
else
    echo "ERROR: Log file not found"
    exit 1
fi
SEARCH_SCRIPT

chmod +x /usr/local/bin/fw-stats
chmod +x /usr/local/bin/fw-logs-live
chmod +x /usr/local/bin/fw-search

echo "[OK] Helper scripts created"

# ============================================
# Final verification
# ============================================
echo ""
echo "=========================================="
echo "  Internal Firewall Configuration Complete"
echo "=========================================="
echo ""
echo "Logging: NFLOG + ulogd2"
echo "Log file: /var/log/firewall/firewall-events.log"
echo ""
echo "Helper Commands:"
echo "  fw-stats      - Show statistics and recent events"
echo "  fw-logs-live  - View live logs"
echo "  fw-search     - Search logs"
echo ""
echo "Testing..."

sleep 3

if [ -f /var/log/firewall/firewall-events.log ]; then
    SIZE=$(stat -c%s /var/log/firewall/firewall-events.log 2>/dev/null || echo "0")
    echo "Log file size: $SIZE bytes"
    
    if [ "$SIZE" -gt "0" ]; then
        echo "  Logging is working! Latest entries:"
        tail -5 /var/log/firewall/firewall-events.log
    else
        echo "  Log file exists but is empty (normal if no traffic matched rules yet)"
        echo ""
        echo "Verification:"
        echo "  - ulogd2: $(pgrep -x ulogd >/dev/null && echo 'RUNNING  ' || echo 'NOT RUNNING  ')"
        echo "  - NFLOG rules: $(iptables -L -v -n | grep -c NFLOG) configured"
    fi
else
    echo "   WARNING: Log file not created!"
fi

echo ""
echo "=========================================="

EOF

log_ok "Internal Firewall configured"


# =========================
# Firewall: External_FW
# - NAT (MASQUERADE) für ausgehenden Verkehr zur 'Internet'-Schnittstelle (eth2)
# - DMZ -> Internet erlaubt
# - Internet -> DMZ/Internal (NEW) explicit DROP
# =========================
log_step "2/2" "Configuring External Firewall..."
log_info "Configuring External Firewall"
sudo docker exec -i clab-MaJuVi-External_FW bash <<'EOF'
set -e

# ============================================
# Install packages
# ============================================
echo "[1/7] Installing packages..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends \
    iptables \
    iproute2 \
    iputils-ping \
    net-tools \
    ulogd2 \
    ulogd2-json \
    wget \
    curl \
    bash \
    procps \
    gnupg \
    ca-certificates \
    2>&1 | tail -10

echo "[OK] Packages installed"


echo "[2/7] Installing Filebeat..."
# Install Filebeat
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update -qq
apt-get install -y filebeat 2>&1 | tail -10

# ============================================
# Switch to iptables-legacy
# ============================================
echo "[3/7] Switching to iptables-legacy..."
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
echo "[OK] Using: $(iptables --version)"

# ============================================
# Configure network interfaces
# ============================================
echo "[4/7] Configuring network interfaces..."
ip addr add 10.0.2.2/24 dev eth1 2>/dev/null || true      # DMZ
ip addr add 172.168.3.2/30 dev eth2 2>/dev/null || true   # Router Edge
ip addr add 192.168.20.2/24 dev eth4 2>/dev/null || true  # Internal_FW link
ip addr add 10.0.3.6/30 dev eth3 || true     # zu SIEM_FW (.6 in .4-.7)
ip link set eth1 up
ip link set eth2 up
ip link set eth4 up
ip link set eth4 up
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "[OK] Network configured"

# ============================================
# Configure ulogd2 for NFLOG
# ============================================
echo "[5/7] Configuring ulogd2..."
mkdir -p /var/log/firewall /var/log/ulogd /etc/ulogd

cat > /etc/ulogd/ulogd.conf << 'ULOGD_CONFIG'
[global]
logfile="/var/log/ulogd/ulogd.log"
loglevel=5

plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_raw2packet_BASE.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IFINDEX.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IP2STR.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_PRINTPKT.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_LOGEMU.so"

stack=log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU

[log1]
group=0

[base1]
[ifi1]
[ip2str1]
[print1]

[emu1]
file="/var/log/firewall/firewall-events.log"
sync=1
ULOGD_CONFIG

# Stop any existing ulogd
pkill ulogd 2>/dev/null || true
sleep 1

# Start ulogd2
ulogd -d -c /etc/ulogd/ulogd.conf &
ULOGD_PID=$!
sleep 2

# Verify ulogd is running
if pgrep -x ulogd >/dev/null; then
    echo "[OK] ulogd2 running (PID: $(pgrep -x ulogd))"
else
    echo "[ERROR] ulogd2 failed to start!"
    if [ -f /var/log/ulogd/ulogd.log ]; then
        echo "ulogd log:"
        cat /var/log/ulogd/ulogd.log
    fi
    exit 1
fi

# Configure Filebeat
cat > /etc/filebeat/filebeat.yml << 'FILEBEAT_CONFIG'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/firewall/firewall-events.log
  fields:
    firewall: external
    log_type: firewall
  fields_under_root: true

output.logstash:
  hosts: ["10.0.3.10:5044"]

path.data: /var/lib/filebeat
logging.level: info
FILEBEAT_CONFIG

# Start Filebeat
nohup filebeat -e -c /etc/filebeat/filebeat.yml > /var/log/filebeat.log 2>&1 &
FILEBEAT_PID=$!
sleep 2

# ============================================
# Configure iptables with NFLOG
# ============================================
echo "[6/7] Configuring iptables with NFLOG..."

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X 2>/dev/null || true

# Set policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ============================================
# INPUT Chain
# ============================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/sec -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.2.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 192.168.20.0/24 -j ACCEPT

# Log INPUT drops
iptables -A INPUT -m limit --limit 5/min -j NFLOG \
  --nflog-prefix "[EXT-FW-INPUT-DROP] " \
  --nflog-group 0

# ============================================
# FORWARD Chain
# ============================================

# Invalid packets
iptables -N LOG_INVALID
iptables -A LOG_INVALID -m limit --limit 10/min --limit-burst 20 -j NFLOG \
  --nflog-prefix "[EXT-FW-INVALID-DROP] " \
  --nflog-group 0
iptables -A LOG_INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j LOG_INVALID

# Established/Related
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# DMZ → Internet (NEW)
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[EXT-FW-DMZ-TO-INET] " \
  --nflog-group 0
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT

# Internal_FW → Internet (NEW)
iptables -A FORWARD -i eth4 -o eth2 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[EXT-FW-INTERN-TO-INET] " \
  --nflog-group 0
iptables -A FORWARD -i eth4 -o eth2 -m conntrack --ctstate NEW -j ACCEPT

# Internet → DMZ (blocked NEW connections)
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[EXT-FW-INET-TO-DMZ-DROP] " \
  --nflog-group 0
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j DROP

# Internet → Internal (blocked NEW connections)
iptables -A FORWARD -i eth2 -o eth4 -m conntrack --ctstate NEW -m limit --limit 10/min -j NFLOG \
  --nflog-prefix "[EXT-FW-INET-TO-INTERN-DROP] " \
  --nflog-group 0
iptables -A FORWARD -i eth2 -o eth4 -m conntrack --ctstate NEW -j DROP

# Catch-all FORWARD drops
iptables -A FORWARD -m limit --limit 5/min -j NFLOG \
  --nflog-prefix "[EXT-FW-FORWARD-DROP] " \
  --nflog-group 0

# ============================================
# NAT Configuration
# ============================================
# MASQUERADE traffic that leaves via eth2 (towards router-edge/internet)
iptables -t nat -A POSTROUTING -o eth2 -s 192.168.10.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth2 -s 10.0.2.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth2 -s 192.168.20.0/24 -j MASQUERADE

echo "[OK] iptables rules and NAT configured"

# ============================================
# Routing
# ============================================
ip route replace 172.168.2.0/30 via 172.168.3.1 dev eth2 2>/dev/null || true
ip route replace 192.168.10.0/24 via 192.168.20.1 dev eth4 2>/dev/null || true
ip route add 10.0.3.0/24 via 10.0.3.5 dev eth3 || true

# ============================================
# Create helper scripts
# ============================================
echo "[7/7] Creating helper scripts..."

cat > /usr/local/bin/fw-stats << 'STATS_SCRIPT'
#!/bin/bash
echo "=========================================="
echo "External Firewall Statistics"
echo "=========================================="
echo ""
echo "Logging Method: NFLOG + ulogd2"
echo "iptables: $(iptables --version)"
echo ""

# ulogd status
if pgrep -x ulogd >/dev/null; then
    echo "ulogd2 Status:   RUNNING (PID: $(pgrep -x ulogd))"
else
    echo "ulogd2 Status:   NOT RUNNING"
fi
echo ""

echo "--- Last 20 Firewall Events ---"
if [ -f /var/log/firewall/firewall-events.log ] && [ -s /var/log/firewall/firewall-events.log ]; then
    tail -20 /var/log/firewall/firewall-events.log
else
    LOG_SIZE=$(stat -c%s /var/log/firewall/firewall-events.log 2>/dev/null || echo "0")
    echo "No events logged yet"
    echo "Log file size: $LOG_SIZE bytes"
    echo ""
    if [ "$LOG_SIZE" == "0" ] && ! pgrep -x ulogd >/dev/null; then
        echo "   WARNING: ulogd2 is not running!"
        echo "   Restart it with: ulogd -d -c /etc/ulogd/ulogd.conf &"
    fi
fi

echo ""
echo "--- Event Summary ---"
if [ -f /var/log/firewall/firewall-events.log ]; then
    TOTAL=$(wc -l < /var/log/firewall/firewall-events.log)
    echo "Total events: $TOTAL"
    
    if [ $TOTAL -gt 0 ]; then
        echo ""
        echo "Events by type:"
        grep -o 'EXT-FW-[A-Z-]*' /var/log/firewall/firewall-events.log 2>/dev/null | sort | uniq -c | sort -rn || true
    fi
fi

echo ""
echo "--- iptables Rule Counters ---"
iptables -L -v -n | grep -E "Chain|NFLOG|pkts" | head -30

echo ""
echo "--- NAT Rules ---"
iptables -t nat -L -v -n | grep -E "Chain|MASQUERADE|pkts" | head -20

echo ""
echo "=========================================="
STATS_SCRIPT

cat > /usr/local/bin/fw-logs-live << 'LIVE_SCRIPT'
#!/bin/bash
echo "=== Live External Firewall Logs (NFLOG) ==="
echo "Press CTRL+C to stop"
echo ""

if [ -f /var/log/firewall/firewall-events.log ]; then
    tail -f /var/log/firewall/firewall-events.log
else
    echo "ERROR: Log file not found"
    exit 1
fi
LIVE_SCRIPT

cat > /usr/local/bin/fw-search << 'SEARCH_SCRIPT'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: fw-search <search_term>"
    echo "Example: fw-search '10.0.2.30'"
    echo "Example: fw-search 'INET-TO-DMZ'"
    exit 1
fi

echo "Searching for: $1"
echo ""

if [ -f /var/log/firewall/firewall-events.log ]; then
    grep -i "$1" /var/log/firewall/firewall-events.log || echo "No matches found"
else
    echo "ERROR: Log file not found"
    exit 1
fi
SEARCH_SCRIPT

chmod +x /usr/local/bin/fw-stats
chmod +x /usr/local/bin/fw-logs-live
chmod +x /usr/local/bin/fw-search

echo "[OK] Helper scripts created"

# ============================================
# Final verification
# ============================================
echo ""
echo "=========================================="
echo "  External Firewall Configuration Complete"
echo "=========================================="
echo ""
echo "Logging: NFLOG + ulogd2"
echo "Log file: /var/log/firewall/firewall-events.log"
echo ""
echo "Helper Commands:"
echo "  fw-stats      - Show statistics and recent events"
echo "  fw-logs-live  - View live logs"
echo "  fw-search     - Search logs"
echo ""
echo "Testing..."

sleep 3

if [ -f /var/log/firewall/firewall-events.log ]; then
    SIZE=$(stat -c%s /var/log/firewall/firewall-events.log 2>/dev/null || echo "0")
    echo "Log file size: $SIZE bytes"
    
    if [ "$SIZE" -gt "0" ]; then
        echo "  Logging is working! Latest entries:"
        tail -5 /var/log/firewall/firewall-events.log
    else
        echo "  Log file exists but is empty (normal if no traffic matched rules yet)"
        echo ""
        echo "Verification:"
        echo "  - ulogd2: $(pgrep -x ulogd >/dev/null && echo 'RUNNING  ' || echo 'NOT RUNNING  ')"
        echo "  - NFLOG rules: $(iptables -L -v -n | grep -c NFLOG) configured"
    fi
else
    echo "   WARNING: Log file not created!"
fi

echo ""
echo "=========================================="

EOF
log_ok "External Firewall configured"

log_ok "Configuration of Firewalls completed"

log_section "SECTION 7: Configuring Internal Hosts and Switches..."
# =========================
# Internal Clients (IP + default route)
# =========================
log_step "1/2" "Configuring Internal Clients..."
log_info "Configuring Internal Clients..."
sudo docker exec -i clab-MaJuVi-Internal_Client1 sh <<EOF
apk add --no-cache curl >/dev/null 2>&1 || true
echo '172.168.2.1    internet' >> /etc/hosts
ip addr add ${Internal_Client1_ip} dev eth1 || true
ip link set eth1 up
ip route replace default via 192.168.10.1 || true
EOF

sudo docker exec -i clab-MaJuVi-Internal_Client2 sh <<EOF
apk add --no-cache curl >/dev/null 2>&1 || true
echo '172.168.2.1    internet' >> /etc/hosts
ip addr add ${Internal_Client2_ip} dev eth1 || true
ip link set eth1 up
ip route replace default via 192.168.10.1 || true
EOF

log_ok "Internal Clients configured"

log_step "2/2" "Configuring Internal Switch..."
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

log_ok "Internal Switch configured"

echo ""
log_ok "Internal Hosts and Switches configured"


log_section "SECTION 8: Configuring DMZ..."
# =========================
# DMZ Switch config
# =========================
log_step "1/3" "Configuring DMZ Switch..."
log_info "Configurating DMZ Switch"
sudo docker exec -i clab-MaJuVi-DMZ_Switch sh <<'EOF'
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
EOF

log_ok "DMZ Switch configured"

# =========================
# Database config
# =========================
log_step "2/3" "Configuring Database..."
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
# Webserver config
# =========================
log_step "3/3" "Configuring Webserver..."
log_info "Configuring Webserver"
sudo docker exec -i --user root clab-MaJuVi-Web_Proxy_WAF sh <<'EOF'
set -e
apk add --no-cache iproute2 iputils >/dev/null 2>&1 || true

ip addr add 10.0.2.30/24 dev eth1 || true
ip link set eth1 up
ip route replace default via 10.0.2.1 || true
EOF

log_ok "Webserver configured"

echo ""
log_ok "DMZ configured"

log_section "SECTION 9: Configuring Router-edge..."
# router-edge configuration
log_info "Configuring router-edge"
sudo docker exec -i clab-MaJuVi-router-edge sh <<'EOF'
set -e
# Interfaces
ip addr add 172.168.2.2/30 dev eth1  # from router-internet
ip addr add 172.168.3.1/30 dev eth2  # to External_FW
ip link set eth1 up
ip link set eth2 up

echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush rules
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow NEW traffic to/from Internet via eth1/eth2
iptables -A FORWARD -i eth1 -o eth2 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# --- Prevent Internal → Attacker (eth1) directly
iptables -I FORWARD 1 -s 192.168.10.0/24 -d 200.168.1.0/24 -m conntrack --ctstate NEW -j DROP

# Routing
ip route replace 10.0.2.0/24 via 172.168.3.2
ip route replace 192.168.10.0/24 via 172.168.3.2
ip route replace 200.168.1.0/24 via 172.168.2.1
EOF

log_ok "router-edge configured"

log_section "SECTION 10: Configuring Attacker and router-internet..."
log_step "1/2" "Configuring Attacker..."
# =========================
# Attacker host config (netzwerkseitig)
# =========================
log_info "Configuring Attacker"
sudo docker exec -i clab-MaJuVi-Attacker sh <<EOF
set -e
ip addr add 200.168.1.10/24 dev eth1 || true
ip link set eth1 up
ip route replace default via 200.168.1.1 || true
EOF

log_ok "Attacker configured"

# =========================
# router-internet configuration
# - Drop NEW destined to DMZ/INTERNAL from Attacker link (eth1)
# - Otherwise allow established/related
# =========================
log_step "2/2" "Configuring router-internet..."
log_info "Configuring router-internet"
sudo docker exec -i clab-MaJuVi-router-internet sh <<'EOF'
set -e
# ensure tooling
if command -v apt >/dev/null 2>&1; then
  apt update >/dev/null 2>&1 || true
  apt install -y iproute2 iputils-ping iptables >/dev/null 2>&1 || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache iproute2 iputils iptables >/dev/null 2>&1 || true
fi

# Interfaces: eth1 <-> Attacker, eth2 <-> router-edge
ip addr add 200.168.1.1/24 dev eth1 || true
ip addr add 172.168.2.1/30 dev eth2 || true

ip link set eth1 up
ip link set eth2 up

# forwarding aktivieren
echo 1 > /proc/sys/net/ipv4/ip_forward || true

# Disable rp_filter (testweise, vermeidet unerwartete Drops)
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.eth1.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.eth2.rp_filter=0 >/dev/null 2>&1 || true

# Base firewall: flush, default drop, allow established/related
iptables -F
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow router-side initiated NEW connections to Attacker (eth2 -> eth1)
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# Explicitly drop any NEW from Attacker side (eth1) aimed at DMZ (10.0.2.0/24) or Internal (192.168.10.0/24)
iptables -A FORWARD -i eth1 -o eth2 -d 10.0.2.0/24 -m conntrack --ctstate NEW -j DROP
iptables -A FORWARD -i eth1 -o eth2 -d 192.168.10.0/24 -m conntrack --ctstate NEW -j DROP

# Ensure routes for lab networks (so router-internet knows how to reach DMZ/Internal)
# next-hop is router-edge (172.168.2.2)
ip route replace 10.0.2.0/24 via 172.168.2.2 || true
ip route replace 192.168.10.0/24 via 172.168.2.2 || true
# route to attacker network (locally attached already, but keep explicit)
ip route replace 200.168.1.0/24 dev eth1 || true
ip route replace 172.168.3.2 via 172.168.2.2 dev eth2
EOF

log_ok "router-internet configured"

echo ""
log_ok "Attacker and router-internet configured"


log_section "SECTION 11: Configuring SIEM components..."

log_section "SECTION 11: Configuring SIEM components..."

# =========================
# Configure SIEM_FW
# =========================
log_step "1/5" "Configuring SIEM_FW..."
log_info "Configuring SIEM_FW with restrictive firewall rules..."

sudo docker exec -i clab-MaJuVi-SIEM_FW bash <<'EOF'
set -e
apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends \
    iptables \
    iproute2 \
    iputils-ping \
    2>&1 | tail -10

echo "Configuring SIEM_FW interfaces and routing..."

# Separate /30 Subnetze für jeden Link
ip addr add 10.0.3.1/30 dev eth1 || true
ip addr add 10.0.3.5/30 dev eth2 || true
ip addr add 10.0.3.9/30 dev eth3 || true
ip addr add 10.0.3.13/30 dev eth4 || true
ip addr add 10.0.3.17/30 dev eth5 || true
ip addr add 10.0.3.21/30 dev eth6 || true

# Interfaces aktivieren
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
ip link set eth5 up
ip link set eth6 up

# IP Forwarding aktivieren
echo 1 > /proc/sys/net/ipv4/ip_forward

# Disable ICMP redirects
sysctl -w net.ipv4.conf.all.send_redirects=0 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.send_redirects=0 >/dev/null 2>&1

# Disable rp_filter für flexible Routing
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1

# Flush all rules
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X 2>/dev/null || true

# Default DROP policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# INPUT Chain - allow management
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/sec -j ACCEPT

# FORWARD Chain - Explicit Allow Rules

# 1. Admin_PC → Kibana (Port 5601)
iptables -A FORWARD -s 10.0.3.22 -d 10.0.3.18 -p tcp --dport 5601 -m conntrack --ctstate NEW -j ACCEPT

# 2.  Admin_PC → Elasticsearch (Port 9200)
iptables -A FORWARD -s 10.0.3.22 -d 10.0.3.14 -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 10.0.3.22 -d 10.0.3.26 -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
# 3.  Firewall-Filebeats → Logstash (Port 5044)
iptables -A FORWARD -s 10.0.3.2 -d 10.0.3.10 -p tcp --dport 5044 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 10.0.3.6 -d 10.0.3.10 -p tcp --dport 5044 -m conntrack --ctstate NEW -j ACCEPT

# 4.  Logstash → Elasticsearch (Port 9200)
iptables -A FORWARD -s 10.0.3.10 -d 10.0.3.26 -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT

# 5. Kibana → Elasticsearch (Port 9200)
iptables -A FORWARD -s 10.0.3.30 -d 10.0.3.26 -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 10.0.3.18 -d 10.0.3.26 -p tcp --dport 9200 -m conntrack --ctstate NEW -j ACCEPT
# 6.  Established/Related connections
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 7. Log dropped packets
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "[SIEM_FW-DROP] " --log-level 7

echo "SIEM_FW configured with restrictive micro-segmentation rules"
EOF

log_ok "SIEM_FW configured"

# =========================
# Configure Logstash
# =========================
log_step "2/5" "Configuring Logstash..."
log_info "Configuring Logstash network via nsenter..."

LOGSTASH_PID=$(sudo docker inspect -f '{{.State.Pid}}' clab-MaJuVi-logstash)
sudo nsenter -t $LOGSTASH_PID -n ip addr add 10.0.3.10/30 dev eth1 || true
sudo nsenter -t $LOGSTASH_PID -n ip addr add 10.0.3.25/30 dev eth2 || true
sudo nsenter -t $LOGSTASH_PID -n ip link set eth1 up
sudo nsenter -t $LOGSTASH_PID -n ip link set eth2 up
sudo nsenter -t $LOGSTASH_PID -n ip route replace default via 10.0.3.9 dev eth1 || true

echo "=== Logstash Network Configuration ==="
sudo nsenter -t $LOGSTASH_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $LOGSTASH_PID -n ip route show || true

log_ok "Logstash configured"

# =========================
# Configure Admin_PC
# =========================
log_step "3/5" "Configuring Admin_PC..."
log_info "Configuring Admin_PC"
sudo docker exec -i clab-MaJuVi-Admin_PC sh <<EOF
set -e
apk add --no-cache curl >/dev/null 2>&1 || true
ip addr add 10.0.3.22/30 dev eth1 || true
ip link set eth1 up
ip route replace default via 10.0.3.21 || true
EOF

log_ok "Admin_PC configured"

# =========================
# Configure Elasticsearch
# =========================
log_step "4/5" "Configuring Elasticsearch..."
log_info "Configuring Elasticsearch network via nsenter..."

ELASTICSEARCH_PID=$(sudo docker inspect -f '{{.State.Pid}}' clab-MaJuVi-elasticsearch)
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add 10.0.3.26/30 dev eth1 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add 10.0.3.29/30 dev eth2 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr add 10.0.3.14/30 dev eth3 || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth1 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth2 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip link set eth3 up
sudo nsenter -t $ELASTICSEARCH_PID -n ip route replace default via 10.0.3.13 dev eth3 || true

echo "=== Elasticsearch Network Configuration ==="
sudo nsenter -t $ELASTICSEARCH_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $ELASTICSEARCH_PID -n ip route show || true

log_ok "Elasticsearch configured"

# =========================
# Configure Kibana
# =========================
log_step "5/5" "Configuring Kibana..."
log_info "Configuring Kibana network via nsenter..."

KIBANA_PID=$(sudo docker inspect -f '{{.State.Pid}}' clab-MaJuVi-kibana)
sudo nsenter -t $KIBANA_PID -n ip addr add 10.0.3.30/30 dev eth1 || true
sudo nsenter -t $KIBANA_PID -n ip addr add 10.0.3.18/30 dev eth2 || true
sudo nsenter -t $KIBANA_PID -n ip link set eth1 up
sudo nsenter -t $KIBANA_PID -n ip link set eth2 up
sudo nsenter -t $KIBANA_PID -n ip route replace default via 10.0.3.17 dev eth2 || true
sudo nsenter -t $KIBANA_PID -n ip route add 10.0.3.26/32 via 10.0.3.29 dev eth1 || true

echo "=== Kibana Network Configuration ==="
sudo nsenter -t $KIBANA_PID -n ip addr show | grep "inet " || true
sudo nsenter -t $KIBANA_PID -n ip route show || true

log_ok "Kibana configured"

echo ""
log_ok "SIEM components configured"

log_section "SECTION 12: Lab deployment and configuration completed"
log_ok "Lab deployment and configuration completed"
