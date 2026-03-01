#!/usr/bin/env bash
set -uo pipefail

# =========================
# Terminal Color Setup
# =========================
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"
ENDCOLOR="\e[0m"

# =========================
# Test Statistics
# =========================
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
declare -a FAILED_TEST_NAMES
declare -a FAILED_TEST_DETAILS

# =========================
# Simple Test Runner (No Cursor Movement)
# =========================
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout="${3:-10}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Print test line with waiting status
    printf "%-70s" "[$(printf '%02d' $TOTAL_TESTS)] ${test_name}..."
    echo -ne "${YELLOW}[RUNNING]${ENDCOLOR}"
    
    # Run test with timeout
    local output
    local exit_code=0
    
    output=$(timeout $timeout bash -c "$test_command" 2>&1) || exit_code=$?
    
    # Move cursor back to overwrite status
    echo -ne "\r"
    printf "%-70s" "[$(printf '%02d' $TOTAL_TESTS)] ${test_name}..."
    
    # Check result
    if [ $exit_code -eq 124 ]; then
        echo -e "${RED}[TIMEOUT]${ENDCOLOR}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")
        FAILED_TEST_DETAILS+=("TIMEOUT after ${timeout}s")
        return 1
    elif [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${ENDCOLOR}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}[FAILED] ${ENDCOLOR}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")
        local short_output="${output:0:100}"
        FAILED_TEST_DETAILS+=("Exit code: $exit_code | ${short_output}")
        return 1
    fi
}

# =========================
# Header
# =========================
clear
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${ENDCOLOR}"
echo -e "${BOLD}${CYAN}║           DMZ Lab Network & Security Test Skript                   ║${ENDCOLOR}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${ENDCOLOR}"
echo ""

# =========================
# SECTION 1: Container Health Tests
# =========================
echo -e "${BOLD}${MAGENTA}═══ SECTION 1: Container Health Tests ═══${ENDCOLOR}"
echo ""

run_test "Internal_Client1 running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Internal_Client1' --format '{{.Names}}' | grep -q 'Internal_Client1'" 5

run_test "Internal_Client2 running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Internal_Client2' --format '{{.Names}}' | grep -q 'Internal_Client2'" 5

run_test "Internal_FW running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Internal_FW' --format '{{.Names}}' | grep -q 'Internal_FW'" 5

run_test "External_FW running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-External_FW' --format '{{.Names}}' | grep -q 'External_FW'" 5

run_test "SIEM_FW running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-SIEM_FW' --format '{{.Names}}' | grep -q 'SIEM_FW'" 5

run_test "Proxy_WAF running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Proxy_WAF' --format '{{.Names}}' | grep -q 'Proxy_WAF'" 5

run_test "Database running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Database' --format '{{.Names}}' | grep -q 'Database'" 5

run_test "DMZ IDS running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-DMZ_IDS' --format '{{.Names}}' | grep -q 'clab-MaJuVi-DMZ_IDS$'" 5

run_test "Internal IDS running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Internal_IDS' --format '{{.Names}}' | grep -q 'clab-MaJuVi-Internal_IDS$'" 5

run_test "Elasticsearch running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-elasticsearch' --format '{{.Names}}' | grep -q 'elasticsearch'" 5

run_test "Logstash running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-logstash' --format '{{.Names}}' | grep -q 'logstash'" 5

run_test "Kibana running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-kibana' --format '{{.Names}}' | grep -q 'kibana'" 5

run_test "Attacker running" \
    "sudo docker ps --filter 'name=clab-MaJuVi-Attacker' --format '{{.Names}}' | grep -q 'Attacker'" 5

# =========================
# SECTION 2: Network Connectivity Tests
# =========================
echo ""
echo -e "${BOLD}${MAGENTA}═══ SECTION 2: Network Connectivity Tests ═══${ENDCOLOR}"
echo ""

run_test "Internal_Client1 → Internal_FW" \
    "sudo docker exec clab-MaJuVi-Internal_Client1 ping -c 2 -W 2 192.168.10.1 >/dev/null 2>&1" 8

run_test "Internal_Client1 → internet" \
    "sudo docker exec clab-MaJuVi-Internal_Client1 ping -c 2 -W 2 internet >/dev/null 2>&1" 8

run_test "Internal_Client1 → Webserver" \
    "sudo docker exec clab-MaJuVi-Internal_Client1 ping -c 2 -W 2 10.0.2.30 >/dev/null 2>&1" 8

run_test "Internal_Client2 → Webserver" \
    "sudo docker exec clab-MaJuVi-Internal_Client2 ping -c 2 -W 2 10.0.2.30 >/dev/null 2>&1" 8

run_test "Webserver → Database" \
    "sudo docker exec clab-MaJuVi-Flask_Webserver ping -c 2 -W 2 10.0.2.70 >/dev/null 2>&1" 8

run_test "Proxy → Database" \
    "sudo docker exec clab-MaJuVi-Proxy_WAF ping -c 2 -W 2 10.0.2.10 >/dev/null 2>&1" 8
    
run_test "Attacker → Internet Router" \
    "sudo docker exec clab-MaJuVi-Attacker ping -c 2 -W 2 200.168.1.1 >/dev/null 2>&1" 8

run_test "Admin_PC → Kibana (HTTP)" \
    "sudo docker exec clab-MaJuVi-Admin_PC timeout 5 curl -s http://10.0.3.18:5601/api/status 2>/dev/null | grep -q 'name'" 10

run_test "Admin_PC → Elasticsearch (HTTP)" \
    "sudo docker exec clab-MaJuVi-Admin_PC timeout 5 curl -s http://10.0.3.14:9200 2>/dev/null | grep -q 'tagline'" 10

# =========================
# SECTION 3: Firewall Rule Tests
# =========================
echo ""
echo -e "${BOLD}${MAGENTA}═══ SECTION 3: Firewall Rule Tests ═══${ENDCOLOR}"
echo ""

run_test "Internal → Webserver Port 80 (ALLOW)" \
    "sudo docker exec clab-MaJuVi-Internal_Client1 curl -s -m 5 http://10.0.2.30 2>/dev/null | grep -q 'Login'" 8

run_test "Internet → Webserver Port 80 (ALLOW)" \
    "sudo docker exec clab-MaJuVi-Attacker curl -s -m 5 http://172.168.3.5 2>/dev/null | grep -q 'Login'" 8

run_test "DMZ → Internal BLOCKED" \
    "!  sudo docker exec clab-MaJuVi-Proxy_WAF timeout 3 ping -c 1 -W 2 192.168.10.10 >/dev/null 2>&1" 8

run_test "Internet → Internal BLOCKED" \
    "! sudo docker exec clab-MaJuVi-Attacker timeout 3 ping -c 1 -W 2 192.168.10.10 >/dev/null 2>&1" 8

run_test "Internal → Internet (ALLOW)" \
    "sudo docker exec clab-MaJuVi-Internal_Client1 ping -c 2 -W 3 172.168.2.1 >/dev/null 2>&1" 10

run_test "NAT Configuration (External FW)" \
    "sudo docker exec clab-MaJuVi-External_FW iptables -t nat -L -n | grep -q 'DNAT'" 5

# =========================
# SECTION 4: Service Tests
# =========================
echo ""
echo -e "${BOLD}${MAGENTA}═══ SECTION 4: Service Tests ═══${ENDCOLOR}"
echo ""

run_test "Webserver HTTP responding" \
    "curl -s -m 5 http://localhost:8181 2>/dev/null | grep -q 'Login'" 8

run_test "Database PostgreSQL responding" \
    "sudo docker exec clab-MaJuVi-Database pg_isready -U admin_use >/dev/null 2>&1" 5

run_test "Elasticsearch API responding" \
    "curl -s -m 5 http://localhost:9200/_cluster/health 2>/dev/null | grep -q 'cluster_name'" 8

run_test "Kibana Web UI responding" \
    "curl -s -m 5 http://localhost:5601/api/status 2>/dev/null | grep -q 'available'" 8

run_test "Logstash beat port open" \
    "sudo docker exec clab-MaJuVi-logstash timeout 3 sh -c 'echo > /dev/tcp/127.0.0.1/5044' 2>/dev/null" 6

# =========================
# SECTION 5: SIEM & Logging Tests
# =========================
echo ""
echo -e "${BOLD}${MAGENTA}═══ SECTION 5: SIEM & Logging Tests ═══${ENDCOLOR}"
echo ""

run_test "Filebeat running (Internal FW)" \
    "sudo docker exec clab-MaJuVi-Internal_FW pgrep -x filebeat >/dev/null 2>&1" 5

run_test "Filebeat running (External FW)" \
    "sudo docker exec clab-MaJuVi-External_FW pgrep -x filebeat >/dev/null 2>&1" 5

run_test "Filebeat running (DMZ IDS)" \
    "sudo docker exec clab-MaJuVi-DMZ_IDS pgrep -x filebeat >/dev/null 2>&1" 5

run_test "Filebeat running (Internal IDS)" \
    "sudo docker exec clab-MaJuVi-Internal_IDS pgrep -x filebeat >/dev/null 2>&1" 5

run_test "ulogd2 running (Internal FW)" \
    "sudo docker exec clab-MaJuVi-Internal_FW pgrep -x ulogd >/dev/null 2>&1" 5

run_test "ulogd2 running (External FW)" \
    "sudo docker exec clab-MaJuVi-External_FW pgrep -x ulogd >/dev/null 2>&1" 5

run_test "Suricata running (DMZ IDS)" \
    "sudo docker exec clab-MaJuVi-DMZ_IDS pgrep -x Suricata-Main >/dev/null 2>&1" 5

run_test "Suricata running (Internal IDS)" \
    "sudo docker exec clab-MaJuVi-Internal_IDS pgrep -x Suricata-Main >/dev/null 2>&1" 5

run_test "Logstash → Elasticsearch connection" \
    "sudo docker exec clab-MaJuVi-logstash timeout 5 sh -c 'curl -s http://10.0.3.26:9200 >/dev/null 2>&1'" 8

# =========================
# SECTION 6: Security Tests
# =========================
echo ""
echo -e "${BOLD}${MAGENTA}═══ SECTION 6: Security Tests ═══${ENDCOLOR}"
echo ""

run_test "WAF/ModSecurity active" \
    "sudo docker exec clab-MaJuVi-Proxy_WAF nginx -V 2>&1 | grep -q 'modsecurity'" 5

run_test "IP Forwarding enabled (Firewalls)" \
    "sudo docker exec clab-MaJuVi-Internal_FW cat /proc/sys/net/ipv4/ip_forward | grep -q '1'" 5

run_test "Default DROP policy (Internal FW)" \
    "sudo docker exec clab-MaJuVi-Internal_FW iptables -L -n | grep -E 'Chain (INPUT|FORWARD)' -A 1 | grep -q 'DROP'" 5

run_test "Default DROP policy (External FW)" \
    "sudo docker exec clab-MaJuVi-External_FW iptables -L -n | grep -E 'Chain (INPUT|FORWARD)' -A 1 | grep -q 'DROP'" 5

run_test "SIEM_FW restrictive rules" \
    "sudo docker exec clab-MaJuVi-SIEM_FW iptables -L FORWARD -n | grep -q 'DROP'" 5

# =========================
# Final Summary
# =========================
echo ""
echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${ENDCOLOR}"
echo -e "${BOLD}${CYAN}║                      Test Summary                                  ║${ENDCOLOR}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${ENDCOLOR}"
echo ""
echo -e "${BOLD}Total Tests:${ENDCOLOR}    $TOTAL_TESTS"
echo -e "${GREEN}${BOLD}Passed:${ENDCOLOR}         $PASSED_TESTS${ENDCOLOR}"
echo -e "${RED}${BOLD}Failed:${ENDCOLOR}         $FAILED_TESTS${ENDCOLOR}"
echo -e "${MAGENTA}${BOLD}Skipped:${ENDCOLOR}        $SKIPPED_TESTS${ENDCOLOR}"
echo ""

# Calculate pass rate
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
else
    PASS_RATE=0
fi

# Progress bar
echo -ne "${BOLD}Progress: ${ENDCOLOR}["
FILLED=$(( PASSED_TESTS * 50 / TOTAL_TESTS ))
EMPTY=$(( 50 - FILLED ))
printf "${GREEN}%0.s█${ENDCOLOR}" $(seq 1 $FILLED)
printf "${RED}%0.s░${ENDCOLOR}" $(seq 1 $EMPTY)
echo "] ${PASS_RATE}%"
echo ""

# Failed tests details
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}${BOLD}Failed Tests Details:${ENDCOLOR}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${ENDCOLOR}"
    
    for ((i=0; i<${#FAILED_TEST_NAMES[@]}; i++)); do
        echo -e "${RED}✗ ${FAILED_TEST_NAMES[$i]}${ENDCOLOR}"
        echo -e "${YELLOW}  ${FAILED_TEST_DETAILS[$i]}${ENDCOLOR}"
        echo ""
    done
fi

# Overall result
echo ""
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗${ENDCOLOR}"
    echo -e "${GREEN}${BOLD}║   ALL TESTS PASSED SUCCESSFULLY!       ║${ENDCOLOR}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${ENDCOLOR}"
    exit 0
else
    echo -e "${YELLOW}${BOLD}╔════════════════════════════════════════╗${ENDCOLOR}"
    echo -e "${YELLOW}${BOLD}║     SOME TESTS FAILED                  ║${ENDCOLOR}"
    echo -e "${YELLOW}${BOLD}║  Pass Rate: ${PASS_RATE}%              ║${ENDCOLOR}"
    echo -e "${YELLOW}${BOLD}╚════════════════════════════════════════╝${ENDCOLOR}"
    exit 1
fi
