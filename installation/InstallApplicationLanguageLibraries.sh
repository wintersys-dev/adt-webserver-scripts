#!/bin/sh
######################################################################################################
# Description: This script will install the php modules needed for the current application type
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

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh APPLICATIONLANGUAGE:PHP`" = "0" ] )
then
        exit
fi

BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
BUILDOS_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOSVERSION'`"
PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
WEBSERVER_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSERVERCHOICE'`"


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
HOME="`/bin/cat /home/homedir.dat`"

manager=""
options=""
tail_options=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt" ] )
then
	manager="/usr/bin/apt"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
	manager="/usr/bin/apt-get"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "nala" ] )
then
	manager="${HOME}/installation/nala_wrapper.sh"
	tail_options="-y"
fi           

export DEBIAN_FRONTEND=noninteractive
add_repository_command="/usr/bin/add-apt-repository -y "
install_command="${manager} ${options} install "
update_command="${manager} ${options} update "

if ( [ "${manager}" != "" ] )
then
        if ( [ "${BUILDOS}" = "ubuntu" ] )
        then
                if ( [ "${BUILDOS_VERSION}" = "24.04" ] || [ "${BUILDOS_VERSION}" = "26.04" ] )
                then
                        if ( ( [ "${BUILDOS_VERSION}" = "24.04" ] && [ "${PHP_VERSION}" = "8.3" ] ) || ( [ "${BUILDOS_VERSION}" = "26.04" ] && [ "${PHP_VERSION}" = "8.5" ] ) )
                        then
                                PHP_VERSION=""
                        fi
                        
                        php_application_modules="`/bin/grep "^PHP_MODULES:" ${HOME}/runtime/application.dat | /bin/sed 's/^PHP_MODULES://g' | /bin/sed 's/:/ /g'`"

                        for module in ${php_application_modules}
                        do
                                ${install_command} php${PHP_VERSION}-${module} ${tail_options}
                        done
                fi
        fi

        if ( [ "${BUILDOS}" = "debian" ] )
        then
                if ( [ "${BUILDOS_VERSION}" = "13" ] )
                then
                        if ( [ "${BUILDOS_VERSION}" = "13" ] && [ "${PHP_VERSION}" = "8.4" ] )
                        then
                                PHP_VERSION=""
                        fi
                fi
                
                php_application_modules="`/bin/grep "^PHP_MODULES:" ${HOME}/runtime/application.dat | /bin/sed 's/^PHP_MODULES://g' | /bin/sed 's/:/ /g'`"

                for module in ${php_application_modules}
                do
                        ${install_command} php${PHP_VERSION}-${module} ${tail_options}
                done
        fi
fi

/bin/touch ${HOME}/runtime/installedsoftware/InstallApplicationLanguageLibraries.sh
