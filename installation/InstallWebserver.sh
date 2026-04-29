#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will perform a rudimentary configuration of your chosen
# webserver. You are welcome to modify it to your own requirements.
###################################################################################
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
##################################################################################
##################################################################################
set -x

WEBSERVER_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSERVERCHOICE'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
WEBSITE_NAME="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{print $2}'`"
SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"

buildos=""

if ( [ "${1}" != "" ] )
then
        buildos="${1}"
fi

if ( [ "${buildos}" = "" ] )
then
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
else 
        BUILDOS="${buildos}"
fi

if ( [ "${WEBSERVER_TYPE}" = "NGINX" ] )
then
        ${HOME}/installation/InstallNGINX.sh ${BUILDOS}

        if ( [ "`/usr/bin/hostname | /bin/grep "^ws-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureNginxForApplication.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureNginxForReverseProxy.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureNginxForAuthenticator.sh
        fi
fi

if ( [ "${WEBSERVER_TYPE}" = "APACHE" ] )
then
        ${HOME}/installation/InstallApache.sh ${BUILDOS}

        if ( [ "`/usr/bin/hostname | /bin/grep "^ws-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureApacheForApplication.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureApacheForReverseProxy.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureApacheForAuthenticator.sh
        fi
fi

if ( [ "${WEBSERVER_TYPE}" = "LIGHTTPD" ] )
then
        ${HOME}/installation/InstallLighttpd.sh ${BUILDOS}

        if ( [ "`/usr/bin/hostname | /bin/grep "^ws-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureLighttpdForApplication.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureLighttpdForReverseProxy.sh
        elif ( [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
        then
                ${HOME}/webserver/configuration/ConfigureLighttpdForAuthenticator.sh
        fi
fi

/bin/touch ${HOME}/runtime/installedsoftware/InstallWebserver.sh			

