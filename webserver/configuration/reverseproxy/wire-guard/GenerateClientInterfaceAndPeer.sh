
if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key ] )
then
  client_private_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key`"
fi

if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/CLIENT_NO ] )
then
  client_no="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/CLIENT_NO`"
fi
                
if ( [ -f ${HOME}/runtime/wire-guard/server/server_public.key ] )
then
  server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"
fi
                
if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key ] )
then
  preshared_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key`"
fi

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
