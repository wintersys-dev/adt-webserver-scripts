#!/bin/sh

set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

HOME="`/bin/cat /home/homedir.dat`"

WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"
NO_AUTHENTICATORS="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOAUTHENTICATORS'`"

dates="`/usr/bin/find /var/www/html | /bin/egrep "(client|qrcode)" | /usr/bin/awk -F'-' '{print $5}' | /bin/sed 's/\..*$//g' | /bin/sed '/^$/d'`"
links=""
current_date="`/usr/bin/date +%s`"
for date in ${dates}
do
        if ( [ "`/bin/expr ${current_date} - ${date}`" -gt "1800" ] )
        then
                links="`/usr/bin/find /var/www/html -name "*${date}*" -type f`"
        fi
        all_links="${all_links} ${links}"
done

if ( [ "${all_links}" != "" ] )
then
        for link in ${all_links}        
        do
                file="`/bin/echo ${link} | /usr/bin/awk -F'/' '{print $NF}'`"
                ${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emailed-links"  "${file}" "distributed"
                /bin/rm ${link}
        done
fi

authenticator_no="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"
sleep="`/usr/bin/expr ${authenticator_no} \* 10`"
/usr/bin/sleep ${sleep}

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"
${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emailed-links" "/var/www/html"

#if ( [ -f ${HOME}/runtime/wire-guard/time_email_sent ] )
#then
#        /bin/rm ${HOME}/runtime/wire-guard/time_email_sent
#fi
##
#
#if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "wire-guard-emailed-links" "time_email_sent"`" != "" ] )
#then 
#        ${HOME}/services/datastore/operations/GetFromDatastore.sh "wire-guard-emailed-links" "time_email_sent" "${HOME}/runtime/wire-guard" 
#fi
#
#if ( [ -f ${HOME}/runtime/wire-guard/time_email_sent ] )
#then
#        current_time="`/usr/bin/date +%s`"
#        backup_time="`/bin/cat ${HOME}/runtime/wire-guard/time_email_sent`"
#
#        if ( [ "`/usr/bin/expr ${current_time} - ${backup_time}`" -lt "60" ] )
 #       then
 #               exit
 #       fi
#fi

#time_email_sent="`/usr/bin/date +%s`"
#/bin/echo "${time_email_sent}" > ${HOME}/runtime/wire-guard/time_email_sent
#${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emailed-links" "${HOME}/runtime/wire-guard/time_email_sent" "root" "distributed" "no"

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "CLIENT_INTERFACE_GENERATED" -print | /usr/bin/awk -F'/' '{print $8}' | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"

reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"

/bin/touch ${HOME}/runtime/wire-guard/PROCESSED_EMAILS

for email_address in ${email_addresses}
do
        if ( [ "`/bin/grep ${email_address} ${HOME}/runtime/wire-guard/PROCESSED_EMAILS`" = "" ] && [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/EMAIL_PROCESSED ] )
        then
                primed="1"
                for ip in ${reverse_proxy_ips}
                do
                        if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_interface.conf ] || [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_peer.conf ] )
                        then
                                primed="0"
                        fi

                        if ( [ "${primed}" = "1" ] )
                        then
                                if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                                then
                                        if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf ] )
                                        then
                                                /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_interface.conf ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                                        fi
                                        /bin/echo "" >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf   
                                        /bin/cat ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client_peer.conf >> ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf
                                fi

                                if ( [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                                then
                                        /bin/cat ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf >> ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                                        /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf
                                fi
                        fi
                        /bin/rm ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf
                done
        fi
done

for email_address in ${email_addresses}
do
        if ( [ "`/bin/grep ${email_address} ${HOME}/runtime/wire-guard/PROCESSED_EMAILS`" = "" ] && [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/EMAIL_PROCESSED ] )
        then
                reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs`"
                ip="`/bin/echo ${reverse_proxy_ips} | /usr/bin/xargs shuf -n1 -e`"
                reverse_proxy_ips="`/bin/echo ${reverse_proxy_ips} | /bin/sed "s/${ip}//g"`"
                ips="${ip} `/bin/echo ${reverse_proxy_ips} | /usr/bin/xargs shuf -n1 -e | /bin/sed 's/  / /g'`"
                count="0"
                for ip in ${ips}
                do
                        if ( [ -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                        then
                                current_epoch_date="`/usr/bin/date +%s`"
                                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                                full_file_name="/var/www/html/qrcode-${file_name}-${ip}-${email_address}-${current_epoch_date}.png"
                                /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ${full_file_name}
                                full_file_name_html="/var/www/html/client-${file_name}-${ip}-${email_address}-${current_epoch_date}.html"
                                /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/client_peer_template.html ${full_file_name_html}
                                /bin/sed -i -e "/XXXXCLIENT_PEERXXXX/{r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf" -e 'd}' ${full_file_name_html}

                                if ( [ ! -f /var/www/html/txtstyle.css ] )
                                then
                                        /bin/echo "html, body {font-family:Helvetica, Arial, sans-serif}" > /var/www/html/txtstyle.css
                                fi

                                /bin/chmod 600 ${full_file_name}
                                /bin/chmod 600 ${full_file_name_html}
                                /bin/chown www-data:www-data /var/www/html/*

                                date_since_epoch="`/usr/bin/date +%s`"

                                if ( [ "${count}" = "0" ] )
                                then
                                        qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${ip}-${email_address}-${date_since_epoch}.png"
                                        client_url="https://${WEBSITE_URL}/client-${file_name}-${ip}-${email_address}-${date_since_epoch}.html"
                                        count="`/usr/bin/expr ${count} + 1`"
                                else
                                        backup_qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${ip}-${email_address}-${date_since_epoch}.png"
                                        backup_client_url="https://${WEBSITE_URL}/client-${file_name}-${ip}-${email_address}-${date_since_epoch}.html"
                                fi

                                ${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard-emailed-links" "/var/www/html" "distributed"

                                if ( [ "${NO_REVERSE_PROXIES}" -gt "1" ] )
                                then
                                        message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a> <br> <br><a href='"${backup_qrcode_url}"'>View Your Backup Wireguard QR Code</a> <br> <a href='"${backup_client_url}"'>View Your Backup Wireguard QR Client File</a> <br> <br> For future resiliance, install your primary AND your backup QR codes now into your wireguard app. The QR codes will be valid for half an hour. </body> </html>"
                                else
                                        message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  <br>  The QR code will be valid for half an hour. </body> </html>"
                                fi
                                /bin/touch ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/EMAIL_PROCESSED

                                if ( [ "`/bin/grep "^${email_address}$" ${HOME}/runtime/wire-guard/PROCESSED_EMAILS`" = "" ] )
                                then
                                        email_addresses="${email_addresses} ${email_address}"
                                        /bin/echo "${email_address}" >> ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
                                fi
                        fi
                done
                ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" "MANDATORY" "${email_address}" "HTML" "AUTHENTICATION"
                /bin/echo ${email_address} >> ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
        fi
done

${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs/" "distributed"
