#set -x

export HOME="`/bin/cat /home/homedir.dat`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

/usr/bin/find /var/www/html/qrcode-* -mmin +5 -type f -exec rm -fv {} \;  2>/dev/null

if ( [ ! -d ${HOME}/runtime/authenticator/incoming ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator/incoming
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
        /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat
fi

${HOME}/services/datastore/operations/GetFromDatastore.sh "authentication-emails" "authentication-emails.dat" "${HOME}/runtime/authenticator/incoming"

/bin/touch ${HOME}/runtime/authenticator/incoming/authentication-emails.dat
/usr/bin/uniq ${HOME}/runtime/authenticator/incoming/authentication-emails.dat >> ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$
/bin/mv ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$ ${HOME}/runtime/authenticator/incoming/authentication-emails.dat

reverse_proxy_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "reverseproxypublicips/*"`"

if ( [ ! -f /etc/wireguard/postup.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/postup.sh /etc/wireguard
        /bin/sed -i "s/XXXXWG_PORTXXXX/${wireguard_port}/g" /etc/wireguard/postup.sh
fi

if ( [ ! -f /etc/wireguard/postdown.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/postdown.sh /etc/wireguard
        /bin/sed -i "s/XXXXWG_PORTXXXX/${wireguard_port}/g" /etc/wireguard/postdown.sh
fi

if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/preshared.key ] )
then
        /usr/bin/wg genpsk > ${HOME}/runtime/authenticator/wire-guard/preshared.key
fi
preshared_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/preshared.key`"


reverse_proxy_no="0"
for reverse_proxy_ip in ${reverse_proxy_ips}
do
        reverse_proxy_no="`/usr/bin/expr ${reverse_proxy_no} + 1`"

        if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/wg0.conf.${reverse_proxy_ip} ] )
        then
                if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/server_private.key ] )
                then
                        umask 077
                        /usr/bin/wg genkey > ${HOME}/runtime/authenticator/wire-guard/server_private.key
                        /bin/chmod 600 ${HOME}/runtime/authenticator/wire-guard/server_private.key
                        /bin/cat ${HOME}/runtime/authenticator/wire-guard/server_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/authenticator/wire-guard/server_public.key

                        server_private_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/server_private.key`"
                        server_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/server_public.key`"


                        /bin/echo "[Interface]
        PrivateKey = ${server_private_key}
        Address = 10.0.0.${reverse_proxy_no}/8
        MTU = 1380
        ListenPort = ${wireguard_port}
        SaveConfig = false
        PostUp = /etc/wireguard/postup.sh
        PostDown = /etc/wireguard/postdown.sh" > ${HOME}/runtime/authenticator/wire-guard/wg0.conf.${reverse_proxy_ip}
        
                fi
        fi

        for email_address in `/bin/cat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat`
        do
                if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_public.key ] )
                then
                        if ( [ ! -d ${HOME}/runtime/authenticator/wire-guard/client/${email_address} ] )
                        then
                                /bin/mkdir -p ${HOME}/runtime/authenticator/wire-guard/client/${email_address}
                        fi

                        if ( [ -f ${HOME}/runtime/authenticator/wire-guard/wg0.conf.${reverse_proxy_ip} ] )
                        then
                                client_no="`/bin/grep "Peer" ${HOME}/runtime/authenticator/wire-guard/wg0.conf.${reverse_proxy_ip} | /usr/bin/wc -l`"
                                client_no="`/usr/bin/expr ${client_no} + 2`"
                        fi

                        umask 077
                        /usr/bin/wg genkey > ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key
                        /bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_public.key

                        # Get the keys and server info
                        new_client_private_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key`"
                        new_client_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_public.key`"
                        server_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/server_public.key`"

                        twenty_four="`/usr/bin/expr ${client_no} / 255`"
                        iteration1="`/usr/bin/expr ${twenty_four} \* 255`"
                        thirty_two="`/usr/bin/expr ${client_no} - ${iteration1}`"
                        sixteen="`/usr/bin/expr ${twenty_four} / 255`"
                        iteration2="`/usr/bin/expr ${sixteen} \* 255`"
                        twenty_four="`/usr/bin/expr ${twenty_four} - ${iteration2}`"

                        # Add peer to server config
                        /bin/echo "[Peer]
        PublicKey = ${new_client_public_key}
        AllowedIPs = 10.${sixteen}.${twenty_four}.${thirty_two}/32
        PresharedKey = ${preshared_key}" >> ${HOME}/runtime/authenticator/wire-guard/wg0.conf.${reverse_proxy_ip}

                        #Create client config
                        /bin/echo "[Interface]
        PrivateKey = ${new_client_private_key}
        Address = 10.0.0.${client_no}/32
        MTU = 1380
        DNS = 1.1.1.1, 1.0.0.1" >>  ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.conf

                        for reverse_proxy_ip in ${reverse_proxy_ips}
                        do
                                /bin/echo "[Peer]
        PublicKey = ${server_public_key}
        PresharedKey = ${preshared_key}
        Endpoint = ${reverse_proxy_ip}:${wireguard_port}
        AllowedIPs =  10.0.0.0/8
        PersistentKeepalive = 25" >> ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.conf
                        done
                        /usr/bin/qrencode -t png -o ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/qrcode.png -r ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.conf
                        /bin/touch ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/CANDIDATE_QR_CODE
                fi
        done
done
