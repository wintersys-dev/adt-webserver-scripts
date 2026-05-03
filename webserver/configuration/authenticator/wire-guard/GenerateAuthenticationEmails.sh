#!/bin/sh
###########################################################################################################
# Description: This will generate a one time link to a QR code for access to wireguard enabled servers
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
set -x

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir ${HOME}/runtime/authenticator
fi

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
email_addresses=`/bin/ls /etc/wireguard/client_*.png | /bin/sed -e 's/.*client_//g' -e 's/\.png//g'`


for email_address in ${email_addresses}
do
        if ( [ -f /etc/wireguard/client_${email_address}.png ] )
        then
                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                full_file_name="/var/www/html/qrcode-${file_name}-${email_address}.png"
                /bin/mv /etc/wireguard/client_${email_address}.png ${full_file_name}
                full_file_name_html="/var/www/html/client-${file_name}-${email_address}.html"
                /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/client_peer_template.html ${full_file_name_html}
                /bin/sed -i -e "/XXXXCLIENT_PEERXXXX/{r /etc/wireguard/client_${email_address}.conf" -e 'd}' ${full_file_name_html}
                /bin/rm /etc/wireguard/client_${email_address}.conf
                if ( [ ! -f /var/www/html/txtstyle.css ] )
                then
                        /bin/echo "html, body {font-family:Helvetica, Arial, sans-serif}" > /var/www/html/txtstyle.css
                fi
                /bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL_ORIGINAL}/g" ${full_file_name}
                /bin/chmod 600 ${full_file_name}
                /bin/chmod 600 ${full_file_name_html}
                /bin/chown www-data:www-data /var/www/html/* 
                qrcode_url="https://${WEBSITE_URL}/qrcode-${file_name}-${email_address}.png"
                client_url="https://${WEBSITE_URL}/client-${file_name}-${email_address}.html"
                message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${qrcode_url}"'>View Your Wireguard QR Code</a> <br> <a href='"${client_url}"'>View Your Wireguard QR Client File</a>  </br> </body> </html>"
                ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" MANDATORY ${email_address} "HTML" "AUTHENTICATION"
        fi              
done
