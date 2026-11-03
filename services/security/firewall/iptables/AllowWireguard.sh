
export HOME="`/bin/cat /home/homedir.dat`"

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
AUTHENTICATOR_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHENTICATORTYPE'`"

updated="0"

if ( [ "`/usr/bin/hostname | /bin/grep '^rp\-'`" = "" ] && [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] )
then
	wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"
	if ( [ "`/usr/sbin/iptables --list-rules | /bin/grep ".*${wireguard_port}.*ACCEPT"`" = "" ] )
	then
		/usr/sbin/iptables -A INPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --dport ${wireguard_port} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
		/usr/sbin/iptables -A OUTPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --sport ${wireguard_port} -m conntrack --ctstate ESTABLISHED -j ACCEPT
		/usr/sbin/iptables -A INPUT -s ${BUILD_MACHINE_IP}/32 -p udp --dport ${wireguard_port} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
		/usr/sbin/iptables -A OUTPUT -s ${BUILD_MACHINE_IP}/32 -p udp --sport ${wireguard_port} -m conntrack --ctstate ESTABLISHED -j ACCEPT
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
