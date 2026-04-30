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
#set -x

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir ${HOME}/runtime/authenticator
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
        /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/authenticator/authentication-emails.dat
fi

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
email_addresses=`/bin/ls /etc/wireguard/freshqrcodes/client_*.png | /bin/sed -e 's/.*client_//g' -e 's/\.png//g'`

for email_address in ${email_addresses}
do
        if ( [ -f /etc/wireguard/freshqrcodes/client_${email_address}.png ] )
        then
                file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
                full_file_name="/var/www/html/qrcode-${file_name}-${email_address}.png"
                /bin/cp /etc/wireguard/freshqrcodes/client_${email_address}.png ${full_file_name}
                /bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL_ORIGINAL}/g" ${full_file_name}
                /bin/chown www-data:www-data ${full_file_name}
                /bin/chmod 644 ${full_file_name}
                website_url="https://${WEBSITE_URL}/authorise-email-${file_name}.html"
                message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${website_url}"'>View Your Wireguard QR Code</a> </body> </html>"
                ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" MANDATORY ${email_address} "HTML" "AUTHENTICATION"

                if ( [ ! -d /etc/wireguard/processedqrcodes ] )
                then
                        /bin/mkdir /etc/wireguard/processedqrcodes
                fi

                /bin/mv /etc/wireguard/freshqrcodes/client_${email_address}.png /etc/wireguard/processedqrcodes/client_${email_address}.png
        fi              
done
