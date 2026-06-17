
                
if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
then
  /bin/echo "Require ip ${VPC_IP_RANGE}" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
  /bin/echo "Require ip 127.0.0.1" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
fi
/bin/echo "Require ip ${ip_address}" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
