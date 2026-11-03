export HOME="`/bin/cat /home/homedir.dat`"

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
updated="0"

if ( [ "`/usr/sbin/iptables --list-rules | /bin/grep "${VPC_IP_RANGE}.*${SSH_PORT}.*ACCEPT"`" = "" ] )
then
	/usr/sbin/iptables -A INPUT -s ${VPC_IP_RANGE} -p tcp --dport ${SSH_PORT} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	/usr/sbin/iptables -A INPUT -s ${VPC_IP_RANGE} -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	/usr/sbin/iptables -A INPUT -s ${VPC_IP_RANGE} -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	/usr/sbin/iptables -A INPUT -s ${VPC_IP_RANGE} -p ICMP --icmp-type 8 -j ACCEPT
	updated="1"
fi

# Exit with status 10 if updated, otherwise exit with 0
if [ "$updated" -eq 1 ]
then
        exit 10
else
        exit 0
fi
