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
                fi
        done
        /bin/rm ${HOME}/runtime/wire-guard/configs/${email_address}-client.conf
done
