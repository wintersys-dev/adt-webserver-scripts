updated="0"

#Because authenticator machines are more public facing that the other machines in our architecture we want to block ssh requests 
#to our infrastructure that originate from authenticator machines as they are slightly more vulnerable than our core infratructure machines.

if ( [ "`/usr/bin/hostname | /bin/grep '\-auth\-'`" = "" ] )
then
	authenticator_ip="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "authenticatorip/*" | /usr/bin/tr '\n' ' '`"
	authenticator_public_ip="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "authenticatorpublicip/*" | /usr/bin/tr '\n' ' '`"

	if ( [ "${authenticator_ip}" != "" ] )
	then

			/usr/sbin/ufw deny from ${authenticator_ip}
	fi

	if ( [ "${authenticator_public_ip}" != "" ] )
	then

			/usr/sbin/ufw deny from ${authenticator_public_ip}
	fi
fi

