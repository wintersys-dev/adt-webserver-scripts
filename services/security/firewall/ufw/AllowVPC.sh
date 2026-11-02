if ( [ "`/usr/sbin/ufw status | /bin/grep "${SSH_PORT}.*ALLOW.*${VPC_IP_RANGE}"`" = "" ] )
then
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port ${SSH_PORT}
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port 443
  /usr/sbin/ufw allow from ${VPC_IP_RANGE} to any port 80
  updated="1"
fi

