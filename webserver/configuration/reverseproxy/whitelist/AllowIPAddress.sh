
ip_address="${1}"

VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
WEBSERVER_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSERVERCHOICE'`"

if ( [ "${WEBSERVER_CHOICE}" = "apache" ] )
then
  if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
  then
    /bin/echo "Require ip ${VPC_IP_RANGE}" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
    /bin/echo "Require ip 127.0.0.1" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
  fi
  /bin/echo "Require ip ${ip_address}" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
fi

if ( [ "${WEBSERVER_CHOICE}" = "nginx" ] )
then
  if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
  then
    /bin/echo "allow ${VPC_IP_RANGE};" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
    /bin/echo "allow 127.0.0.1;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
    /bin/echo "deny all;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
  fi
  /bin/sed -i "1s/^/allow ${ip_address};/" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
fi

