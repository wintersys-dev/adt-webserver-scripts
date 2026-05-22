#!/bin/sh
######################################################################################
# Author: Peter Winter
# Date :  07/07/2016
# Description: Check if the assets directories are mounted - essential for integrity
# of the build. This is called from the build machine at the end of the build process
#####################################################################################
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
#######################################################################################
#######################################################################################
#set -x

mounted=""

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:0`" = "1" ] && [ "${mounted}" = "1" ] )
then
        mounted="MOUNTED"
else
        assets_directories=""
        assets_directories="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"
        mounted=""
        if ( [ "${assets_directories}" != "" ] )
        then
                for directory in ${assets_directories}
                do
                        mounted="MOUNTED"
                        if ( [ "`/bin/mount | /bin/grep -P "/var/www/html/${directory}(?=\s|$)"`" = "" ] || [ ! -f /var/www/html/${directory}/ASSETS_SUCCESSFULLY_MOUNTED ] )
                        then
                                mounted=""
                        fi
                done
        else
                mounted="MOUNTED"
        fi
fi

/bin/echo ${mounted}
