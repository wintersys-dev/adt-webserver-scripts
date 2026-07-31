#!/bin/sh
###########################################################################################################
# Description: This will accept candidate email addresses from the HTML form running on an authenticator
# server and will store the email address(es) in the datastore where the reverse proxies can access them
# to see who they need to open up to. 
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

MULTI_REGION="`${HOME}/utilities/config/ExtractConfigValue.sh 'MULTIREGION'`"
USER_EMAIL_DOMAIN="`${HOME}/utilities/config/ExtractConfigValue.sh 'USEREMAILDOMAIN'`"
machine_ip="`${HOME}/utilities/processing/GetIP.sh`"

datastore_scope="local"
if ( [ "${MULTI_REGION}" = "1" ] )
then
        datastore_scope="distributed"
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
	/bin/sed -i "/${USER_EMAIL_DOMAIN}/!d" /var/www/wire-guard/authentication-emails.dat
    if ( [ ! -d ${HOME}/runtime/wire-guard/emails ] )
	then
		/bin/mkdir -p ${HOME}/runtime/wire-guard/emails
	fi
    
	/bin/cat /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/wire-guard/emails/authentication-emails.dat.${machine_ip}
    ${HOME}/services/datastore/operations/MountDatastore.sh "wire-guard-emails" "${datastore_scope}" 
	${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/emails/authentication-emails.dat.${machine_ip} "" "${datastore_scope}" "no"

fi
