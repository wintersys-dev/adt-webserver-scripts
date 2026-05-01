

if ( [ ! -f ${HOME}/runtime/IP_FORWARDING_ENABLED ] )
then
  /bin/echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  /usr/sbin/sysctl -p
  /bin/touch ${HOME}/runtime/IP_FORWARDING_ENABLED 
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wireguard-config" "wireguard-config/*" "${HOME}/runtime/authenticator"
/bin/cp ${HOME}/runtime/authenticator/qrcode/*  /etc/wireguard/freshqrcodes
/bin/cp ${HOME}/runtime/authenticator/client/* /etc/wireguard
/bin/cp ${HOME}/runtime/authenticator/server/* /etc/wireguard

