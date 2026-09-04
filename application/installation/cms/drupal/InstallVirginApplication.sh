#!/bin/sh
###################################################################################
# Description: This script will obtain and extract the sourcecode for drupal into 
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

HOME="`/bin/cat /home/homedir.dat`"
PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"

webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${webroot_directory}" = "" ] )
then
        webroot_directory="/var/www/html/drupal"
fi

verify_php_version ()
{
        if ( [ -f ${webroot_directory}/composer.lock ] )
        then
                minimum_required_php_version="`/bin/grep '"php":' ${webroot_directory}/composer.lock | /bin/grep '>=' | /usr/bin/cut -d'"' -f4 | /bin/sed 's/.*=//g' | /usr/bin/awk  -F'.' 'BEGIN{OFS="."} {print $1,$2}' | /bin/sed 's/\.//g' | /usr/bin/sort -n | /usr/bin/tail -1`"

                if ( [ "${minimum_required_php_version}" != "" ] )
                then
                        minimum_required_php_version="`/bin/echo ${minimum_required_php_version} | /usr/bin/cut -c1-1`.`/bin/echo ${minimum_required_php_version} | /usr/bin/cut -c2-2`"

                        if ( [ "`/bin/echo ${PHP_VERSION} | /bin/sed 's/\.//g'`" -lt "`/bin/echo ${minimum_required_php_version} | /bin/sed 's/\.//g'`" ] )
                        then
                                /bin/echo "Your PHP_VERSION is ${PHP_VERSION} and the minimum PHP version is set to ${minimum_required_php_version}"
                                exit
                        fi
                fi
        fi

}

if ( [ "`/bin/grep "^APPLICATION_TYPE:drupal" ${HOME}/runtime/application.dat`" != "" ] )
then
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        drupal_version="`/bin/grep "^DRUPAL_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^DRUPAL_VERSION://g'`"
        /usr/bin/sudo -u www-data /usr/local/bin/composer create-project ${drupal_version} ${webroot_directory} --no-interaction --no-install
        verify_php_version
        cd ${webroot_directory}
        /usr/bin/sudo -u www-data /usr/local/bin/composer install
        /usr/bin/sudo -u www-data /usr/local/bin/composer require goalgorilla/open_social --with-all-dependencies

        ${HOME}/installation/InstallDrush.sh ${BUILDOS}

        cd ${HOME}
        /bin/echo "DRUPAL" > /var/www/html/dbt.dat
        /bin/echo "success"

elif ( [ "`/bin/grep "^APPLICATION_TYPE:cms" ${HOME}/runtime/application.dat`" != "" ] )
then
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
  
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        cms_version="`/bin/grep "^CMS_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^CMS_VERSION://g'`"
        /usr/bin/sudo -u www-data /usr/local/bin/composer create-project ${cms_version} ${webroot_directory} --no-interaction --no-install
        verify_php_version
        cd ${webroot_directory}
        /usr/bin/sudo -u www-data /usr/local/bin/composer install
#this is needed for CMS version 1
      #  ${HOME}/installation/InstallDrush.sh ${BUILDOS}

        if ( [ -f ${webroot_directory}/vendor/bin/drush.php ] )
        then
                /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/bin/drush.php"> /usr/sbin/drush
                /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/drush/drush" >> /usr/sbin/drush
                /bin/echo "/usr/bin/php ${webroot_directory}/vendor/bin/drush.php \$@" >> /usr/sbin/drush
                /bin/chmod 750 /usr/sbin/drush
        fi

        cd ${HOME}
        /bin/echo "CMS_DRUPAL" > /var/www/html/dbt.dat
        /bin/echo "success"
#elif ( [ "`/bin/grep "^APPLICATION_TYPE:opensocial" ${HOME}/runtime/application.dat`" != "" ] )
#then
else 
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
  
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        ${HOME}/services/git/GitClone.sh "github" "" "goalgorilla" "open_social" "" "releese/13.0.0-stable" "${webroot_directory}"
        /bin/chown -R www-data:www-data /var/www/html
        verify_php_version
        cd ${webroot_directory}
        /usr/bin/sudo -u www-data /usr/local/bin/composer install
        ${HOME}/installation/InstallDrush.sh ${BUILDOS}

        cd ${HOME}
        /bin/echo "CMS_DRUPAL" > /var/www/html/dbt.dat
        /bin/echo "success"

fi
