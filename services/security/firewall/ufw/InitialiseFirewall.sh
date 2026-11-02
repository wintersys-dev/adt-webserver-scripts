
HOME="`/bin/cat /home/homedir.dat`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"

initialised="0"

if ( [ ! -f ${HOME}/runtime/FIREWALL-INITIALISED ] )
then
        if ( [ ! -f ${HOME}/runtime/FIREWALL-ACTIVE ] )
        then
                /usr/bin/yes | /usr/sbin/ufw reset
                /usr/sbin/ufw delete allow 22/tcp
                /usr/sbin/ufw logging off
                VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
                ip_addresses="`/usr/sbin/ufw status | /bin/grep "^443" | /bin/grep -v "${VPC_IP_RANGE}" | /bin/grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"`"

                for ip_address in ${ip_addresses}
                do
                        /usr/sbin/ufw delete allow from ${ip_address}
                done

                /usr/sbin/ufw reload
				intialised="1"
                /bin/touch ${HOME}/runtime/FIREWALL-INITIALISED 
        fi
fi
