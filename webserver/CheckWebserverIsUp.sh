#!/bin/sh
#########################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Check if the webserver is running and if it isn't try and start it
#########################################################################################
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
#########################################################################################
#########################################################################################
#set -x

export HOME="`/bin/cat /home/homedir.dat`"

if ( [ ! -f ${HOME}/runtime/INSTALLED_SUCCESSFULLY ] )
then
	 exit
fi

if ( [ "`/usr/bin/hostname | /bin/grep "\-auth-"`" != "" ] )
then
	WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL'`"
else
	WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
fi

PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"

# We don't want to be up if we are not secure 
if ( [ ! -f ${HOME}/ssl/live/${WEBSITE_URL}/fullchain.pem ] || [ ! -f ${HOME}/ssl/live/${WEBSITE_URL}/privkey.pem ] )
then
        exit
fi

online="1"
if ( [ "`/usr/bin/curl -s -I --max-time 60 --insecure https://localhost:443/adt-probe.php | /bin/grep 'ALIVE' 2>/dev/null`" = "" ] )
then
	${HOME}/utilities/processing/RunServiceCommand.sh php${PHP_VERSION}-fpm restart
elif ( [ "`/usr/bin/curl -s -I --max-time 60 --insecure https://localhost:443/adt-probe.php | /bin/grep 'ALIVE' 2>/dev/null`" = "" ] )
then
	${HOME}/webserver/RestartWebserver.sh
elif  ( [ "`/usr/bin/curl -s -I --max-time 60 --insecure https://localhost:443/adt-probe.php | /bin/grep 'ALIVE' 2>/dev/null`" = "" ] )
then
	if ( [ ! -d ${HOME}/runtime/webserver_status_audit ] )
	then
		/bin/mkdir -p ${HOME}/runtime/webserver_status_audit
	fi
	/bin/echo "`/usr/bin/hostname` is offline at `/usr/bin/date`"
	online="0"
fi

if ( [ "${online}" = "1" ] && [ ! -f ${HOME}/runtime/BEEN_ONLINE ] )
then
	if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "INSTALLED_SUCCESSFULLY"`" = "INSTALLED_SUCCESSFULLY" ] )
	then
		private_ip="`${HOME}/utilities/processing/GetIP.sh`"
		${HOME}/services/datastore/config/wrapper/PutToDatastore.sh "config" "${private_ip}" "beenonline" "no"
		/bin/touch ${HOME}/runtime/BEEN_ONLINE
	fi
fi


