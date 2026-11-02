if ( [ "`/usr/bin/hostname | /bin/grep '^rp\-'`" = "" ] && [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
then
        wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

                if ( [ "`/usr/sbin/ufw status | /bin/grep  "${wireguard_port}.*ALLOW.*"`" = "" ] )
                then
                        /usr/sbin/ufw allow ${wireguard_port}
                        /bin/sleep 2
                        updated="1"
                fi
fi

