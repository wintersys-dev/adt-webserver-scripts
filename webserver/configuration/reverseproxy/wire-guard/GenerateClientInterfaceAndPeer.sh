
export HOME="`/bin/cat /home/homedir.dat`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

endpoint="`${HOME}/utilities/processing/GetPublicIP.sh`"

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat ] )
then
	for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
	do
		if ( [ ! -f ${HOME}/runtime/wire-guard/client/${email_address}/client.conf ] )
		then
			if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key ] )
			then
				client_private_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/client_private.key`"
			fi

			if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/CLIENT_NO ] )
			then
				client_no="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/CLIENT_NO`"  
			fi
                
			if ( [ -f ${HOME}/runtime/wire-guard/server/server_public.key ] )
			then
				server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"
			fi
                
			if ( [ -f ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key ] )
			then
				preshared_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${email_address}/preshared.key`"
			fi

			twenty_four="`/usr/bin/expr ${client_no} / 255`"
			iteration1="`/usr/bin/expr ${twenty_four} \* 255`"
			thirty_two="`/usr/bin/expr ${client_no} - ${iteration1}`"
			sixteen="`/usr/bin/expr ${twenty_four} / 255`"
			iteration2="`/usr/bin/expr ${sixteen} \* 255`"
			twenty_four="`/usr/bin/expr ${twenty_four} - ${iteration2}`"

			# Create client config
			/bin/echo "[Interface]
  PrivateKey = ${client_private_key}
  Address = 10.${sixteen}.${twenty_four}.${thirty_two}/32
  MTU = 1380
  DNS = 1.1.1.1, 1.0.0.1 

[Peer]
  PublicKey = ${server_public_key}
  PresharedKey = ${preshared_key}
  Endpoint = ${endpoint}:${wireguard_port}
  AllowedIPs =  10.0.0.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`/32,10.0.0.0/8
  PersistentKeepalive = 25" >> ${HOME}/runtime/wire-guard/client/${email_address}/client.conf
        	/usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/client/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/client/${email_address}/client.conf
		fi
		#Write the QR code to the wireguard datastore and download it to the webroot of the authenticator and then send an email from this machine
		#with a link to the QR code on the webroot of the authenticator
	done
fi

