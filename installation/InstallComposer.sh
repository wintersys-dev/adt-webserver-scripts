#!/bin/sh
######################################################################################################
# Description: This script will install composer
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

PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"

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
	manager="/usr/bin/nala"
	tail_options="-y"
fi

export DEBIAN_FRONTEND=noninteractive
update_command="${manager} ${options} update " 
install_command="${manager} ${options} install " 

count="0"
while ( [ ! -x /usr/local/bin/composer ] && [ "${count}" -lt "5" ] )
do
	if ( [ "${manager}" != "" ] )
	then
		if ( [ "${BUILDOS}" = "ubuntu" ] )
		then
			${HOME}/utilities/processing/RunServiceCommand.sh cron stop				
			eval ${update_command}			
			eval ${install_command} php${PHP_VERSION}-cli unzip	
			cd ~												
			/usr/bin/curl -sS https://getcomposer.org/installer -o /opt/composer-setup.php			
			HASH=`/usr/bin/curl -sS https://composer.github.io/installer.sig`				
			/usr/bin/php -r "if (hash_file('SHA384', '/opt/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"		
			/usr/bin/php /opt/composer-setup.php --install-dir=/usr/local/bin --filename=composer	
			${HOME}/utilities/processing/RunServiceCommand.sh cron start				
		fi

		if ( [ "${BUILDOS}" = "debian" ] )
		then
			${HOME}/utilities/processing/RunServiceCommand.sh cron stop				
			eval ${update_command}			
			eval ${install_command} php${PHP_VERSION}-cli unzip
			cd ~												
			/usr/bin/curl -sS https://getcomposer.org/installer -o /opt/composer-setup.php			
			HASH=`/usr/bin/curl -sS https://composer.github.io/installer.sig`				
			/usr/bin/php -r "if (hash_file('SHA384', '/opt/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"		
			/usr/bin/php /opt/composer-setup.php --install-dir=/usr/local/bin --filename=composer	
			${HOME}/utilities/processing/RunServiceCommand.sh cron start				
		fi
	fi
	count="`/usr/bin/expr ${count} + 1`"
done

if ( [ ! -x /usr/local/bin/composer ] && [ "${count}" = "5" ] )
then
	${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR COMPOSER" "I believe that composer hasn't installed correctly, please investigate" "ERROR"
else
	/bin/touch ${HOME}/runtime/installedsoftware/InstallComposer.sh				
fi
