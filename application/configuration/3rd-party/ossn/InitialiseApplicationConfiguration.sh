#!/bin/sh
###########################################################################################################
# Description:
# This script will generate the configuration files 
#
#       ${webroot_directory}/configurations/ossn.config.db.php
#       ${webroot_directory}/configurations/ossn.config.db.php
#
# Using the values set in:
#
#        ${BUILD_HOME}/application/3rd-party/ossn/descriptor.dat
#
# If a virgin copy of ossn is being installed, then, the database is imported from installation/sql/opensource-socialnetwork.sql
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin ossn application. 
# If you are deploying a baseline or a temporal backup then the configuration.php file is manually generated
# based on the values set in 
#
#        ${BUILD_HOME}/application/3rd-party/ossn/descriptor.dat
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
        /bin/cp ${webroot_directory}/configurations/ossn.config.db.example.php /var/www/html/ossn.config.db.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.config.db.php.default
fi

config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/html/ossn.config.db.php"
fi

if ( [ -f ${webroot_directory}/ossn.config.db.php ] )
then
        /bin/rm ${webroot_directory}/ossn.config.db.php
fi

config_file_site="`/bin/grep "^CONFIG_FILE_SITE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file_site}" = "" ] )
then
        config_file_site="/var/www/html/ossn.site.db.php"
fi

if ( [ -f ${webroot_directory}/ossn.config.site.php ] )
then
        /bin/rm ${webroot_directory}/ossn.config.site.php
fi

if ( [ -f ${webroot_directory}/configurations/ossn.config.site.example.php ] )
then
        /bin/cp ${webroot_directory}/configurations/ossn.config.site.example.php /var/www/html/ossn.config.site.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.config.site.php.default
fi

dbprefix="ossn_"
/bin/echo "${dbprefix}" > /var/www/html/dbp.dat
/bin/chown www-data:www-data /var/www/html/dbp.dat

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        if ( [ ! -f ${webroot_directory}/ossn.config.db.php ] || [ ! -f ${webroot_directory}/ossn.site.db.php ] )
        then
                while ( [ ! -f ${webroot_directory}/ossn.config.db.php ] || [ ! -f ${webroot_directory}/ossn.site.db.php ] )
                do
                        /bin/sleep 1
                done
        fi
else
        if ( [ -f ${config_file} ] )
        then
                /bin/rm ${config_file}
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:DBaaS`" = "1" ] )
        then
                HOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'DBIDENTIFIER'`"
        else
                HOST="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "databaseip/*"`"
        fi
        DB_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'DBPORT'`"

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:DBaaS`" = "1" ] )
        then
                HOST="`${HOME}/utilities/config/ExtractConfigValue.sh 'DBIDENTIFIER'`"
        else
                HOST="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "databaseip/*"`"
        fi

        if ( [ -f ${HOME}/runtime/application.dat ] )
        then
                if ( [ ! -d ${HOME}/runtime/filesystem_sync/webroot-sync/outgoing ] )
                then
                        /bin/mkdir -p ${HOME}/runtime/filesystem_sync/webroot-sync/outgoing
                fi

                if ( [ -f ${HOME}/runtime/filesystem_sync/webroot-sync/outgoing/exclusion_list.dat ] )
                then
                        /bin/rm ${HOME}/runtime/filesystem_sync/webroot-sync/outgoing/exclusion_list.dat
                fi

                for directory in `/bin/grep "^DIRECTORIES_TO_CREATE:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_TO_CREATE://g' | /bin/sed 's/:/ /g'`
                do
                        directory="/var/www/html/${directory}"

                        if ( [ ! -d ${directory} ] )
                        then
                                /bin/mkdir -p ${directory}
                                /bin/echo "${directory}" >> ${HOME}/runtime/filesystem_sync/webroot-sync/outgoing/exclusion_list.dat
                        fi

                        while ( [ "${directory}" != "/var/www/html" ] )
                        do
                                /bin/chmod 755 ${directory}
                                /bin/chown www-data:www-data ${directory}
                                directory=`/usr/bin/dirname "${directory}"`
                        done
                done
        fi


        if ( [ -f /var/www/html/ossn.config.db.php.default ] && [ ! -f ${config_file} ] )
        then
                /bin/cp /var/www/html/ossn.config.db.php.default ${config_file}
                /bin/chown www-data:www-data ${config_file}
                /bin/chmod 400 ${config_file}
        else
                if ( [ ! -f  ${HOME}/runtime/CONFIG_EMAIL_SENT ] )
                then
                        ${HOME}/services/email/SendEmail.sh "DEFAULT CONFIGURATION FILE ABSENT" "Default joomla configuration file is absent" "ERROR"
                        /bin/touch ${HOME}/runtime/CONFIG_EMAIL_SENT
                        exit
                fi
        fi

        if ( [ -f /var/www/html/ossn.config.site.php.default ] && [ ! -f ${config_file} ] )
        then
                /bin/cp /var/www/html/ossn.config.site.php.default ${config_file}
                /bin/chown www-data:www-data ${config_file}
                /bin/chmod 400 ${config_file}
        else
                if ( [ ! -f  ${HOME}/runtime/CONFIG_SITE_EMAIL_SENT ] )
                then
                        ${HOME}/services/email/SendEmail.sh "DEFAULT CONFIGURATION FILE ABSENT" "Default joomla configuration file is absent" "ERROR"
                        /bin/touch ${HOME}/runtime/CONFIG_SITE_EMAIL_SENT
                        exit
                fi
        fi

        user="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:user=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
        password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
        dbname="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:db=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                type="mysqli"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                type="mysqli"
        fi

        /bin/sed -i "s%<<host>>%${HOST}%" ${config_file}
        /bin/sed -i "s%<<port>>%${DB_PORT}%" ${config_file}
        /bin/sed -i "s%<<user>>%${user}%" ${config_file}
        /bin/sed -i "s%<<password>>%${password}%" ${config_file}
        /bin/sed -i "s%<<dbname>>%${dbname}%" ${config_file}

        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"

        /bin/sed -i "s%<<siteurl>>%https://${WEBSITE_URL}/%" ${config_file_site}

        data_directory="`/bin/grep "^DATA_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

        /bin/sed -i "s%<<datadir>>%${data_directory}/%" ${config_file_site}

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                ${HOME}/utilities/remote/ConnectToRemoteMySQL.sh < ${webroot_directory}/installation/sql/opensource-socialnetwork.sql
                /bin/sed -i '0,/requirments/{s//account/}' ${webroot_directory}/installation/libraries/ossn.install.php
        else
                /bin/touch ${webroot_directory}/installation/INSTALLED
                /bin/chown www-data:www-data ${webroot_directory}/installation/INSTALLED
        fi
fi

#This is how we tell ourselves this is a the Open Source Social Network  application
/bin/echo "OSSN" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

if ( [ ! -f ${webroot_directory}/.htaccess ] )
then
        /bin/sed -i 's/order allow,deny/Require all granted/g' ${webroot_directory}/installation/configs/htaccess.dist
        /bin/sed -i 's/deny from all//g' ${webroot_directory}/installation/configs/htaccess.dist
        /bin/cp ${webroot_directory}/installation/configs/htaccess.dist ${webroot_directory}/.htaccess 
        /bin/chown www-data:www-data ${webroot_directory}/.htaccess 
        /bin/chmod 440 ${webroot_directory}/.htaccess
fi

if ( [ -f ${webroot_directory}/ossn.config.db.php ] )
then
        /bin/mv ${webroot_directory}/ossn.config.db.php ${config_file}
        /bin/chown www-data:www-data ${config_file}
        /bin/chown 740 ${config_file}
fi

/bin/echo "<?php require( '${config_file}' ); ?>" > ${webroot_directory}/configurations/ossn.config.db.php
/bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.db.php
/bin/chmod 440 ${webroot_directory}/configurations/ossn.config.db.php

if ( [ -f ${webroot_directory}/ossn.config.site.php ] )
then
        /bin/mv ${webroot_directory}/ossn.config.site.php ${config_file}
        /bin/chown www-data:www-data ${config_file}
        /bin/chown 740 ${config_file}
fi

/bin/echo "<?php require( '${config_file_site}' ); ?>" > ${webroot_directory}/configurations/ossn.config.site.php
/bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.site.php
/bin/chmod 440 ${webroot_directory}/configurations/ossn.config.site.php

#For ease of use we tell ourselves what database engine this webroot is associated with
if ( [ ! -f /var/www/html/dbe.dat ] || [ "`/bin/cat /var/www/html/dbe.dat`" = "" ] )
then
        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                /bin/echo "For your information this application requires Maria DB as its database" > /var/www/html/dbe.dat
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                /bin/echo "For your information this application requires MySQL as its database" > /var/www/html/dbe.dat
        fi

        if ( [ -f /var/www/html/dbe.dat ] )
        then
                /bin/chown www-data:www-data /var/www/html/dbe.dat
                /bin/chmod 600 /var/www/html/dbe.dat
        fi
fi

/usr/bin/php -ln ${config_file}

if ( [ "$?" = "0" ] )
then
        /bin/chmod 600 ${config_file}
        /bin/chown www-data:www-data ${config_file}
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET
fi

/usr/bin/php -ln ${config_file_site}

if ( [ "$?" != "0" ] )
then
        /bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET
fi

if ( [ ! -f  ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy ossn configuration file to the live location during application initiation" "ERROR"
fi
