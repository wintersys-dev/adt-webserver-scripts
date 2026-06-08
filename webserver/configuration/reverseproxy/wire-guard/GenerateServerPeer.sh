#set -x

export HOME="`/bin/cat /home/homedir.dat`"

if ( [ ! -f ${HOME}/runtime/REVERSEPROXY_READY ] )
then
        exit
fi

if ( [ ! -d ${HOME}/logs/wire-guard ] )
then
        /bin/mkdir -p ${HOME}/logs/wire-guard
fi

exec 1>>${HOME}/logs/wire-guard/server-peers.out
exec 2>>${HOME}/logs/wire-guard/server-peers.err

if ( [ ! -d ${HOME}/runtime/wire-guard/emails/processing ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/processing
fi

endpoint="`${HOME}/utilities/processing/GetPublicIP.sh`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL'`"

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat ] )
then
        for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
        do
                if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "wire-guard-emails" "SENT_NOTIFICATION_EMAIL"`" = "" ] )
                then
                        /bin/touch ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
                        ${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL "" "distributed" "no"
                        /bin/rm ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL

                        for email_address1 in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
                        do
                                message="The wireguard server IP addresses have changed at our end you will need to reconfigure your wireguard app by going to ${WEBSITE_URL} and replacing your previous wireguard client profile with a new one" 
                                message="${message} This happens when a redeployment of our servers is actioned."
                                ${HOME}/services/email/SendEmail.sh "WIREGUARD SERVER ALTERATION" "${message}" "MANDATORY" "${email_address1}" "HTML"
                        done
                fi
                
                if ( [ ! -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_public.key} ] )
                then
                        if ( [ ! -d ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address} ] )
                        then
                                /bin/mkdir -p ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}
                        fi

                        if ( [ ! -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key ] )
                        then
                                umask 077
                                /usr/bin/wg genkey > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key
                                /bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_public.key
                        fi


                        # Get the keys and server info
                        new_client_private_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key`"
                        new_client_public_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_public.key`"
                        server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"

                        /bin/touch /etc/wireguard/wg0.conf
                        client_no="`/bin/grep "Peer" /etc/wireguard/wg0.conf | /usr/bin/wc -l`"
                        client_no="`/usr/bin/expr ${client_no} + 10`"

                        twenty_four="`/usr/bin/expr ${client_no} / 255`"
                        iteration1="`/usr/bin/expr ${twenty_four} \* 255`"
                        thirty_two="`/usr/bin/expr ${client_no} - ${iteration1}`"
                        sixteen1="`/usr/bin/expr ${twenty_four} / 255`"
                        sixteen="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"
                        iteration2="`/usr/bin/expr ${sixteen1} \* 255`"
                        twenty_four="`/usr/bin/expr ${twenty_four} - ${iteration2}`"

                        if ( [ ! -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/preshared.key ] )
                        then
                                /usr/bin/wg genpsk > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/preshared.key
                        fi

                        preshared_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/preshared.key`"

                        # Add peer to server config
                        /bin/echo "[Peer]
                        PublicKey = ${new_client_public_key}
                        AllowedIPs = 10.${sixteen}.${twenty_four}.${thirty_two}/32
                        PresharedKey = ${preshared_key}" >> /etc/wireguard/wg0.conf
                        
                        if ( [ "`/bin/grep ${email_address} ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat`" = "" ] )
                        then
                                /bin/echo "${email_address}" >> ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat
                        fi
                fi
        done
        /bin/cat ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat >> ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat.client
fi
              
