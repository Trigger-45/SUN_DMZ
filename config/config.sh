openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout ./webserver-details/server.key \
  -out ./webserver-details/server.crt \
  -subj "/CN=example.local"
chmod 0777 ./webserver-details/server.crt
chmod 0777 ./webserver-details/server.key