#!/bin/sh
###########################################################################################################
# Description: This will generate a one time link to a file allowing the user to input their IP address
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

email_list="`/bin/cat ${HOME}/runtime/authenticator/authentication-emails.dat | /usr/bin/awk -F':' '{print $NF}'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"

#create a diirectory for new QR codes send the email to email address that the QR code is labelled as  and then move the QR code into processed. 
#When we generate the QR code check if it exists in the processed directory and if it does, copy it from the processed to tbe new
#Also copy all the processed QR codes to the datastore and sync them down to the processed directory from other machines

for email_address in ${email_list}
do
        file_name="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"
        full_file_name="/var/www/html/authorise-email-${file_name}.html"
        /bin/cp ${HOME}/webserver/configuration/authenticator/wire-guard/request_authorisation.html ${full_file_name}
        /bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL_ORIGINAL}/g" ${full_file_name}
        /bin/chown www-data:www-data ${full_file_name}
        /bin/chmod 644 ${full_file_name}
        website_url="https://${WEBSITE_URL}/authorise-email-${file_name}.html"
        message="<!DOCTYPE html> <html> <body> <h1>Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}</h1> <p>Click the below link in order to authorise your wireguard access for ${WEBSITE_URL_ORIGINAL} </p> <a href='"${website_url}"'>Enable Your IP Address</a> </body> </html>"
        ${HOME}/services/email/SendEmail.sh "Wireguard authorisation for ${WEBSITE_URL_ORIGINAL}" "${message}" MANDATORY ${email_address} "HTML" "AUTHENTICATION"
        /bin/sed -i "/${email_address}$/d" ${HOME}/runtime/authenticator/authentication-emails.dat
done
