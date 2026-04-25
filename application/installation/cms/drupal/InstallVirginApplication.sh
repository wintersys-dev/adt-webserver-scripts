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

if ( [ ! -d ${HOME}/logs/application_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/application_installation
fi

exec 1>>${HOME}/logs/application_installation/drupal_out.log
exec 2>>${HOME}/logs/application_installation/drupal_err.log

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "`/bin/grep "^APPLICATION_TYPE:drupal" ${HOME}/runtime/application.dat`" != "" ] )
then
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        drupal_version="`/bin/grep "^DRUPAL_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^DRUPAL_VERSION://g'`"
        /usr/bin/sudo -u www-data /usr/local/bin/composer create-project ${drupal_version} /var/www/html --no-interaction --no-install
        /bin/sed -i 's;web/;drupal/;g' /var/www/html/composer.json
        cd /var/www/html
        /usr/bin/sudo -u www-data /usr/local/bin/composer install
        /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/bin/drush.php' > /usr/sbin/drush
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/drush/drush/drush' >> /usr/sbin/drush
        /bin/echo '/usr/bin/php /var/www/html/vendor/bin/drush.php $@' >> /usr/sbin/drush
        module_list="`/bin/grep "^DRUPAL_MODULES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed 's/DRUPAL_MODULES_TO_INSTALL://g' | /bin/sed 's/:/ /g'`"

        if ( [ "${modules_list}" != "" ] )
        then
                for module in "${modules_list}"
                do
                        /usr/bin/sudo -u www-data /usr/local/bin/composer require drupal/${module}
                        /usr/sbin/drush en ${module} -y
                done
        fi

        theme_list="`/bin/grep "^DRUPAL_THEMES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed 's/DRUPAL_THEMES_TO_INSTALL://g' | /bin/sed 's/:/ /g'`"

        if ( [ "${theme_list}" != "" ] )
        then
                for theme in "${theme_list}"
                do
                        /usr/bin/sudo -u www-data /usr/local/bin/composer require drupal/${theme}
                        /usr/sbin/drush en ${theme} -y
                done
        fi

        cd ${HOME}
        /bin/echo "success"
elif ( [ "`/bin/grep "^APPLICATION_TYPE:cms" ${HOME}/runtime/application.dat`" != "" ] )
then
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        cms_version="`/bin/grep "^CMS_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^CMS_VERSION://g'`"
        /usr/bin/sudo -u www-data /usr/local/bin/composer create-project ${cms_version} /var/www/html --no-interaction --no-install
        /bin/sed -i 's;web/;drupal/;g' /var/www/html/composer.json
        cd /var/www/html
        /usr/bin/sudo -u www-data /usr/local/bin/composer install
        /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/bin/drush.php' > /usr/sbin/drush
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/drush/drush/drush' >> /usr/sbin/drush
        /bin/echo '/usr/bin/php /var/www/html/vendor/bin/drush.php $@' >> /usr/sbin/drush

        module_list="`/bin/grep "^CMS_MODULES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed 's/CMS_MODULES_TO_INSTALL://g' | /bin/sed 's/:/ /g'`"

        if ( [ "${modules_list}" != "" ] )
        then
                for module in "${modules_list}"
                do
                        /usr/bin/sudo -u www-data /usr/local/bin/composer require drupal/${module}
                done
        fi

        theme_list="`/bin/grep "^CMS_THEMES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed 's/CMS_THEMES_TO_INSTALL://g' | /bin/sed 's/:/ /g'`"

        if ( [ "${theme_list}" != "" ] )
        then
                for theme in "${theme_list}"
                do
                        /usr/bin/sudo -u www-data /usr/local/bin/composer require drupal/${theme}
                done
        fi
        
        cd ${HOME}
        /bin/echo "success"
elif ( [ "`/bin/grep "^APPLICATION_TYPE:droopler" ${HOME}/runtime/application.dat`" != "" ] )
then
        cd ${HOME}
        BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
        ${HOME}/installation/InstallComposer.sh ${BUILDOS}
        /bin/rm -r /var/www/*
        /bin/chown www-data:www-data /var/www
        droopler_project="`/bin/grep "^DROOPLER_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^DROOPLER_VERSION://g' | /usr/bin/awk -F':' '{print $1}'`"
        droopler_version="`/bin/grep "^DROOPLER_VERSION:" ${HOME}/runtime/application.dat | /bin/sed 's/^DROOPLER_VERSION://g' | /usr/bin/awk -F':' '{print $2}'`"
        /bin/mkdir -p /var/www/html
        /bin/chown www-data:www-data /var/www/html
        cd /var/www/html
        /usr/bin/sudo -u www-data /usr/local/bin/composer create-project ${droopler_project} --no-interaction --no-install /var/www/html
        /usr/bin/sudo -u www-data /usr/local/bin/composer update ${droopler_project}  
        /bin/sed -i 's;web/;drupal/;g' /var/www/html/composer.json
        /usr/bin/yes | /usr/bin/sudo -u www-data /usr/local/bin/composer install
        /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/bin/drush.php' > /usr/sbin/drush
        /bin/echo '/bin/chmod 755 /var/www/html/vendor/drush/drush/drush' >> /usr/sbin/drush
        /bin/echo '/usr/bin/php /var/www/html/vendor/bin/drush.php $@' >> /usr/sbin/drush
        /bin/cp -r /var/www/html/web* /var/www/html/drupal
        /bin/rm -r /var/www/html/web
fi
