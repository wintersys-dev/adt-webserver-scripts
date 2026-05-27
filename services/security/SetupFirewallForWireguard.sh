#!/bin/sh

export HOME="`/bin/cat /home/homedir.dat`"
SERVER_USER_PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSERPASSWORD'`"
AUTHENTICATOR_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHENTICATORTYPE'`"
BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"

firewall=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $2}'`" = "ufw" ] )
then
        firewall="ufw"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $2}'`" = "iptables" ] )
then
        firewall="iptables"
fi

reverse_proxy_ips=""
if ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] && [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
then
        reverse_proxy_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "reverseproxypublicips/*"`"
fi

updated="0"

if ( [ "${firewall}" = "ufw" ] )
then
        if ( [ "${reverse_proxy_ips}" != "" ] )
        then
                for ip in ${reverse_proxy_ips}
                do
                        /bin/echo ${SERVER_USER_PASSWORD} | /usr/bin/sudo -S -E /usr/sbin/ufw allow from ${ip}/32 to any port 443
                done
        fi
        updated="1"
elif ( [ "${firewall}" = "iptables" ] )
then
        if ( [ "${reverse_proxy_ips}" != "" ] )
        then
                for ip in ${reverse_proxy_ips}
                do
                        /usr/sbin/iptables -A INPUT -s ${ip}/32 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
                done
        fi
        updated="1"

fi

if ( [ "${updated}" = "1" ] )
then
        if ( [ "${firewall}" = "ufw" ] )
        then
                /usr/sbin/ufw -f enable
                /usr/sbin/ufw reload
                if ( [ "$?" = "0" ] )
                then
                        /bin/touch ${HOME}/runtime/FIREWALL_INITIALISED_FOR_WIREGUARD
                fi

        elif ( [ "${firewall}" = "iptables" ] )
        then
                /usr/sbin/iptables-save > /etc/iptables/rules.v4
                if ( [ "$?" = "0" ] )
                then
                        /bin/touch ${HOME}/runtime/FIREWALL_INITIALISED_FOR_WIREGUARD
                fi
        fi

        if ( [ "${BUILDOS}" = "ubuntu" ] )
        then
                ${HOME}/utilities/processing/RunServiceCommand.sh systemd-networkd.service restart
        elif ( [ "${BUILDOS}" = "debian" ] )
        then
                ${HOME}/utilities/processing/RunServiceCommand.sh networking restart
        fi
fi
