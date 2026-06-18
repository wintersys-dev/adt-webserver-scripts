#!/bin/sh
#################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: If a machine has been allowed access by an authenticator machine
# then allow its ip address through the whitelist of the webserver
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
#####################################################################################
#####################################################################################
#set -x

SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"
SERVER_USER_PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSERPASSWORD'`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
ALGORITHM="`${HOME}/utilities/config/ExtractConfigValue.sh 'ALGORITHM'`"
HOST="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "authenticatorip/*" | /usr/bin/tr '\n' ' '`"
BUILD_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDIDENTIFIER'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh ACTIVEFIREWALLS:1`" = "0" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh ACTIVEFIREWALLS:3`" = "0" ] )
then
        exit
fi

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir ${HOME}/runtime/authenticator
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "whitelist-auth-laptop-ips"  "${HOME}/runtime/authenticator"
/bin/cat ${HOME}/runtime/authenticator/whitelist-laptop-ips/ipaddresses.dat* > ${HOME}/runtime/authenticator/incoming_ipaddresses.dat

updated="0"
for ip_address in `/bin/cat ${HOME}/runtime/authenticator/incoming_ipaddresses.dat`
do
        if ( [ ! -f ${HOME}/runtime/authenticator/processed_ipaddresses.dat ] || [ "`/bin/grep ${ip_address} ${HOME}/runtime/authenticator/processed_ipaddresses.dat`" = "" ] )
        then
                if ( [ "`/bin/grep ${ip_address} ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat`" = "" ] )
                then
                        updated="1"
                        ${HOME}/webserver/configuration/reverseproxy/whitelist/AllowIPAddress.sh "${ip_address}"
                     #   /bin/echo "${ip_address}" >> ${HOME}/runtime/authenticator/processed_ipaddresses.dat
                fi
        fi
done

if ( [ -f ${HOME}/runtime/authenticator/incoming_ipaddresses.dat ] )
then
        /bin/rm ${HOME}/runtime/authenticator/incoming_ipaddresses.dat
fi

if ( [ "${updated}" = "1" ] )
then
        ${HOME}/webserver/ReloadWebserver.sh
fi
