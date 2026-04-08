<div align="center">

# DMZ – Enterprise Network Security Lab

**Fully containerized enterprise network environment with DMZ architecture, multi-tier firewalls, Suricata IDS, and ELK SIEM stack — automated with Containerlab.**

[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Docker](https://img.shields.io/badge/Docker-24.0%2B-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Containerlab](https://img.shields.io/badge/Containerlab-0.48%2B-FF6600?style=for-the-badge&logo=linux-containers&logoColor=white)](https://containerlab.dev/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Elasticsearch](https://img.shields.io/badge/Elastic-9.2.1-005571?style=for-the-badge&logo=elasticsearch&logoColor=white)](https://www.elastic.co/)
[![Suricata](https://img.shields.io/badge/Suricata-IDS-E5311A?style=for-the-badge&logo=suricata&logoColor=white)](https://suricata.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](./LICENSE)

---

</div>

> **Originally a university project** — Initially built as a graded assignment for the university.  
> **Actively maintained** — Continued development driven by personal interest in security research and hands-on learning.


## Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Usage](#-usage)
- [Network Topology](#-network-topology)
- [Components](#-components)
- [Attack Scenarios](#-attack-scenarios)
- [Testing](#-testing)
- [Project Structure](#-project-structure)
- [License](#-license)

---

## Overview

**DMZ** is a one-command deployment tool that creates a complete enterprise network environment using [Containerlab](https://containerlab.dev/). It simulates a realistic corporate infrastructure across four network segments:

| Segment | Subnet | Description |
|---------|--------|-------------|
| **Internal** | `192.168.10.0/24` | Corporate LAN with client machines |
| **DMZ** | `10.0.2.0/24` | Demilitarized zone with web server, WAF & database |
| **SIEM** | `10.0.3.0/30` | Security monitoring with full ELK stack |
| **Internet / Edge** | `200.168.1.0/24` | Simulated internet with attacker node |

Perfect for:
- Security training and education
- Penetration testing practice
- IDS/IPS rule development
- SIEM log analysis and dashboarding
- Network forensics

---

## Architecture

```
                        ┌─────────────┐
                        │  Attacker   │
                        │ (Kali Linux)│
                        └──────┬──────┘
                               │ 200.168.1.0/24
                        ┌──────┴──────┐
                        │   Router    │
                        │  Internet   │
                        └──────┬──────┘
                               │ 172.168.2.0/30
                        ┌──────┴──────┐
                        │   Router    │
                        │    Edge     │
                        └──────┬──────┘
                               │ 172.168.3.0/30
                    ┌──────────┴──────────┐
                    │    External FW      │
                    │ (iptables + ulogd2) │
                    └───┬─────────┬───────┘
                        │         │
          ┌─────────────┴─┐     ┌─┴──────────────┐
          │   DMZ Zone    │     │  Internal Zone  │
          │  10.0.2.0/24  │     │ 192.168.10.0/24 │
          │               │     │                 │
          │ ┌───────────┐ │     │ ┌─────────────┐ │
          │ │Proxy / WAF│ │     │ │Internal FW  │ │
          │ │(ModSec)   │ │     │ │(iptables)   │ │
          │ └─────┬─────┘ │     │ └──────┬──────┘ │
          │ ┌─────┴─────┐ │     │ ┌──────┴──────┐ │
          │ │ Flask Web │ │     │ │  Switch     │ │
          │ └─────┬─────┘ │     │ │ (FRR Bridge)│ │
          │ ┌─────┴─────┐ │     │ └──┬──────┬───┘ │
          │ │ PostgreSQL│ │     │    │      │     │
          │ └───────────┘ │     │ Client1 Client2 │
          │ ┌───────────┐ │     │ ┌─────────────┐ │
          │ │ DMZ IDS   │ │     │ │Internal IDS │ │
          │ │(Suricata) │ │     │ │(Suricata)   │ │
          │ └───────────┘ │     │ └─────────────┘ │
          └───────────────┘     └─────────────────┘
                        │         │
                    ┌───┴─────────┴───┐
                    │    SIEM FW      │
                    │  10.0.3.0/30    │
                    └───┬───┬───┬─────┘
                        │   │   │
              ┌─────────┘   │   └─────────┐
        ┌─────┴─────┐  ┌────┴────┐ ┌──────┴──────┐
        │ Logstash  │  │Elastic- │ │   Kibana    │
        │  :5044    │  │search   │ │   :5601     │
        │           │  │ :9200   │ │             │
        └───────────┘  └─────────┘ └─────────────┘
```

---

## Features

### Network Security
- **Multi-tier firewall architecture** — Internal FW, External FW, SIEM FW (iptables + NFLOG)
- **Intrusion detection** — Suricata IDS in DMZ and internal network (traffic mirroring via bridge)
- **Web Application Firewall** — OWASP ModSecurity CRS with NGINX reverse proxy
- **Network segmentation** — Strict isolation between Internet, DMZ, internal, and SIEM zones

### Application Stack
- **Vulnerable web application** — Flask + PostgreSQL with login system and role-based access
- **Reverse proxy** with SSL/TLS termination
- **Database** — PostgreSQL 16 with sample data (users, reports, access control)

### Security Monitoring (SIEM)
- **Elasticsearch 9.2.1** — Centralized log storage and search
- **Logstash** — Log ingestion with separate pipelines for firewall and IDS logs
- **Kibana** — Visualization, dashboards, and analysis
- **Filebeat** — Log shipping from firewalls and IDS nodes
- **ulogd2** — Firewall logging via NFLOG

### Automation
- **One-command deployment** — Entire environment with a single command
- **Modular design** — Separate scripts per component
- **Automated cleanup** — Clean teardown of the entire lab
- **Pre-configured attack scenarios** — SQL Injection, DoS, XSS & Directory Traversal

---

## Prerequisites

| Software | Version | Description |
|----------|---------|-------------|
| **Linux** | — | Tested on Ubuntu / Debian |
| **Docker** | 24.0+ | Container runtime |
| **Containerlab** | 0.48+ | Lab orchestration |
| **sudo** | — | Root privileges for network operations |

### Install Dependencies

```bash
bash install_dependencies.sh
```

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Trigger-45DMZ.git
cd DMZ

# Install dependencies (one-time)
bash install_dependencies.sh

# Full deployment
sudo bash main.sh
```

After deployment, the following services are accessible:

| Service | URL | Description |
|---------|-----|-------------|
| **Kibana** | `http://localhost:5601` | SIEM Dashboard |
| **Elasticsearch** | `http://localhost:9200` | Search API |
| **Web App (WAF)** | `http://localhost:8080` | Web application via ModSecurity |

---

## Usage

```bash
# Full deployment (default)
sudo bash main.sh

# Deploy topology only (no configuration)
sudo bash main.sh --topology-only

# Deploy without prior cleanup
sudo bash main.sh --skip-cleanup

# Destroy lab (stop containers)
sudo bash main.sh --destroy

# Destroy lab + remove Docker images
sudo bash main.sh --purge
```

### Inspect Topology

```bash
sudo containerlab inspect --topo topology/DMZ.yml
```

---

## Network Topology

### Subnets

| Subnet | CIDR | Purpose |
|--------|------|---------|
| Internal | `192.168.10.0/24` | Clients, Internal Switch |
| Between FW | `192.168.20.0/24` | Internal FW ↔ External FW |
| DMZ | `10.0.2.0/24` | WAF, Web Server, DB, IDS |
| SIEM | `10.0.3.0/24` | ELK Stack, SIEM FW, Admin PC |
| Edge 1 | `172.168.2.0/30` | Router Internet ↔ Router Edge |
| Edge 2 | `172.168.3.0/30` | Router Edge ↔ External FW |
| Internet | `200.168.1.0/24` | Attacker |

### Nodes (19 Containers)

| Node | Image | Role |
|------|-------|------|
| `Internal_Client1` | Alpine | Internal client |
| `Internal_Client2` | Alpine | Internal client |
| `Internal_Switch` | FRR | Bridge with traffic mirroring |
| `Internal_FW` | Ubuntu | Firewall (iptables + ulogd2 + Filebeat) |
| `Internal_IDS` | Suricata | IDS for internal network |
| `DMZ_Switch` | FRR | Bridge with traffic mirroring |
| `Proxy_WAF` | ModSecurity | OWASP WAF + NGINX reverse proxy |
| `Flask_Webserver` | NGINX | Flask web application |
| `Database` | PostgreSQL 16 | Database server |
| `DMZ_IDS` | Suricata | IDS for DMZ |
| `External_FW` | Ubuntu | External firewall with NAT |
| `SIEM_FW` | Ubuntu | SIEM firewall (restrictive) |
| `logstash` | Elastic 9.2.1 | Log pipeline |
| `elasticsearch` | Elastic 9.2.1 | Log storage & search |
| `kibana` | Elastic 9.2.1 | Visualization |
| `siem_pc` | Alpine | Admin access to SIEM |
| `router-edge` | FRR | Edge router |
| `router-internet` | FRR | Internet router |
| `Attacker` | Kali Linux | Attacker node |

---

## Components

### Firewalls

- **Internal FW** — Allows internal traffic to web server (port 80), blocks DMZ → Internal, logging via NFLOG + ulogd2 + Filebeat
- **External FW** — DNAT for incoming web traffic, MASQUERADE for outgoing, logging via NFLOG + ulogd2 + Filebeat
- **SIEM FW** — Restrictive rules: only defined connections allowed (Filebeat → Logstash, Admin → Kibana, etc.), everything else is DROPped

### IDS (Suricata)

- Rules for: SQL Injection, SSH Brute Force, Port Scanning, ICMP Flood
- Logs: `/var/log/suricata/eve.json` → Filebeat → Logstash → Elasticsearch
- Separate index per IDS: `suricata-dmz-*`, `suricata-internal-*`

### SIEM (ELK Stack)

- **Logstash pipelines**: `firewall.conf` (NFLOG parsing), `ids.conf` (Suricata eve.json)
- **Elasticsearch indices**: `firewall-internal-*`, `firewall-external-*`, `suricata-dmz-*`, `suricata-internal-*`
- **Kibana**: Accessible at `http://localhost:5601`

### Web Application

- Flask app with login system (admin/user roles)
- PostgreSQL backend with sample data (users, reports, access control)
- Protected by OWASP ModSecurity CRS (WAF) and NGINX reverse proxy

---

## Attack Scenarios

Pre-configured scripts in the `attacks/` directory:

| Script | Attack Type | Executed From |
|--------|-------------|---------------|
| `attack_sql.sh` | SQL Injection against login form | Attacker container |
| `attack_dos.sh` | DoS (ICMP Flood, SYN Flood, HTTP/S Flood) | Attacker container |
| `attack_xss_path.sh` | XSS & Directory Traversal | Internal_Client2 |

### Example: Run SQL Injection

```bash
# Deploy the attack script
bash attacks/attack_sql.sh

# Execute inside the Attacker container
sudo docker exec -it clab-MaJuVi-Attacker bash /root/sql_attack_simple.sh
```

### Example: Run DoS Attack

```bash
bash attacks/attack_dos.sh
sudo docker exec -it clab-MaJuVi-Attacker python3 /root/dos.py
```

All attacks generate logs that are ingested through the SIEM pipeline into Elasticsearch and can be visualized in Kibana.

---

## Testing

```bash
bash scripts/tests/test-connectivity.sh
```

The test suite verifies:
- Network connectivity between all segments
- Service availability (Elasticsearch, Kibana, Logstash)
- Running processes (Filebeat, Suricata, ulogd2)
- Firewall rules (default DROP policies)
- WAF functionality (ModSecurity active)

---

## Project Structure

```
DMZ/
├── main.sh                       # Main entry point
├── install_dependencies.sh       # Dependency installer
├── attacks/                      # Pre-configured attack scripts
│   ├── attack_sql.sh             #   SQL Injection
│   ├── attack_dos.sh             #   Denial of Service
│   └── attack_xss_path.sh        #   XSS & Directory Traversal
├── config/                       # Configuration files
│   ├── variables.sh              #   Central variables (IPs, images, subnets)
│   ├── logstash/                 #   Logstash pipeline configurations
│   ├── suricata/                 #   Suricata rules & configuration
│   └── webserver-details/        #   Flask app (app.py)
├── topology/                     # Containerlab topology
│   └── topology-generator.sh     #   Generates the YAML topology
├── scripts/
│   ├── setup/                    # Setup & deployment
│   │   ├── 01-cleanup.sh         #   Clean up previous environments
│   │   ├── 02-docker-prep.sh     #   Prepare Docker images
│   │   └── 03-deploy-topology.sh #   Deploy Containerlab topology
│   ├── configure/                # Component configuration
│   │   ├── firewalls/            #   Internal FW, External FW, SIEM FW
│   │   ├── dmz/                  #   Web server, Proxy/WAF, Database
│   │   ├── ids/                  #   Suricata IDS (DMZ + Internal)
│   │   ├── siem/                 #   ELK stack configuration
│   │   └── network/              #   Routers, switches, clients
│   ├── tests/                    # Connectivity & functional tests
│   └── lib/                      # Helper libraries (logging)
├── docs/                         # Documentation
│   └── diagramm.puml             #   PlantUML network diagram
└── LICENSE                       # MIT License
```

---

## License

This project is licensed under the [MIT License](LICENSE).
