set -x

HOME="`/bin/cat /home/homedir.dat`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"

limit="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $3}'`"
limit_burst=""
limit_burst="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $4}'`"
if ( [ "${limit}" = "" ] || [ "${limit_burst}" = "" ] )
then
	limited="off"
else
	if ( [ "${limit}" -eq "${limit}" 2>/dev/null ] && [ "${limit_burst}" -eq "${limit_burst}" 2>/dev/null ] )
	then
		limited="on"
	else
		limited="off"
	fi
fi
		
if ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] )
then
	limited="off"
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
            		if ( [ "`/usr/sbin/iptables --list-rules | /bin/grep "${ip}.*443.*ACCEPT"`" = "" ] )
            		then
						/usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
						if ( [ "${limited}" = "on" ] )
						then
							/usr/sbin/iptables -A INPUT -s ${ip} -p tcp --dport ${port} -m conntrack --ctstate NEW -m limit --limit 20/min --limit-burst 30 -j ACCEPT
							/usr/sbin/iptables -A INPUT -s ${ip} -p tcp --dport ${port} -m conntrack --ctstate NEW -j DROP
							/usr/sbin/iptables -A OUTPUT -s ${ip} -p tcp --sport ${port} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
                		elif ( [ "${limited}" = "off" ] )
						then
							/usr/sbin/iptables -I INPUT -s ${ip} -p tcp -m tcp --dport 443 -j ACCEPT
						fi
						updated="1"
                    fi
                done
            elif ( [ "`/usr/sbin/iptables --list-rules | /bin/grep "${ip_address}.${port}.*ACCEPT"`" = "" ] && [ "${delete}" != "yes" ] )
            then
				if ( [ "${limited}" = "on" ] )
				then
					/usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
					/usr/sbin/iptables -A INPUT -s ${ip_address} -p tcp --dport ${port} -m conntrack --ctstate NEW -m limit --limit ${limit}/min --limit-burst ${limit_burst} -j ACCEPT
					/usr/sbin/iptables -A INPUT -s ${ip_address} -p tcp --dport ${port} -m conntrack --ctstate NEW -j DROP
					/usr/sbin/iptables -A OUTPUT -s ${ip_address} -p tcp --sport ${port} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
				elif ( [ "${limited}" = "off" ] )
				then
                	/usr/sbin/iptables -A INPUT -s ${ip_address} -p tcp --dport ${port} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
                	/usr/sbin/iptables -A OUTPUT -s ${ip_address} -p tcp --sport ${port} -m conntrack --ctstate ESTABLISHED -j ACCEPT
                fi    
				updated="1"
            else
            	if ( [ "`/usr/sbin/iptables --list-rules | /bin/grep "${ip_address}.${port}.*ACCEPT"`" != "" ] && [ "${delete}" = "yes" ] )
            	then
            		if ( [ "${limited}" = "on" ] )
					then
						/usr/sbin/iptables -D INPUT -s ${ip_address} -p tcp --dport ${port} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
                		/usr/sbin/iptables -D OUTPUT -s ${ip_address} -p tcp --sport ${port} -m conntrack --ctstate ESTABLISHED -j ACCEPT
                    elif ( [ "${limited}" = "off" ] )
					then      
						/usr/sbin/iptables -D INPUT -s ${ip_address} -p tcp -m tcp --dport ${port} -j ACCEPT
					fi
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
