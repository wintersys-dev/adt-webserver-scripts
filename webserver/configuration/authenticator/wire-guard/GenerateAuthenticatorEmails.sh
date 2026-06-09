#!/bin/sh

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"
reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"

for ip in ${reverse_proxy_ips}
do
        email_addresses="`/bin/ls ${HOME}/runtime/wire-guard/configs/${ip}`"
        for email_address in ${email_addresses}
        do
                if ( [ ! -f  ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf ] )
                then
                        /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_interface.conf ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf 
                        /bin/echo "" >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                        /bin/cat ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_peer.conf >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf 
                        /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/client/${ip}/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/client/${ip}/${email_address}/client.conf
                        /bin/touch ${HOME}/runtime/wire-guard/client/${ip}/${email_address}/CANDIDATE_QR_CODE
                fi
        done
done

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "CANDIDATE_QR_CODE"  -print | /usr/bin/awk -F'/' '{print $8}'`"

for ip in ${reverse_proxy_ips}
do
        for email_address in ${email_addresses}
        do
                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                full_file_name="/var/www/html/qrcode-${file_name}-${ip}-${email_address}.png"
                /bin/cp ${HOME}/runtime/wire-guard/client/${ip}/${email_address}/qrcode.png ${full_file_name}
                full_file_name_html="/var/www/html/client-${file_name}-${ip}-${email_address}.html"
                /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/client_peer_template.html ${full_file_name_html}
               # /bin/sed -i -e "/XXXXCLIENT_PEERXXXX/{r /etc/wireguard/client_${email_address}.conf" -e 'd}' ${full_file_name_html}

                if ( [ ! -f /var/www/html/txtstyle.css ] )
                then
                        /bin/echo "html, body {font-family:Helvetica, Arial, sans-serif}" > /var/www/html/txtstyle.css
                fi

                /bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL_ORIGINAL}/g" ${full_file_name}
                /bin/chmod 600 ${full_file_name}
                /bin/chmod 600 ${full_file_name_html}
                /bin/chown www-data:www-data /var/www/html/*
                qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${ip}-${email_address}.png"
                client_url="https://${WEBSITE_URL}/client-${file_name}-${ip}-${email_address}.html"
                message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  </br> </body> </html>"
                ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" MANDATORY ${email_address} "HTML" "AUTHENTICATION"
                /bin/rm ${HOME}/runtime/authenticator/wire-guard/client/${email_address}/CANDIDATE_QR_CODE
        done
done

${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs/" "distributed"
