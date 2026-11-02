
export HOME="`/bin/cat /home/homedir.dat`"

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
AUTHENTICATOR_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHENTICATORTYPE'`"

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

# Exit with status 10 if updated, otherwise exit with 0
if [ "$updated" -eq 1 ]
then
        exit 10
else
        exit 0
fi

