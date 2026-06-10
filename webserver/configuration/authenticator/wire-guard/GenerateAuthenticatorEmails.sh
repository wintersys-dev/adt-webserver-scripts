#!/bin/sh

#set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"

/usr/bin/find /var/www/html -mmin +30 -name "*qrcode*" -type f -exec rm -fv {} \;
/usr/bin/find /var/www/html -mmin +30 -name "*client*" -type f -exec rm -fv {} \;

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"

email_addresses="`/bin/ls ${HOME}/runtime/wire-guard/configs/* | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"
#reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"

for email_address in ${email_addresses}
do
        config_dirs="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "${email_address}" -print`"

        for config_dir in ${config_dirs}
        do
                if ( [ -f ${config_dir}/client.conf ] )
                then
                        /bin/rm ${config_dir}/client.conf
                fi
        done
done

for email_address in ${email_addresses}
do
        for config_dir in ${config_dirs}
        do
                if ( [ ! -f ${config_dir}/client.conf ] )
                then
                        /bin/cp ${config_dir}/client_interface.conf ${config_dir}/client.conf
                fi

                config_dirs1="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "${email_address}" -print`"

                for config_dir1 in ${config_dirs1}
                do
                        if ( [ -f ${config_dir1}/client_peer.conf ] )
                        then
                                /bin/cat ${config_dir1}/client_peer.conf >> ${config_dir}/client.conf
                                /bin/echo ${config_dir}/client.conf
                        fi
                done
                /usr/bin/qrencode -t png -o ${config_dir}/qrcode.png -r ${config_dir}/client.conf
                /bin/touch ${config_dir}/CANDIDATE_QR_CODE
        done
done

#reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"

#for ip in ${reverse_proxy_ips}
#do
#        email_addresses="`/bin/ls ${HOME}/runtime/wire-guard/configs/${ip}`"
#        for email_address in ${email_addresses}
#        do
#                if ( [ ! -f  ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf ] && [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
#                then
#                        /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_interface.conf ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf 
#                        /bin/echo "" >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
#                        /bin/cat ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_peer.conf >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf 
#                        /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
#                        /bin/touch ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/CANDIDATE_QR_CODE
#                fi
#        done
#done

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "CANDIDATE_QR_CODE"  -print | /usr/bin/awk -F'/' '{print $8}'`"
email_addresses="`/bin/echo ${email_addresses} | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"

#for ip in ${reverse_proxy_ips}
#do

for email_address in ${email_addresses}
do
        reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"
        ip="`/bin/echo ${reverse_proxy_ips} | /usr/bin/xargs shuf -n1 -e`"
        reverse_proxy_ips="`/bin/echo ${reverse_proxy_ips} | /bin/sed "s/${ip}/g"`"
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

                #/bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL_ORIGINAL}/g" ${full_file_name}
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
               # /bin/echo "${email_address}:${qrcode_url}" >> ${HOME}/runtime/wire-guard/qrcodes
               # /bin/echo "${email_address}:${client_url}" >> ${HOME}/runtime/wire-guard/clientconfig
                message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  </br> <a href='"${backup_qrcode_url}"'>View Your Backup Wireguard QR Code</a> <br> <a href='"${backup_client_url}"'>View Your Backup Wireguard QR Client File</a>  </br>  For future resiliance, install your primary and your backup QR codes now into your wireguard app. </body> </html>"
                # ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" "MANDATORY" "${email_address}" "HTML" "AUTHENTICATION"
                /bin/rm ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/CANDIDATE_QR_CODE
        done
done

${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs/" "distributed"
