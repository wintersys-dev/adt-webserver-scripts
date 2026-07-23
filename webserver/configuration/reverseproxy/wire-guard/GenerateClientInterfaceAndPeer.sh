set -x

export HOME="`/bin/cat /home/homedir.dat`"


if ( [ ! -f ${HOME}/runtime/REVERSEPROXY_READY ] )
then
        exit
fi

if ( [ ! -d ${HOME}/logs/wire-guard ] )
then
        /bin/mkdir -p ${HOME}/logs/wire-guard
fi

exec 1>>${HOME}/logs/wire-guard/client-peers.out
exec 2>>${HOME}/logs/wire-guard/client-peers.err

SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

endpoint="`${HOME}/utilities/processing/GetPublicIP.sh`"

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat.client ] )
then
        processing_new_email="0"
        for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat.client`
        do
                processing_new_email="1"

                if ( [ ! -d ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address} ] )
                then
                        /bin/mkdir -p ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}
                fi

                if ( [ ! -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_peer.conf ] )
                then
                        /bin/touch /etc/wireguard/wg0.conf
                        client_no="`/bin/grep "Peer" /etc/wireguard/wg0.conf | /usr/bin/wc -l`"
                        client_no="`/usr/bin/expr ${client_no} + 1`"    

                        if ( [ -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key ] )
                        then
                                client_private_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_private.key`"
                        fi

                        if ( [ "${client_private_key}" = "" ] )
                        then
                                exit
                        fi

                        if ( [ -f ${HOME}/runtime/wire-guard/server/server_public.key ] )
                        then
                                server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"
                        fi

                        if ( [ "${server_public_key}" = "" ] )
                        then
                                exit
                        fi

                        if ( [ -f ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/preshared.key ] )
                        then
                                preshared_key="`/bin/cat ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/preshared.key`"
                        fi

                        if ( [ "${preshared_key}" = "" ] )
                        then
                                exit
                        fi

                        twenty_four="`/usr/bin/expr ${client_no} / 255`"
                        iteration1="`/usr/bin/expr ${twenty_four} \* 255`"
                        thirty_two="`/usr/bin/expr ${client_no} - ${iteration1}`"
                        sixteen1="`/usr/bin/expr ${twenty_four} / 255`"
                        sixteen="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"
                        iteration2="`/usr/bin/expr ${sixteen1} \* 255`"
                        twenty_four="`/usr/bin/expr ${twenty_four} - ${iteration2}`"

                        # Create client config
                  #      /bin/echo "[Interface]
                  #      PrivateKey = ${client_private_key}
                  #      Address = 10.${sixteen}.${twenty_four}.${thirty_two}/32
                  #      MTU = 1380
                  #      DNS = 1.1.1.1, 1.0.0.1" > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_interface.conf
                  
                        /bin/echo "[Interface]
                        PrivateKey = ${client_private_key}
                        Address = 10.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`.0.${client_no}/32
                        MTU = 1380
                        DNS = 1.1.1.1, 1.0.0.1" > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_interface.conf

                    # This is the original   /bin/echo "[Peer]
                    #    PublicKey = ${server_public_key}
                    #    PresharedKey = ${preshared_key}
                    #    Endpoint = ${endpoint}:${wireguard_port}
                    #    AllowedIPs =  10.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`.0.${client_no}/32,10.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`.0.0/8
                    #    PersistentKeepalive = 25" > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_peer.conf
                        
                        /bin/echo "[Peer]
                        PublicKey = ${server_public_key}
                        PresharedKey = ${preshared_key}
                        Endpoint = ${endpoint}:${wireguard_port}
                        AllowedIPs =  10.0.0.0/8
                        PersistentKeepalive = 25" > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/client_peer.conf

                        current_epoch_date="`/usr/bin/date +%s`"
                      #  /bin/echo "${current_epoch_date}" > ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/GENERATION_TIMESTAMP
                        /bin/touch ${HOME}/runtime/wire-guard/client/${endpoint}/${email_address}/CLIENT_INTERFACE_GENERATED
                        /bin/sed -i "/^${email_address}$/d" ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat.client
                        #                       /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/client/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/client/${email_address}/client.conf
                fi
                #Write the QR code to the wireguard datastore and download it to the webroot of the authenticator and then send an email from this machine
                #with a link to the QR code on the webroot of the authenticator
        done

        if ( [ "${processing_new_email}" = "1" ] )
        then
                ${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/client/" "distributed"
        fi
fi

