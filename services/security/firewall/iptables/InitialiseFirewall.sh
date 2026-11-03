
HOME="`/bin/cat /home/homedir.dat`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"

initialised="0"

if ( [ ! -f ${HOME}/runtime/FIREWALL-INITIALISED ] )
then
	if ( [ "${firewall}" = "iptables" ] && [ ! -f ${HOME}/runtime/FIREWALL-INITIALISED ] )
        then
                /usr/sbin/iptables -P INPUT DROP
                /usr/sbin/iptables -P FORWARD DROP
                /usr/sbin/iptables -P OUTPUT ACCEPT
                /usr/sbin/iptables -A INPUT -i lo -j ACCEPT
                /usr/sbin/iptables -A OUTPUT -o lo -j ACCEPT

                /usr/sbin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                /usr/sbin/iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
                /usr/sbin/iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
                /usr/sbin/iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

                /usr/sbin/ip6tables -P INPUT DROP
                /usr/sbin/ip6tables -P FORWARD DROP
                /usr/sbin/ip6tables -P OUTPUT ACCEPT
                /usr/sbin/ip6tables -A INPUT -i lo -j ACCEPT
                /usr/sbin/ip6tables -A OUTPUT -o lo -j ACCEPT

                VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
                ip_addresses="`/usr/sbin/iptables -L INPUT -n | /bin/grep "443$" | /bin/grep -v "${VPC_IP_RANGE}" | /bin/grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"`"
                for ip_address in ${ip_addresses}
                do
                        /usr/sbin/iptables -D INPUT -s ${ip_address} -p tcp --dport 443 -j ACCEPT
                done
				intialised="1"
                /bin/touch ${HOME}/runtime/FIREWALL-INITIALISED 
        fi
fi

# Exit with status 10 if updated, otherwise exit with 0
if [ "$initialised" -eq 1 ]
then
        exit 10
else
        exit 0
fi
