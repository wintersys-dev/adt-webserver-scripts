updated_ssh="0"
if ( [ "`/bin/grep ${VPC_IP_RANGE} /etc/ssh/sshd_config`" = "" ] )
then
	if ( [ "${SERVER_USER}" != "" ] && [ "${VPC_IP_RANGE}" != "" ] )
	then
		if ( [ "`/bin/grep "AllowUsers" /etc/ssh/sshd_config.d/99-hardening.conf | /bin/grep "${SERVER_USER}" | /bin/grep "${VPC_IP_RANGE}"`" = "" ] )
		then
			/bin/echo "AllowUsers ${SERVER_USER}@${VPC_IP_RANGE}" >> /etc/ssh/sshd_config.d/99-hardening.conf
			updated_ssh="1"
		fi
	fi
fi

if ( [ "`/bin/grep ${BUILD_MACHINE_IP} /etc/ssh/sshd_config`" = "" ] )
then
	if ( [ "${SERVER_USER}" != "" ] && [ "${BUILD_MACHINE_IP}" != "" ] )
	then
		if ( [ "`/bin/grep "AllowUsers" /etc/ssh/sshd_config.d/99-hardening.conf | /bin/grep "${SERVER_USER}" | /bin/grep "${BUILD_MACHINE_IP}"`" = "" ] )
		then
			/bin/echo "AllowUsers ${SERVER_USER}@${BUILD_MACHINE_IP}" >> /etc/ssh/sshd_config.d/99-hardening.conf
			updated_ssh="1"
		fi
	fi
fi

if ( [ "${updated_ssh}" = "1" ] )
then
	${HOME}/utilities/processing/RunServiceCommand.sh "ssh" restart
fi

