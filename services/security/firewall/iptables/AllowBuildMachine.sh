export HOME="`/bin/cat /home/homedir.dat`"


BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"

updated="0"

if ( [ "`/usr/sbin/iptables --list-rules | /bin/grep "${BUILD_MACHINE_IP}.*${SSH_PORT}.*ACCEPT"`" = "" ] )
then
  /usr/sbin/iptables -A INPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --dport ${SSH_PORT} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
  /usr/sbin/iptables -A OUTPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --sport ${SSH_PORT} -m conntrack --ctstate ESTABLISHED -j ACCEPT
  /usr/sbin/iptables -A INPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
  /usr/sbin/iptables -A OUTPUT -s ${BUILD_MACHINE_IP}/32 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED -j ACCEPT  
  /usr/sbin/iptables -A INPUT -s ${BUILD_MACHINE_IP}/32 -p ICMP --icmp-type 8 -j ACCEPT
  updated="1"
fi

# Exit with status 10 if updated, otherwise exit with 0
if [ "$updated" -eq 1 ]
then
        exit 10
else
        exit 0
fi
