#!/bin/sh

export HOME="`/bin/cat /home/homedir.dat`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

if ( [ ! -d ${HOME}/runtime/authenticator/incoming ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator/incoming
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
        /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat
fi

/usr/bin/uniq ${HOME}/runtime/authenticator/incoming/authentication-emails.dat >> ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$
/bin/mv ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$ ${HOME}/runtime/authenticator/incoming/authentication-emails.dat

authenticator_ip="`${HOME}//utilities/processing/GetPublicIP.sh`"

if ( [ ! -f /etc/wireguard/wg0.conf ] )
then
        for authenticator_ip in ${server_ips}
        do
                if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_private.key ] )
                then
                        umask 077
                        /usr/bin/wg genkey > ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_private.key
                        /bin/chmod 600 ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_private.key
                        /bin/cat ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_public.key

                        server_private_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_private.key`"
                        server_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_public.key`"

                        if ( [ ! -f ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/preshared.key ] )
                        then
                                /usr/bin/wg genpsk > ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/preshared.key
                                preshared_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/preshared.key`"
                        fi

                        /bin/echo "[Interface]
                        PrivateKey = ${server_private_key}
                        Address = 10.0.0.1/24
                        PresharedKey = ${preshared_key}
                        MTU = 1380
                        ListenPort = ${wireguard_port}
                        SaveConfig = false
                        PostUp = /etc/wireguard/postup.sh
                        PostDown = /etc/wireguard/postdown.sh" > /etc/wireguard/wg0.conf
                fi
        done
fi

if ( [ -f /etc/wireguard/wg0.conf ] )
then
        client_no="`/bin/grep "Peer" /etc/wireguard/wg0.conf | /usr/bin/wc -l`"
        client_no="`/usr/bin/expr ${client_no} + 2`"
fi

for email_address in `/bin/cat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat`
do
        /usr/bin/wg genkey > ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key
        /bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_public.key

        # Get the keys and server info
        new_client_private_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_private.key`"
        new_client_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client_public.key`"
        server_public_key="`/bin/cat ${HOME}/runtime/authenticator/wire-guard/authenticators/${authenticator_ip}/server_public.key`"

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
        PresharedKey = ${preshared_key}" >> /etc/wireguard/wg0.conf

        # Create client config
        /bin/echo "[Interface]
        PrivateKey = ${new_client_private_key}
        Address = 10.0.0.${client_no}/32
        MTU = 1380
        DNS = 1.1.1.1, 1.0.0.1 

        [Peer]
        PublicKey = ${server_public_key}
        PresharedKey = ${preshared_key}
        Endpoint = ${server_ip}:${wireguard_port}
        AllowedIPs =  10.0.0.0/16
        PersistentKeepalive = 25" >> ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.conf

        /usr/bin/qrencode -t png -o ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.png -r ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/client.conf
done
