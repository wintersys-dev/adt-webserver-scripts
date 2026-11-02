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


