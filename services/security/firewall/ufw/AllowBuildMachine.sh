
export HOME="`/bin/cat /home/homedir.dat`"


BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"

updated="0"

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDMACHINEVPC:0`" = "1" ] )
then
	    if ( [ "`/usr/sbin/ufw status | /bin/grep  "${SSH_PORT}.*ALLOW.*${BUILD_MACHINE_IP}"`" = "" ] )
		then
			/usr/sbin/ufw allow from ${BUILD_MACHINE_IP}/32 to any port ${SSH_PORT}
			/usr/sbin/ufw allow from ${BUILD_MACHINE_IP}/32 to any port 443
			/bin/sleep 2
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


