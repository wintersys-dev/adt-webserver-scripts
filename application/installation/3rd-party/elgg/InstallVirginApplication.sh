#!/bin/sh
###################################################################################
# Description: This script will obtain and extract the sourcecode for elgg into 
# the webroot directory
# Author: Peter Winter
# Date: 04/01/2017
##################################################################################
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
#################################################################################
#################################################################################
#set -x

if ( [ ! -d ${HOME}/logs/application_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/application_installation
fi

exec 1>>${HOME}/logs/application_installation/elgg_out.log
exec 2>>${HOME}/logs/application_installation/elgg_err.log

HOME="`/bin/cat /home/homedir.dat`"

cd ${HOME}
BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
${HOME}/installation/InstallComposer.sh ${BUILDOS}
/bin/rm -r /var/www/*
/bin/chown www-data:www-data /var/www
/usr/bin/sudo -u www-data /usr/local/bin/composer create-project elgg/starter-project /var/www/html --no-interaction --no-install
cd /var/www/html
/usr/bin/sudo -u www-data /usr/local/bin/composer install
cd ${HOME}
/bin/echo "success"

