

if ( [ ! -f ${HOME}/runtime/IP_FORWARDING_ENABLED ] )
then
  /bin/echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  /usr/sbin/sysctl -p
  /bin/touch ${HOME}/runtime/IP_FORWARDING_ENABLED 
fi



if ( [ ! -d /etc/wireguard/server ] )
then
        /bin/mkdir -p /etc/wireguard/server
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wireguard-config" "wireguard-config/*" "${HOME}/runtime/authenticator"
#/bin/cp ${HOME}/runtime/authenticator/qrcode/*  /etc/wireguard/freshqrcodes
#/bin/cp ${HOME}/runtime/authenticator/client/* /etc/wireguard
/bin/cp ${HOME}/runtime/authenticator/server/* /etc/wireguard

#ip="`${HOME}/utilities/processing/GetPublicIP.sh`"
#/bin/sed -i "s/XXXXSERVER_PUBLIC_IPXXXX/${ip}/" /etc/wireguard/wg0.conf

modified="`/usr/bin/stat -c %Y /etc/wireguard/server`"
if ( [ "`/usr/bin/expr ${modified} - ${now}`" -lt "90" ] )
then
  is_modified="1"
fi

if ( [ "${is_modified}" = "1" ] )
then
  ${HOME}/utilities/processing/RunServiceCommand.sh wg-quick@wg0 stop
  ${HOME}/utilities/processing/RunServiceCommand.sh wg-quick@wg0 start
fi


