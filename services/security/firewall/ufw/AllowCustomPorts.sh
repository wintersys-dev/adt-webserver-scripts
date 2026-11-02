set -x

HOME="`/bin/cat /home/homedir.dat`"

NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"

openness=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $3}'`" = "limit" ] )
then
        openness="limit"
else
        openness="allow"
fi

if ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] )
then
        openness="allow"
fi

updated="0"
if ( [ -f ${HOME}/runtime/firewall.dat ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] )
        then
                ports="`/bin/grep "^REVERSEPROXYPORTS" ${HOME}/runtime/firewall.dat | /bin/sed 's/REVERSEPROXYPORTS://g'`"
        elif ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] )
        then
                ports="`/bin/grep "^WEBSERVERPORTS" ${HOME}/runtime/firewall.dat | /bin/sed 's/WEBSERVERPORTS://g'`"
        elif ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                ports="`/bin/grep "^AUTHENTICATORPORTS" ${HOME}/runtime/firewall.dat | /bin/sed 's/AUTHENTICATORPORTS://g'`"
        fi

        for port_token in ${ports}
        do
                delete="no"
                if ( [ "`/bin/echo ${port_token} | /bin/grep 'ipv4'`" != "" ] )
                then
                        port="`/bin/echo ${port_token} | /usr/bin/awk -F'|' '{print $1}'`"
                        ip_address="`/bin/echo ${port_token} | /usr/bin/awk -F'|' '{print $4}'`"

                        if ( [ "`/bin/echo ${port_token} | /usr/bin/awk -F'|' '{print $6}'`" = "DELETE" ] )
                        then
                                delete="yes"
                        fi
                fi

                if ( [ "${ip_address}" = "cloudflare" ] )
                then
                        for ip in `/usr/bin/curl https://www.cloudflare.com/ips-v4/#`
                        do
                                if ( [ "`/usr/sbin/ufw status | /bin/grep "ALLOW.*${ip}"`" = "" ] )
                                then
                                        /usr/sbin/ufw ${openness} from ${ip} to any port 443
                                        updated="1"
                                fi
                        done
                elif ( [ "`/usr/sbin/ufw status | /bin/grep "${port}" | /bin/grep "ALLOW" | /bin/grep "${ip_address}"`" = "" ] && [ "${delete}" != "yes" ] )
                then
                        /usr/sbin/ufw ${openness} from ${ip_address} to any port ${port}
                        updated="1"
                else
                        if ( [ "`/usr/sbin/ufw status | /bin/grep "${port}" | /bin/grep "ALLOW" | /bin/grep "${ip_address}"`" != "" ] && [ "${delete}" = "yes" ] )
                        then
                                /usr/bin/yes | /usr/sbin/ufw delete `/usr/sbin/ufw status numbered | /bin/grep ${port} | /usr/bin/awk -F"[\[\]]" '{print $2}' | /bin/sed 's/ //g'`
                                updated="1"
                        fi
                fi
        done
fi

# Exit with status 10 if updated, otherwise exit with 0
if [ "$updated" -eq 1 ]
then
        exit 10
else
        exit 0
fi

