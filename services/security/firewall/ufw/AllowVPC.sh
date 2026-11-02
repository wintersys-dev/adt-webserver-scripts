
export HOME="`/bin/cat /home/homedir.dat`"

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"

if ( [ "`/usr/sbin/ufw status | /bin/grep "${SSH_PORT}.*ALLOW.*${VPC_IP_RANGE}"`" = "" ] )
then
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port ${SSH_PORT}
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port 443
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port 80
  updated="1"
fi

