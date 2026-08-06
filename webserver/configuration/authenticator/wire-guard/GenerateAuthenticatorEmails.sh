#!/bin/sh
###########################################################################################################
# Description: This will remove any expired unique link QRcodes or client configs. Generate new QR codes based
# on the client config that the reverse proxy has supplied to us and email the QRCodes and client config
# to the user's email address. The processed config files are then written to the datastore so that they
# can be copied to any other authenticators so that they are available on their filesystems also.
# Author : Peter Winter
# Date: 17/05/2017
######################################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

HOME="`/bin/cat /home/homedir.dat`"

WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
MULTI_REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'MULTIREGION'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"
NO_AUTHENTICATORS="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOAUTHENTICATORS'`"

datastore_scope="local"
if ( [ "${MULTI_REGION}" = "1" ] )
then
        datastore_scope="distributed"
fi

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
                ${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emailed-links"  "${file}" "${datastore_scope}"
                /bin/rm ${link}
        done
fi

authenticator_no="`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`"
sleep="`/usr/bin/expr ${authenticator_no} \* 10`"
/usr/bin/sleep ${sleep}

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"
${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emailed-links" "/var/www/html"

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "CLIENT_INTERFACE_GENERATED" -print | /usr/bin/awk -F'/' '{print $8}' | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"
reverse_proxy_ips="`/bin/ls ${HOME}/runtime/wire-guard/configs | /bin/grep  ".*\..*\..*\..*"`"

/bin/touch ${HOME}/runtime/wire-guard/PROCESSED_EMAILS

/usr/bin/sort ${HOME}/runtime/wire-guard/PROCESSED_EMAILS | /usr/bin/uniq > ${HOME}/runtime/wire-guard/PROCESSED_EMAILS.$$
/bin/mv ${HOME}/runtime/wire-guard/PROCESSED_EMAILS.$$ ${HOME}/runtime/wire-guard/PROCESSED_EMAILS

client_configs="`/usr/bin/find ${HOME}/runtime/wire-guard -name "CLIENT_INTERFACE_GENERATED" -print`"

if ( [ "${NO_REVERSE_PROXIES}" -ne "`/bin/echo "${client_configs}" | /usr/bin/wc -l`" ] )
then
        exit
fi

for client_config in ${client_configs}
do
        email_address="`/bin/echo ${client_config} | /usr/bin/awk -F'/' '{print $8}'`"
        ip_address="`/bin/echo ${client_config} | /usr/bin/awk -F'/' '{print $7}'`"

        if ( [ ! -d ${HOME}/runtime/wire-guard/client_configs/${email_address} ] )
        then
                /bin/mkdir -p ${HOME}/runtime/wire-guard/client_configs/${email_address}
        fi

        client_config="`/bin/echo ${client_config} | /bin/sed 's/CLIENT_INTERFACE_GENERATED/client.conf/'`"
        client_interface="`/bin/echo ${client_config} | /bin/sed 's/client.conf/client_interface.conf/'`"
        client_peer="`/bin/echo ${client_config} | /bin/sed 's/client.conf/client_peer.conf/'`"

        /bin/cat ${client_interface} > ${client_config}
        /bin/cat ${client_peer} >> ${client_config}

        /bin/cp ${client_config} ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf.${ip_address} 

        /bin/grep " Address " ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf.${ip_address} | /usr/bin/awk '{print $NF}' >> ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-addresses

        if ( [ ! -f ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master ] )
        then
                /bin/cp ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf.${ip_address} ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master 
                /bin/sed -i '/\[Peer\]/,$d' ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master
        fi

        /bin/sed -i '/\[Peer\]/,$!d' ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf.${ip_address}
        /bin/cat ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf.${ip_address} >> ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master
done

addresses="`/bin/cat ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-addresses | /usr/bin/sort | /usr/bin/uniq | /usr/bin/tr '\n' ' '`"

if ( [ -f ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master ] )
then
        addresses="`/bin/echo ${addresses} | /bin/sed -e 's/ /, /g' -e 's/ $//g' -e 's/,$//g'`"
        /bin/sed -i "s;.*Address.*;                        Address = ${addresses};g" ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master
fi


ordered_ips=`/bin/grep AllowedIPs ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master | /usr/bin/awk '{print $NF}' | /usr/bin/cut -d '.' -f -2 | /bin/sed 's/10./10x./g'`

count="1"
for ip in ${ordered_ips}
do
        /bin/sed -i "0,/10.${count}/ s/10.${count}/${ip}/" ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master
        count="`/usr/bin/expr ${count} + 1`"
done

/bin/sed -i 's/10x/10/g' ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master


#full_ips=`/bin/grep "Address =" ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master | /bin/sed -e 's/.*=//g' -e 's/,//g'`
#short_ips=`/bin/grep AllowedIPs ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master | /usr/bin/awk '{print $NF}' | /usr/bin/cut -d '.' -f -2`

#count="1"
#for ip in ${short_ips}
#do
#        machine_ip="`/bin/echo ${full_ips} | /usr/bin/cut -d' ' -f${count}`"
#        /bin/sed -i "/AllowedIPs.*${ip}/s;$;, ${machine_ip};" ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master
#        count="`/usr/bin/expr ${count} + 1`"
#done

reverse_proxy_directories="`/usr/bin/find ${HOME}/runtime/wire-guard -name "CLIENT_INTERFACE_GENERATED" -print | /bin/sed 's;/CLIENT_INTERFACE_GENERATED;;g'`"

for directory in ${reverse_proxy_directories}
do
        /bin/cp ${HOME}/runtime/wire-guard/client_configs/${email_address}/client.conf-master ${directory}
done

if ( [ -f ${HOME}/runtime/wire-guard/configs/client.conf-master ] )
then
        /bin/rm ${HOME}/runtime/wire-guard/configs/client.conf-master
fi

/bin/rm ${HOME}/runtime/wire-guard/client_configs/${email_address}/*

for email_address in ${email_addresses}
do
        if ( [ "`/bin/grep ${email_address} ${HOME}/runtime/wire-guard/PROCESSED_EMAILS`" = "" ] && [ ! -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/EMAIL_PROCESSED ] )
        then
                primed="1"
                for ip in ${reverse_proxy_ips}
                do
                        if ( [ -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf-master ] )
                        then
                                /usr/bin/qrencode -t png -o ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png -r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf-master
                        fi
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

                for ip in ${ips}
                do
                        if ( [ -f ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ] )
                        then
                                current_epoch_date="`/usr/bin/date +%s`"
                                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                                file_name="qrcode-${file_name}-${email_address}-${current_epoch_date}.png"
                                full_file_name="/var/www/html/${file_name}"
                                /bin/cp ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/qrcode.png ${full_file_name}
                                file_name_html="client-${file_name}-${email_address}-${current_epoch_date}.html"
                                full_file_name_html="/var/www/html/${file_name_html}"
                                /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/client_peer_template.html ${full_file_name_html}
                                /bin/sed -i -e "/XXXXCLIENT_PEERXXXX/{r ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/client.conf-master" -e 'd}' ${full_file_name_html}

                                if ( [ ! -f /var/www/html/txtstyle.css ] )
                                then
                                        /bin/echo "html, body {font-family:Helvetica, Arial, sans-serif}" > /var/www/html/txtstyle.css
                                fi

                                /bin/chmod 600 ${full_file_name}
                                /bin/chmod 600 ${full_file_name_html}
                                /bin/chown www-data:www-data /var/www/html/*

                                qrcode_url="https://${WEBSITE_URL}/${file_name}"
                                client_url="https://${WEBSITE_URL}/${file_name_html}"
                                count="`/usr/bin/expr ${count} + 1`"

                                ${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard-emailed-links" "/var/www/html" "${datastore_scope}"

                                message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  <br>  The QR code will be valid for half an hour. </body> </html>"

                                /bin/touch ${HOME}/runtime/wire-guard/configs/${ip}/${email_address}/EMAIL_PROCESSED

                                if ( [ "`/bin/grep "^${email_address}$" ${HOME}/runtime/wire-guard/PROCESSED_EMAILS`" = "" ] )
                                then
                                        /bin/echo "${email_address}" >> ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
                                fi
                        fi
                done
                ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" "MANDATORY" "${email_address}" "HTML" "AUTHENTICATION"
                /bin/echo ${email_address} >> ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
        fi
done

${HOME}/services/datastore/operations/SyncToDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs/" "${datastore_scope}"

