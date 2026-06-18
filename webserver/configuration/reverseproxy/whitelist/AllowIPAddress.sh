#set -x

ip_address="${1}"

VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
WEBSERVER_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSERVERCHOICE'`"

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator
fi

if ( [ "${WEBSERVER_CHOICE}" = "APACHE" ] )
then
        if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
        then
                /bin/echo "Require ip ${VPC_IP_RANGE}" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /bin/echo "Require ip 127.0.0.1" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
        fi
        /bin/echo "Require ip ${ip_address}" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
fi

if ( [ "${WEBSERVER_CHOICE}" = "NGINX" ] )
then
        if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
        then
                /bin/echo "allow ${VPC_IP_RANGE};" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /bin/echo "allow 127.0.0.1;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /bin/echo "deny all;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
        fi
        /bin/sed -i "1s/^/allow ${ip_address};\n/" ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
fi

if ( [ "${WEBSERVER_CHOICE}" = "LIGHTTPD" ] )
then
        if ( [ ! -f ${HOME}/runtime/LIGHTTPD_WHITELIST_PRIMED ] && [ -f ${HOME}/runtime/REVERSEPROXY_READY ] )
        then
                /bin/echo "111.111.111.111" > ${HOME}/runtime/authenticator/incoming_ipaddresses.dat
                /bin/touch ${HOME}/runtime/LIGHTTPD_WHITELIST_PRIMED
        fi
        
        if ( [ -f ${HOME}/runtime/authenticator/incoming_ipaddresses.dat ] && [ "`/bin/cat ${HOME}/runtime/authenticator/incoming_ipaddresses.dat`" != "" ] )
        then
                /bin/cat ${HOME}/runtime/authenticator/incoming_ipaddresses.dat > ${HOME}/runtime/authenticator/all_ips_whitelist.dat.$$
                /bin/cat ${HOME}/runtime/authenticator/processed_ipaddresses.dat >> ${HOME}/runtime/authenticator/all_ips_whitelist.dat.$$
                /usr/bin/awk '!seen[$0]++' ${HOME}/runtime/authenticator/all_ips_whitelist.dat.$$ > ${HOME}/runtime/authenticator/all_ips_whitelist.dat
                /bin/rm ${HOME}/runtime/authenticator/all_ips_whitelist.dat.$$
                ip_addresses="`/bin/cat ${HOME}/runtime/authenticator/all_ips_whitelist.dat`"
                ip_addresses="`/bin/echo ${ip_addresses} | /bin/sed 's/ /|/g'`"
                vpc="`/bin/echo ${VPC_IP_RANGE} | /usr/bin/cut -d. -f-3`\\."
                ip_addresses="${ip_addresses}|${vpc}|127.0.0.1"
                /bin/cp ${HOME}/webserver/configuration/reverseproxy/whitelist/allowed-ips.tmpl ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /bin/sed -i "s;XXXXIP_ADDRESSESXXXX;${ip_addresses};" ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /usr/bin/tac /etc/lighttpd/lighttpd.conf | /usr/bin/awk '!p && /##WHITE-LIST-MARKER/{print "##XXXXWHITE-LISTXXXX"; p=1} 1' | /usr/bin/tac > /etc/lighttpd/lighttpd.conf.$$
                /bin/sed -i '/#WHITE-LIST-MARKER/d' /etc/lighttpd/lighttpd.conf.$$
                /bin/sed -i -e "/##XXXXWHITE-LISTXXXX/{r ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat" -e 'd}' /etc/lighttpd/lighttpd.conf.$$
                /bin/mv /etc/lighttpd/lighttpd.conf.$$ /etc/lighttpd/lighttpd.conf
        fi
fi

