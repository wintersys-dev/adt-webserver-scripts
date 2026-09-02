#!/bin/sh
######################################################################################################
# Description: This script will install drush
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

count="0"
while ( [ ! -x /usr/sbin/drush ] && [ "${count}" -lt "5" ] )
do
	webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
	cd ${webroot_directory}
	
	if ( [ "${BUILDOS}" = "ubuntu" ] )
	then
                /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 

                if ( [ -f ${webroot_directory}/vendor/bin/drush.php ] )
                then
                        /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/bin/drush.php"> /usr/sbin/drush
                        /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/drush/drush" >> /usr/sbin/drush
                        /bin/echo "/usr/bin/php ${webroot_directory}/vendor/bin/drush.php \$@" >> /usr/sbin/drush
                        /bin/chmod 750 /usr/sbin/drush
                fi
	fi

	if ( [ "${BUILDOS}" = "debian" ] )
	then    
	#temporary
	         #   /usr/bin/sudo -u www-data /usr/local/bin/composer config allow-plugins true
	#######
                /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 

                if ( [ -f ${webroot_directory}/vendor/bin/drush.php ] )
                then
                        /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/bin/drush.php"> /usr/sbin/drush
                        /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/drush/drush" >> /usr/sbin/drush
                        /bin/echo "/usr/bin/php ${webroot_directory}/vendor/bin/drush.php \$@" >> /usr/sbin/drush
                        /bin/chmod 750 /usr/sbin/drush
                fi
	fi
	count="`/usr/bin/expr ${count} + 1`"
done

if ( [ ! -x /usr/sbin/drush ] && [ "${count}" = "5" ] )
then
	${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR drush" "I believe that drush hasn't installed correctly, please investigate" "ERROR"
else
	/bin/touch ${HOME}/runtime/installedsoftware/InstallDrush.sh				
fi
