#!/bin/sh
###########################################################################################################
# Description:This script will generate a /var/www/html/ossn.config.db.php and /var/www/html/ossn.site.db.php 
# using the values that you have set in
#
#        ${BUILD_HOME}/application/3rd-party/descriptors/ossn.dat
#
# CHANGE THIS PART****************************
# If a virgin copy of ossn is being installed, then, /usr/bin/php /var/www/html/installation/joomla.php is used
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin joomla application. 
# If you are deploying a baseline or a temporal backup then the configuration.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/joomla.dat
# CHANGE THIS PART****************************
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
set -x 

if ( [ ! -d ${HOME}/logs/application_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/application_configuration
fi

exec 1>>${HOME}/logs/application_configuration/ossn_out.log
exec 2>>${HOME}/logs/application_configuration/ossn_err.log

webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${webroot_directory}" = "" ] )
then
        webroot_directory="/var/www/html/ossn"
fi

if ( [ -f ${webroot_directory}/configurations/ossn.config.db.example.php ] )
then
        ${webroot_directory}/configurations/ossn.config.db.example.php /var/www/html/ossn.config.db.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.config.db.php.default
fi

config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/html/ossn.config.db.php"
fi

if ( [ -f ${webroot_directory}/configurations/ossn.config.db.php ] )
then
        /bin/rm ${webroot_directory}/configurations/ossn.config.db.php
fi

if ( [ -f ${webroot_directory}/configurations/ossn.site.db.example.php ] )
then
        ${webroot_directory}/configurations/ossn.site.db.example.php /var/www/html/ossn.site.db.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.site.db.php.default
fi

config_file_site="`/bin/grep "^CONFIG_FILE_SITE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file_site}" = "" ] )
then
        config_file_site="/var/www/html/ossn.site.db.php"
fi

if ( [ -f ${webroot_directory}/configurations/ossn.site.db.php ] )
then
        /bin/rm  ${webroot_directory}/configurations/ossn.site.db.php
fi
