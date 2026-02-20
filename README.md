# SUN_DMZ - Enterprise Network Security Lab

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)
![Containerlab](https://img.shields.io/badge/containerlab-0.48%2B-orange.svg)
![Docker](https://img.shields.io/badge/docker-24.0%2B-blue.svg)

A comprehensive, containerized enterprise network security lab environment featuring DMZ architecture, multiple firewalls, IDS/IPS systems, and a complete SIEM stack (Elasticsearch, Logstash, Kibana).

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Usage](#detailed-usage)
- [Network Topology](#network-topology)
- [Components](#components)
- [Attack Scenarios](#attack-scenarios)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

**SUN_DMZ** is an automated security lab deployment tool that creates a complete enterprise network environment using containerlab. It simulates a realistic corporate infrastructure with:

- **Internal Network** (192.168.10.0/24)
- **DMZ Network** (10.0.2.0/24)
- **SIEM Network** (10.0.3.0/24)
- **Internet/Edge** (200.168.1.0/24)

Perfect for:
- Security training and education
- Penetration testing practice
- IDS/IPS rule development
- SIEM log analysis
- Network forensics

---

## ✨ Features

### Network Security
- **Multi-tier Firewall Architecture** (Internal, External, SIEM)
- **IDS/IPS** with Suricata (DMZ + Internal)
- **Web Application Firewall** (ModSecurity)
- **Network Segmentation** with VLANs

### Application Stack
- **Vulnerable Web Application** (Flask + PostgreSQL)
- **Reverse Proxy** with SSL/TLS
- **Database Server** with sample data

### Security Monitoring
- **SIEM Stack** (ELK: Elasticsearch 9.2.1, Logstash, Kibana)
- **Centralized Logging** (Firewall + IDS logs)
- **Real-time Alerting**
- **Traffic Analysis**

### Automation
- **One-command Deployment**
- **Modular Configuration**
- **Automated Cleanup**
- **Pre-configured Attack Scenarios**

