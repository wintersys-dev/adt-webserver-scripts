#!/bin/sh
###########################################################################################################
# Description:This script will generate a /var/www/html/wp-config.php using the values that you have set in
#
#        ${BUILD_HOME}/application/descriptors/wordpress.dat
#
# If a virgin copy of wordpress is being installed, then, /usr/local/bin/wp is used
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin wordpress application. 
# If you are deploying a baseline or a temporal backup then the configuration.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/wordpress.dat
#
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

if ( [ ! -d ${HOME}/logs/wordpress_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/wordpress_configuration
fi

log_file="wordpress_configuration_out"
err_file="wordpress_configuration_err"

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/wordpress_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/wordpress_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/wordpress_configuration/${log_file}
exec 2>>${HOME}/logs/wordpress_configuration/${err_file}


if ( [ ! -f ${HOME}/runtime/application.dat ] )
then
	exit
fi

#Extract the value of the webroot directory from the application descriptor and if its not set, fall back to a default value
webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ -f /var/www/html/wr.dat ] )
then
        archived_webroot_directory="`/bin/cat /var/www/html/wr.dat`"
fi

if ( [ "${webroot_directory}" != "${archived_webroot_directory}" ] && [ "${archived_webroot_directory}" != "" ] )
then
        webroot_directory="${archived_webroot_directory}"
fi

if ( [ "${webroot_directory}" = "" ] )
then
        webroot_directory="/var/www/html/wordpress"
fi

#Take our own copy of the default configuration file which will still be available to work with on subsquent deployments when the
#installation folder is no longer available to work with
if ( [ -f ${webroot_directory}/installation/configuration.php-dist ] )
then
        /bin/cp ${webroot_directory}/installation/configuration.php-dist /var/www/html/configuration.php.default
        /bin/chown www-data:www-data /var/www/html/configuration.php.default
fi

#Create the standard ourside webroot folder which is used throughout the toolkit as the directory outside of the webroot where
#parts of the system that require dynamic access by users and admins are separated and secured away from the core system
if ( [ ! -d /var/www/outside_webroot ] )
then
        /bin/mkdir /var/www/outside_webroot
        /bin/chown www-data:www-data /var/www/outside_webroot
        /bin/chmod 750 /var/www/outside_webroot
fi
