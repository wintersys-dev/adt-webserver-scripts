#!/bin/sh
#################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This will generate the basic auth configurations used by the reverse
# proxy machines to grant or deny access based on the users email address and 
# the password that is emailed to them
#################################################################################
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
################################################################################
################################################################################
#set -x

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
USER_EMAIL_DOMAIN="`${HOME}/utilities/config/ExtractConfigValue.sh 'USEREMAILDOMAIN'`"
MULTI_REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'MULTIREGION'`"
machine_ip="`${HOME}/utilities/processing/GetIP.sh`"

datastore_scope="local"
if ( [ "${MULTI_REGION}" = "1" ] )
then
        datastore_scope="distributed"
fi

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator 
fi

basic_auth_file="${HOME}/runtime/authenticator/basic-auth.dat.${machine_ip}"
basic_auth_previous_credentials="${HOME}/runtime/authenticator/previous-basic-auth-credentials.dat"

/bin/touch ${basic_auth_previous_credentials}

if ( [ -f /var/www/basic-auth/basic-auth.dat ] )
then
        /bin/mv /var/www/basic-auth/basic-auth.dat ${basic_auth_file}.$$
else
        exit
fi
basic_auth_updated="0"
for data in `/bin/cat ${basic_auth_file}.$$`
do
        username="`/bin/echo ${data} | /usr/bin/awk -F':' '{print $1}'`"
        password="p`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-z0-9' | /usr/bin/cut -b 1-8`p"

        if ( [ "`/bin/echo ${username} | /bin/grep "${USER_EMAIL_DOMAIN}$"`" != "" ] )
        then
                if ( [ ! -f ${basic_auth_file} ] )
                then
                        /usr/bin/htpasswd -b -c ${basic_auth_file} ${username} ${password}
                else
                        /bin/sed -i "/^${username}:/d" ${basic_auth_file}
                        /usr/bin/htpasswd -b ${basic_auth_file} ${username} ${password}
                fi
                
                /bin/sed -i "s/^${username}:/NEW:${username}:/g" ${basic_auth_file}
                message="<!DOCTYPE html> <html> <body> <h1>The basic auth password you requested for ${WEBSITE_URL} is: ${password} </body> </html>"
                ${HOME}/services/email/SendEmail.sh "Basic Auth password request" "${message}" MANDATORY ${username} "HTML" "AUTHENTICATION"
                basic_auth_updated="1"
        fi
done

if ( [ -f ${basic_auth_file}.$$ ] )
then
        /bin/rm ${basic_auth_file}.$$
fi

if ( [ "${basic_auth_updated}" = "1" ] )
then
        ${HOME}/services/datastore/operations/MountDatastore.sh "basic-auth-credentials" "${datastore_scope}" 
        ${HOME}/services/datastore/operations/PutToDatastore.sh "basic-auth-credentials" ${basic_auth_file} "basic-auth-credentials" "${datastore_scope}" "no"
fi        
