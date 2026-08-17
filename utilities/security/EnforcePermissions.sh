#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 11/08/2021
# Description: This script will enforce filesystem permissions and can be modified according
# to how you want your server secured
#######################################################################################
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
########################################################################################
########################################################################################
set -x

HOME="`/bin/cat /home/homedir.dat`"
SERVER_USER="`/bin/ls -d /home/X*X | /usr/bin/awk -F'/' '{print $NF}'`"
APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION'`"
mode="${1}"


/usr/bin/find ${HOME} -type d -exec chmod 755 {} \;
/usr/bin/find ${HOME} -type f -exec chmod 750 {} \;
/usr/bin/find ${HOME} -type d -exec chown ${SERVER_USER}:root {} \;
/usr/bin/find ${HOME} -type f -exec chown ${SERVER_USER}:root {} \;

if ( [ -f ${HOME}/.bashrc ] )
then
        /bin/chmod 644 ${HOME}/.bashrc
        /bin/chown ${SERVER_USER}:root ${HOME}/.bashrc
fi

if ( [ -f ${HOME}/.ssh/webserver_configuration_settings.dat.gz ] )
then
        /bin/chown root:root ${HOME}/.ssh/webserver_configuration_settings.dat.gz
        /bin/chmod 600 ${HOME}/.ssh/webserver_configuration_settings.dat.gz
fi

if ( [ -f ${HOME}/.ssh/webserver_configuration_settings.dat ] )
then
        /bin/chown root:root ${HOME}/.ssh/webserver_configuration_settings.dat
        /bin/chmod 660 ${HOME}/.ssh/webserver_configuration_settings.dat
fi

if ( [ -f ${HOME}/.ssh/software.dat.gz ] )
then
        /bin/chown root:root ${HOME}/.ssh/software.dat.gz
        /bin/chmod 660 ${HOME}/.ssh/software.dat.gz
fi

if ( [ -f ${HOME}/.ssh/software.dat ] )
then
        /bin/chown root:root ${HOME}/.ssh/software.dat
        /bin/chmod 660 ${HOME}/.ssh/software.dat
fi

#If you want to harden the security of your system you  can change the ownerships of these files to root but you won't be able
#to "get rooted" using ${HOME}/super/Super.sh

if ( [ -f ${HOME}/runtime/webserver_configuration_settings.dat ] )
then
        #/bin/chown root:root ${HOME}/runtime/webserver_configuration_settings.dat
        /bin/chmod 660 ${HOME}/runtime/webserver_configuration_settings.dat
fi

if ( [ -f ${HOME}/runtime/software.dat ] )
then
        #/bin/chown root:root ${HOME}/runtime/software.dat
        /bin/chmod 660 ${HOME}/runtime/software.dat
fi

/bin/chmod 700 ${HOME}/.ssh
/bin/chmod 600 ${HOME}/.ssh/authorized_keys
/bin/chmod 600 ${HOME}/.ssh/id_*
/bin/chmod 644 ${HOME}/.ssh/id_*pub

if ( [ "${mode}" != "core-only" ] )
then
        /bin/chmod 755 /var/www/html
        webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

        if ( [ "${webroot_directory}" = "" ] )
        then
                webroot_directory="/var/www/html/${APPLICATION}"
        fi

        if ( [  -d ${webroot_directory} ] )
        then
                /bin/chown -R root:www-data ${webroot_directory}
                command="/usr/bin/find ${webroot_directory} "

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:1`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:2`" = "1" ] )
                then
                        for dir in `/usr/bin/mount | /bin/grep -Eo "/var/www/html.* " | /usr/bin/awk '{print $1}' | /usr/bin/tr '\n' ' '`
                        do
                                command="${command} -path '"${dir}"' -prune -o "
                        done
                fi

                command1="${command} -type d -exec chmod 0750 {} \;"
                command2="${command} -type f -exec chmod 0640 {} \;"

                eval ${command1} &
                eval ${command2}

        fi

		open_perms_directories="`/bin/grep "^OPEN_PERMS_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed -e 's/OPEN_PERMS_DIRECTORIES://g' -e 's/:/ /g'`"
		for directory in ${open_perms_directories}
		do
			/bin/chown -R www-data:www-data ${directory}
		done

  #      for directory in `/bin/grep "^DIRECTORIES_TO_CREATE:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_TO_CREATE://g' | /bin/sed 's/:/ /g'`
  #      do
  #              if ( [ -d /var/www/html/${directory} ] )
  #              then
  #                      /bin/chown -R www-data:www-data /var/www/html/${directory}
  #              fi
  #              command="/usr/bin/find /var/www/html/${directory} "
#
 #               command1="${command} -type d -exec chmod 0700 {} \;"
  #              command2="${command} -type f -exec chmod 0600 {} \;"
#
 #               eval ${command1} &
  #              eval ${command2}
#
 #       done

        /bin/chown www-data:www-data /var/www/html/*
        /bin/chown root:www-data /var/www/html
        /bin/chmod 750 /var/www/html
        /bin/chown root:www-data ${webroot_directory}
        /bin/chmod 770 ${webroot_directory}

        if ( [ -f ${webroot_directory}/adt-probe.php ] )
        then
	        /bin/chmod 440  ${webroot_directory}/adt-probe.php
        fi
fi
