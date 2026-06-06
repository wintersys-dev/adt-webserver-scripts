
if ( [ ! -d ${HOME}/runtime/wire-guard/emails/processing ] )
then
	/bin/mkdir -p ${HOME}/runtime/wire-guard/emails/processing
fi

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat ] )
then
	for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
	do
		if ( [ ! -f ${HOME}/runtime/wire-guard/client/${email_address}/client_public.key ] )
		then
			if ( [ ! -d ${HOME}/runtime/wire-guard/client/${email_address} ] )
			then
				/bin/mkdir -p ${HOME}/runtime/wire-guard/client/${email_address}
			fi

			if ( [ ! -f ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key ] )
			then
				umask 077
				/usr/bin/wg genkey > ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key
				/bin/cat ${HOME}/runtime/wire-guard//client/${email_address}/client_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/wire-guard/client/${email_address}/client_public.key
			fi
                
			# Get the keys and server info
			new_client_private_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key`"
			new_client_public_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/client_public.key`"
			server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"

			if ( [ -f /etc/wireguard/wg0.conf ] )
			then
				client_no="`/bin/grep "Peer" /etc/wireguard/wg0.conf | /usr/bin/wc -l`"
				client_no="`/usr/bin/expr ${client_no} + 10`"
				/bin/echo ${client_no} > ${HOME}/runtime/wire-guard/client/${email_address}/CLIENT_NO
			fi

			twenty_four="`/usr/bin/expr ${client_no} / 255`"
			iteration1="`/usr/bin/expr ${twenty_four} \* 255`"
			thirty_two="`/usr/bin/expr ${client_no} - ${iteration1}`"
			sixteen="`/usr/bin/expr ${twenty_four} / 255`"
			iteration2="`/usr/bin/expr ${sixteen} \* 255`"
			twenty_four="`/usr/bin/expr ${twenty_four} - ${iteration2}`"

			if ( [ ! -f ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key ] )
			then
				/usr/bin/wg genpsk > ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key
			fi
                
			preshared_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key`"

			# Add peer to server config
			/bin/echo "[Peer]
	PublicKey = ${new_client_public_key}
	AllowedIPs = 10.${sixteen}.${twenty_four}.${thirty_two}/32
	PresharedKey = ${preshared_key}" >> /etc/wireguard/wg0.conf
		fi
	done
fi
              
