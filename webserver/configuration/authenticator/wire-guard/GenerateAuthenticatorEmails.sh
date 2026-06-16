#!/bin/sh

set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"

/usr/bin/find /var/www/html -mmin +30 -name "*qrcode*" -type f -exec rm -fv {} \;
/usr/bin/find /var/www/html -mmin +30 -name "*client*" -type f -exec rm -fv {} \;

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "NEEDS_PROCESSING" -print | /usr/bin/awk -F'/' '{print $8}' | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"
reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"

for email_address in ${email_addresses}
do
        for ip in ${reverse_proxy_ips}
        do
                if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                then
                        if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf ] )
                        then
                                /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_interface.conf ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                        fi
                        /bin/echo "" >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf   
                        /bin/cat ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_peer.conf >> ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf
                fi
        done

        for ip in ${reverse_proxy_ips}
        do
                if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                then
                        /bin/cat ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                        /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                        
                        if ( [ -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                        then
                                /bin/rm ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/NEEDS_PROCESSING
                        fi
                fi
        done
        /bin/rm ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf
done

for email_address in ${email_addresses}
do
        reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"
        ip="`/bin/echo ${reverse_proxy_ips} | /usr/bin/xargs shuf -n1 -e`"
        reverse_proxy_ips="`/bin/echo ${reverse_proxy_ips} | /bin/sed "s/${ip}//g"`"
        ips="${ip} `/bin/echo ${reverse_proxy_ips} | /usr/bin/xargs shuf -n1 -e | /bin/sed 's/  / /g'`"
        count="0"
        for ip in ${ips}
        do
                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                full_file_name="/var/www/html/qrcode-${file_name}-${ip}-${email_address}.png"
                /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ${full_file_name}
                full_file_name_html="/var/www/html/client-${file_name}-${ip}-${email_address}.html"
                /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/client_peer_template.html ${full_file_name_html}
                /bin/sed -i -e "/XXXXCLIENT_PEERXXXX/{r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf" -e 'd}' ${full_file_name_html}

                if ( [ ! -f /var/www/html/txtstyle.css ] )
                then
                        /bin/echo "html, body {font-family:Helvetica, Arial, sans-serif}" > /var/www/html/txtstyle.css
                fi

                /bin/chmod 600 ${full_file_name}
                /bin/chmod 600 ${full_file_name_html}
                /bin/chown www-data:www-data /var/www/html/*
                if ( [ "${count}" = "0" ] )
                then
                        qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${ip}-${email_address}.png"
                        client_url="https://${WEBSITE_URL}/client-${file_name}-${ip}-${email_address}.html"
                        count="`/usr/bin/expr ${count} + 1`"
                else
                        backup_qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${ip}-${email_address}.png"
                        backup_client_url="https://${WEBSITE_URL}/client-${file_name}-${ip}-${email_address}.html"
                fi

                if ( [ "${NO_REVERSE_PROXIES}" -gt "1" ] )
                then
                        message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a> <br> <br><a href='"${backup_qrcode_url}"'>View Your Backup Wireguard QR Code</a> <br> <a href='"${backup_client_url}"'>View Your Backup Wireguard QR Client File</a> <br> <br> For future resiliance, install your primary AND your backup QR codes now into your wireguard app. The QR codes will be valid for half an hour. </body> </html>"
                else
                        message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  <br>  The QR code will be valid for half an hour. </body> </html>"
                fi
                /usr/bin/find ${HOME}/runtime/wire-guard/configs -name "CANDIDATE_QR_CODE" -path "*${email_address}*" -delete
        done
        ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" "MANDATORY" "${email_address}" "HTML" "AUTHENTICATION"
        /bin/echo ${email_address} >> ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
done

${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs/" "distributed"
