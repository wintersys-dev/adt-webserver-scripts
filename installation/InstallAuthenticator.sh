#!/bin/sh
######################################################################################################
# Description: This script will install the chosen webserver configured as an authenticator
# Author: Peter Winter
# Date: 17/01/2017
#######################################################################################################
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

HOME="`/bin/cat /home/homedir.dat`"

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

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh WEBSERVERCHOICE:APACHE`" = "1" ] )
then
 	${HOME}/installation/InstallApache.sh ${BUILDOS}
	${HOME}/webserver/configuration/ConfigureApacheForAuthenticator.sh		
fi
	
if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh WEBSERVERCHOICE:NGINX`" = "1" ] )
then
 	${HOME}/installation/InstallNGINX.sh ${BUILDOS}
	${HOME}/webserver/configuration/ConfigureNginxForAuthenticator.sh			
fi
	
if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh WEBSERVERCHOICE:LIGHTTPD`" = "1" ] )
then
 	${HOME}/installation/InstallLighttpd.sh ${BUILDOS}
	${HOME}/webserver/configuration/ConfigureLighttpdForAuthenticator.sh		
fi
	
/bin/touch ${HOME}/runtime/installedsoftware/InstallAuthenticator.sh				



