# Create client config
/bin/echo "[Interface]
  PrivateKey = ${client_private_key}
  Address = 10.0.0.${client_no}/32
  MTU = 1380
  DNS = 1.1.1.1, 1.0.0.1 

[Peer]
  PublicKey = ${server_public_key}
  PresharedKey = ${preshared_key}
  Endpoint = ${server_ip}:${wireguard_port}
  AllowedIPs =  10.0.0.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`/32,10.0.0.0/8
  PersistentKeepalive = 25" >> ${HOME}/runtime/wire-guard/client/${email_address}/client.conf
