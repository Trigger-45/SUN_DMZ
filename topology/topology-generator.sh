#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/config/variables.sh"

log_info "Generating topology file: ${TOPO_FILE}"

cat << EOF > "${SCRIPT_DIR}/topology/${TOPO_FILE}"
name: ${LAB_NAME}
mgmt:
  network: ${MGMT_NETWORK}
  ipv4-subnet: ${MGMT_SUBNET}

topology:
  nodes:
    # ==========================================
    # INTERNAL NETWORK
    # ==========================================
    Internal_Switch:
      kind: linux
      image: ${IMG_FRR}
      type: bridge
      group: switch
      cap-add:
        - NET_ADMIN
        - NET_RAW

    Internal_Client1:
      kind: linux
      image: ${IMG_ALPINE}
      type: host
      group: server
      cap-add:
        - NET_ADMIN

    Internal_Client2:
      kind: linux
      image: ${IMG_ALPINE}
      type: host
      group: server
      cap-add:
        - NET_ADMIN

    siem_pc:
      kind: linux
      image: ${IMG_ALPINE}
      type: host
      group: server
      cap-add:
        - NET_ADMIN

    Internal_FW:
      kind: linux
      image: ${IMG_UBUNTU}
      type: host
      group: firewall
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW

    Internal_IDS:
      kind: linux
      image: ${IMG_SURICATA}
      group: ids
      binds:
        - ${SCRIPT_DIR}/config/suricata/suricata.yml:/etc/suricata/suricata.yml:ro
        - ${SCRIPT_DIR}/config/suricata/rules:/var/lib/suricata/rules:ro
        - ${SCRIPT_DIR}/config/suricata/logs-dmz:/var/log/suricata:rw
      cmd: suricata -i eth1 --af-packet
      cap-add:
        - NET_ADMIN
        - NET_RAW

    # ==========================================
    # DMZ NETWORK
    # ==========================================
    DMZ_Switch:
      kind: linux
      image: ${IMG_FRR}
      type: bridge
      group: switch
      cap-add:
        - NET_ADMIN
        - NET_RAW

    Flask_Webserver:
      kind: linux
      image: ${IMG_UBUNTU}
      group: server
      cap-add:
        - NET_ADMIN

    Proxy_WAF:
      kind: linux
      image: ${IMG_MODSECURITY}
      group: firewall
      ports:
        - "8080:8080"
      env:
        MODSEC_AUDIT_ENGINE: "On"
        MODSEC_AUDIT_LOG: "/var/log/audit/audit.log"
        MODSEC_AUDIT_LOG_TYPE: "Serial"
        MODSEC_AUDIT_LOG_PARTS: "ABIFHZ"
        BACKEND: "http://10.0.2.10:5000"
        MODSEC_RULE_ENGINE: "On"
        PARANOIA: "2"
        ANOMALY_INBOUND: "5"
        ANOMALY_OUTBOUND: "4"
        BLOCKING_PARANOIA: "2"
        EXECUTING_PARANOIA: "2"
        DETECTION_PARANOIA: "2"
        MODSEC_RESP_BODY_ACCESS: "On"
        MODSEC_REQ_BODY_ACCESS: "On"
        MAX_FILE_SIZE: "10485760"
        MAX_NUM_ARGS: "300"
        ARG_NAME_LENGTH: "256"
        ARG_LENGTH: "4000"
        TOTAL_ARG_LENGTH: "64000"
        COMBINED_FILE_SIZES: "52428800"
        RESTRICTED_EXTENSIONS: ".asa/ .asax/ .ascx/ .backup/ .bak/ .bat/ .cdx/ .cer/ .cfg/ .cmd/ .com/ .config/ .conf/ .cs/ .csproj/ .csr/ .dat/ .db/ .dbf/ .dll/ .dos/ .htr/ .htw/ .ida/ .idc/ .idq/ .inc/ .ini/ .key/ .licx/ .lnk/ .log/ .mdb/ .old/ .pass/ .pdb/ .pol/ .printer/ .pwd/ .rdb/ .resources/ .resx/ .sql/ .swp/ .sys/ .vb/ .vbs/ .vbproj/ .vsdisco/ .webinfo/ .xsd/ .xsx/"
        RESTRICTED_HEADERS: "/proxy/ /lock-token/ /content-range/ /if/"
        ALLOWED_METHODS: "GET HEAD POST OPTIONS"
        ALLOWED_REQUEST_CONTENT_TYPE: "|application/x-www-form-urlencoded| |multipart/form-data| |multipart/related| |text/xml| |application/xml| |application/soap+xml| |application/json| |application/cloudevents+json| |application/cloudevents-batch+json|"
        ENFORCE_BODYPROC_URLENCODED: "1"
      binds:
        - ${SCRIPT_DIR}/config/webserver-details/server.crt:/etc/nginx/conf/server.crt:rw
        - ${SCRIPT_DIR}/config/webserver-details/server.key:/etc/nginx/conf/server.key:rw
      cap-add:
        - NET_ADMIN

    Database:
      kind: linux
      image: ${IMG_POSTGRES}
      group: server
      env:
        POSTGRES_USER: admin_user
        POSTGRES_PASSWORD: securePassword123
        POSTGRES_DB: mydatabase
      binds:
        - ${SCRIPT_DIR}/config/db-init/init-users.sql:/docker-entrypoint-initdb.d/init-users.sql:ro
      ports:
        - "3636:5432"
      cap-add:
        - NET_ADMIN

    DMZ_IDS:
      kind: linux
      image: ${IMG_SURICATA}
      group: ids
      binds:
        - ${SCRIPT_DIR}/config/suricata/suricata.yml:/etc/suricata/suricata.yml:ro
        - ${SCRIPT_DIR}/config/suricata/rules:/var/lib/suricata/rules:ro
        - ${SCRIPT_DIR}/config/suricata/logs-dmz:/var/log/suricata:rw
      cmd: suricata -i eth1 --af-packet
      cap-add:
        - NET_ADMIN
        - NET_RAW

    External_FW:
      kind: linux
      image: ${IMG_UBUNTU}
      type: host
      group: firewall
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW

    # ==========================================
    # SIEM NETWORK
    # ==========================================
    SIEM_FW:
      kind: linux
      image: ${IMG_UBUNTU}
      type: host
      group: firewall
      cap-add:
        - NET_ADMIN
        - SYS_MODULE
        - NET_RAW

    elasticsearch:
      kind: linux
      image: ${IMG_ELASTICSEARCH}
      group: siem
      env:
        discovery.type: single-node
        xpack.security.enabled: "false"
        ES_JAVA_OPTS: "-Xms512m -Xmx512m"
      ports:
        - "9200:9200"
      cap-add:
        - NET_ADMIN

    logstash:
      kind: linux
      image: ${IMG_LOGSTASH}
      group: siem
      binds:
        - ${SCRIPT_DIR}/config/logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:rw
        - ${SCRIPT_DIR}/config/logstash/pipeline:/usr/share/logstash/pipeline:rw
      env:
        XPACK_MONITORING_ENABLED: "false"
        LS_JAVA_OPTS: "-Xmx512m -Xms512m"
      cap-add:
        - NET_ADMIN
    kibana:
      kind: linux
      image: ${IMG_KIBANA}
      group: siem
      env:
        ELASTICSEARCH_HOSTS: "http://10.0.3.26:9200"
      ports:
        - "5601:5601"
      cap-add:
        - NET_ADMIN

    # ==========================================
    # EDGE / INTERNET
    # ==========================================
    router-edge:
      kind: linux
      image: ${IMG_FRR}
      type: host
      group: router
      cap-add:
        - NET_ADMIN
        - NET_RAW

    router-internet:
      kind: linux
      image: ${IMG_FRR}
      type: host
      group: router
      cap-add:
        - NET_ADMIN
        - NET_RAW

    Attacker:
      kind: linux
      image: ${IMG_KALI}
      type: host
      group: server
      cap-add:
        - NET_ADMIN

  # ==========================================
  # LINKS (Topology Connections)
  # ==========================================
  links:
    # Internal Network
    - endpoints: ["Internal_Client1:eth1", "Internal_Switch:eth1"]
    - endpoints: ["Internal_Client2:eth1", "Internal_Switch:eth2"]
    - endpoints: ["Internal_Switch:eth3", "Internal_FW:eth1"]
    - endpoints: ["Internal_Switch:eth4", "Internal_IDS:eth1"]
    
    # Internal FW to DMZ/External
    - endpoints: ["Internal_FW:eth2", "DMZ_Switch:eth1"]
    - endpoints: ["Internal_FW:eth3", "External_FW:eth4"]
    - endpoints: ["Internal_FW:eth4", "SIEM_FW:eth1"]
    
    # DMZ Network
    - endpoints: ["DMZ_Switch:eth2", "External_FW:eth1"]
    - endpoints: ["DMZ_Switch:eth3", "Proxy_WAF:eth1"]
    - endpoints: ["DMZ_Switch:eth4", "DMZ_IDS:eth1"]
    - endpoints: ["Proxy_WAF:eth2", "Flask_Webserver:eth1"]
    - endpoints: ["Proxy_WAF:eth3", "SIEM_FW:eth9"]
    - endpoints: ["Flask_Webserver:eth2", "Database:eth1"]
    
    # IDS to SIEM
    - endpoints: ["DMZ_IDS:eth2", "SIEM_FW:eth7"]
    - endpoints: ["Internal_IDS:eth2", "SIEM_FW:eth8"]
    
    # External FW
    - endpoints: ["External_FW:eth2", "router-edge:eth2"]
    - endpoints: ["External_FW:eth3", "SIEM_FW:eth2"]
    
    # SIEM Network
    - endpoints: ["SIEM_FW:eth3", "logstash:eth1"]
    - endpoints: ["SIEM_FW:eth4", "elasticsearch:eth3"]
    - endpoints: ["SIEM_FW:eth5", "kibana:eth2"]
    - endpoints: ["SIEM_FW:eth6", "siem_pc:eth1"]
    
    - endpoints: ["logstash:eth2", "elasticsearch:eth1"]
    - endpoints: ["elasticsearch:eth2", "kibana:eth1"]
    
    # Edge / Internet
    - endpoints: ["router-edge:eth1", "router-internet:eth2"]
    - endpoints: ["router-internet:eth1", "Attacker:eth1"]
EOF

log_ok "Topology file generated: ${SCRIPT_DIR}/topology/${TOPO_FILE}"