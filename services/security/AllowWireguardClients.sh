#set -x

if ( [ ! -f ${HOME}/runtime/IP_FORWARDING_ENABLED ] )
then
        /bin/echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        /usr/sbin/sysctl -p
        /bin/touch ${HOME}/runtime/IP_FORWARDING_ENABLED 
fi

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
WG_PORT="`/usr/bin/expr ${SSH_PORT} + 1`"

if ( [ ! -f /etc/wireguard/postup.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/postup.sh /etc/wireguard/postup.sh
fi

if ( [ ! -f /etc/wireguard/postdown.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/postdown.sh /etc/wireguard/postdown.sh
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wireguard-config" "wireguard-config/*" "${HOME}/runtime/authenticator"
if ( ( [ -f ${HOME}/runtime/authenticator/server/wg0.conf ] && [ -f /etc/wireguard/wg0.conf ] ) || [ ! -f /etc/wireguard/wg0.conf ] )
then
        if ( [ "`/usr/bin/diff ${HOME}/runtime/authenticator/server/wg0.conf /etc/wireguard/wg0.conf`" != "" ] || [ ! -f /etc/wireguard/wg0.conf ] )
        then
                /bin/mv ${HOME}/runtime/authenticator/server/wg0.conf /etc/wireguard/wg0.conf
        fi
fi

now="`/usr/bin/date +%s`"
is_modified="0"
modified="`/usr/bin/stat -c %Y /etc/wireguard`"
if ( [ "`/usr/bin/expr ${now} - ${modified}`" -lt "90" ] )
then
        is_modified="1"
fi

if ( [ "${is_modified}" = "1" ] )
then
        ${HOME}/utilities/processing/RunServiceCommand.sh wg-quick@wg0 stop
        ${HOME}/utilities/processing/RunServiceCommand.sh wg-quick@wg0 start
fi


