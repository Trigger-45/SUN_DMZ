#!/bin/bash
set -euo pipefail

# Get script directory and set up paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
CONFIG_DIR="${BASE_DIR}/config"

# Load dependencies
source "${SCRIPTS_DIR}/lib/logging.sh"
source "${CONFIG_DIR}/variables.sh"

Proxy_WAF_Container="clab-${LAB_NAME}-Proxy_WAF"


sudo docker exec -i --user root \
    -e DMZ_WAF_ETH1_IP="${DMZ_WAF_ETH1_IP}" \
    -e DMZ_WAF_ETH2_IP="${DMZ_WAF_ETH2_IP}" \
    -e INT_FW_ETH2_IP="${INT_FW_ETH2_IP}" \
    -e EXT_FW_ETH1_IP="${EXT_FW_ETH1_IP}" \
    -e SUBNET_INTERNAL="${SUBNET_INTERNAL}" \
    -e DMZ_WEB_ETH1_IP="${DMZ_WEB_ETH1_IP}" \
    "${Proxy_WAF_Container}" sh << 'EOF'
set -e

ip addr add ${DMZ_WAF_ETH1_IP} dev eth1 || true
ip addr add ${DMZ_WAF_ETH2_IP} dev eth2 || true
ip link set eth1 up
ip link set eth2 up

# IP-Route 
ip route add ${SUBNET_INTERNAL} via ${INT_FW_ETH2_IP%/*} dev eth1 || true
ip route replace default via ${EXT_FW_ETH1_IP%/*} || true
ip route add ${DMZ_WEB_ETH1_IP%/*} via ${DMZ_WAF_ETH2_IP%/*} dev eth2 || true

# Find existing modsecurity config path
MODSEC_CONF=""
if [ -f /etc/modsecurity.d/modsecurity.conf ]; then
    MODSEC_CONF="/etc/modsecurity.d/modsecurity.conf"
elif [ -f /etc/nginx/modsecurity/modsecurity.conf ]; then
    MODSEC_CONF="/etc/nginx/modsecurity/modsecurity.conf"
fi

# Configure Nginx - Override the existing default.conf with Flask backend
cat > /etc/nginx/templates/conf.d/default.conf.template << 'NGINX_CONFIG'
upstream flask_backend {
    server 10.0.2.10:5000 max_fails=3 fail_timeout=30s;
}

server {
    listen 8080 default_server;
    server_name _;

    location / {
        proxy_pass http://flask_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX_CONFIG

# Remove old config if exists and restart nginx
rm -f /etc/nginx/conf.d/default.conf
rm -f /etc/nginx/conf.d/flask-upstream.conf
cp /etc/nginx/templates/conf.d/default.conf.template /etc/nginx/conf.d/default.conf

# Send HUP signal to nginx to reload config
echo "Reloading Nginx configuration..."
killall -HUP nginx 2>/dev/null || nginx -s reload 2>/dev/null || echo "Nginx will reload on next restart"
echo "Nginx configuration updated"
EOF


