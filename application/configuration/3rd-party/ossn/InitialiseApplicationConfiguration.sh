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
#
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
set -x 

if ( [ ! -d ${HOME}/logs/ossn_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/ossn_configuration
fi

log_file="ossn_configuration_out"
err_file="ossn_configuration_err"

if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/ossn_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/ossn_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/ossn_configuration/${log_file}
exec 2>>${HOME}/logs/ossn_configuration/${err_file}

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
        webroot_directory="/var/www/html/ossn"
fi

if ( [ -f ${webroot_directory}/configurations/ossn.config.db.example.php ] )
then
        /bin/cp ${webroot_directory}/configurations/ossn.config.db.example.php /var/www/html/ossn.config.db.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.config.db.php.default
fi

if ( [ -f ${webroot_directory}/configurations/ossn.config.site.example.php ] )
then
        /bin/cp ${webroot_directory}/configurations/ossn.config.site.example.php /var/www/html/ossn.config.site.php.default
        /bin/chown www-data:www-data /var/www/html/ossn.config.site.php.default
fi

if ( [ ! -d /var/www/outside_webroot ] )
then
        /bin/mkdir /var/www/outside_webroot
        /bin/chown www-data:www-data /var/www/outside_webroot
        /bin/chmod 750 /var/www/outside_webroot
fi

data_directory="`/bin/grep "^DATA_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ ! -d ${data_directory} ] )
then
        /bin/mkdir -p  ${data_directory}
        /bin/chown www-data:www-data ${data_directory}
        /bin/chmod 750 ${data_directory}
fi

config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/outside_webroot/ossn.config.db.php"
fi

if ( [ -f ${config_file} ] )
then
        /bin/rm ${config_file}
fi

if ( [ -f ${webroot_directory}/ossn.config.db.php ] ) 
then
        /bin/rm ${webroot_directory}/ossn.config.db.php
fi

config_file_site="`/bin/grep "^CONFIG_FILE_SITE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file_site}" = "" ] )
then
        config_file_site="/var/www/outside_webroot/ossn.site.db.php"
fi

if ( [ -f ${webroot_directory}/ossn.config.site.php ] )
then
        /bin/rm ${webroot_directory}/ossn.config.site.php
fi

# Make sure that the session save path directory is set and exists as sometimes this causes an issue if its not set correctly
session_save_path="`/bin/grep "^CONFIG_PHP_INI:" ${HOME}/runtime/application.dat | /bin/sed 's/:/ /g' | /bin/grep -o '[^[:space:]]*session.save_path[^[:space:]]*' | /usr/bin/awk -F'=' '{print $NF}'`"

if ( [ ! -d ${session_save_path} ] )
then
        /bin/mkdir -p ${session_save_path}
        /bin/chown www-data:www-data ${session_save_path}
        /bin/chmod 770 ${session_save_path}
fi

dbprefix="ossn_"
/bin/echo "${dbprefix}" > /var/www/html/dbp.dat
/bin/chown www-data:www-data /var/www/html/dbp.dat

#Find out where our database server is
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

tls_suffix="_notls"

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:DBaaS`" = "1" ] )
then
        tls_suffix=""
        /bin/cp ${HOME}/application/configuration/3rd-party/ossn/tls_enable.php ${HOME}/runtime/tls_enable.php

        PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION' | /bin/sed 's/\.//g'`"
        
        #PHP 8.5 and above
        #Pdo\Mysql::ATTR_SSL_VERIFY_SERVER_CERT => true,
        #PHP 8.4 and below
        # \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true 

        if ( [ "${PHP_VERSION}" -ge "85" ] )
        then
                /bin/sed -i '/XXXXPHP8.4_AND_DOWNXXXX/d' ${HOME}/runtime/tls_enable.php 
                /bin/sed -i 's/XXXXPHP8.5_AND_UPXXXX//g' ${HOME}/runtime/tls_enable.php 
        else 
                /bin/sed -i '/XXXXPHP8.5_AND_UPXXXX/d' ${HOME}/runtime/tls_enable.php 
                /bin/sed -i 's/XXXXPHP8.4_AND_DOWNXXXX//g' ${HOME}/runtime/tls_enable.php 
        fi

        /bin/sed -i '/ATTR_SSL_CA/d' ${webroot_directory}/classes/OssnDatabase.php
        /bin/sed -i '/ATTR_SSL_VERIFY_SERVER_CERT/d' ${webroot_directory}/classes/OssnDatabase.php

        /bin/sed -i "s;XXXXHOMEXXXX;${HOME};" ${HOME}/runtime/tls_enable.php
        /bin/sed -i "/PDO::ATTR_EMULATE_PREPARES   => false,/ r ${HOME}/runtime/tls_enable.php" ${webroot_directory}/classes/OssnDatabase.php
        /bin/rm ${HOME}/runtime/tls_enable.php
fi

user="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:user=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`${tls_suffix}"
password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
dbname="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:db=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
website_username="`/bin/grep "^WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
website_password="`/bin/grep "^WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
webmaster_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        if ( [ ! -f ${webroot_directory}/configurations/ossn.config.db.php ] || [ ! -f ${webroot_directory}/configurations/ossn.config.site.db.php ] )
        then
                while ( [ ! -f ${webroot_directory}/configurations/ossn.config.db.php ] || [ ! -f ${webroot_directory}/configurations/ossn.config.site.db.php ] )
                do
                        /bin/sleep 1
                done
        fi
else
        /bin/cp /var/www/html/ossn.config.db.php.default ${config_file}
        /bin/chown www-data:www-data ${config_file}
        /bin/chmod 400 ${config_file}

        /bin/cp /var/www/html/ossn.config.site.php.default ${config_file_site}
        /bin/chown www-data:www-data ${config_file_site}
        /bin/chmod 400 ${config_file_site}

        /bin/sed -i "s%<<host>>%${HOST}%" ${config_file}
        /bin/sed -i "s%<<port>>%${DB_PORT}%" ${config_file}
        /bin/sed -i "s%<<user>>%${user}%" ${config_file}
        /bin/sed -i "s%<<password>>%${password}%" ${config_file}
        /bin/sed -i "s%<<dbname>>%${dbname}%" ${config_file}
        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        /bin/sed -i "s%<<siteurl>>%https://${WEBSITE_URL}/%" ${config_file_site}
        /bin/sed -i "s%<<datadir>>%${data_directory}/%" ${config_file_site}

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                sitename="`/bin/grep "^WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                /bin/sed -i "s/<<sitename>>/${sitename}/" ${webroot_directory}/installation/sql/opensource-socialnetwork.sql
                owner_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                /bin/sed -i "s/<<owner_email>>/${owner_email}/" ${webroot_directory}/installation/sql/opensource-socialnetwork.sql
                notification_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                /bin/sed -i "s/<<notification_email>>/${notification_email}/" ${webroot_directory}/installation/sql/opensource-socialnetwork.sql
                /bin/cp ${HOME}/application/configuration/3rd-party/ossn/non-interactive.php ${HOME}/runtime/non-interactive.php
                /bin/sed -i "/^\$errors.*/ r ${HOME}/runtime/non-interactive.php" ${webroot_directory}/actions/administrator/settings/save/basic.php
                /bin/rm ${HOME}/runtime/non-interactive.php
                ${HOME}/utilities/remote/ConnectToRemoteMySQL.sh < ${webroot_directory}/installation/sql/opensource-socialnetwork.sql
                /bin/sed -i '0,/requirments/{s//account/}' ${webroot_directory}/installation/libraries/ossn.install.php
                /bin/cp ${HOME}/application/configuration/3rd-party/ossn/bootstrap_admin_user.php ${webroot_directory}/bootstrap_admin_user.php
                /bin/sed -i "s/XXXXWEBMASTER_USERNAMEXXXX/${website_username}/" ${webroot_directory}/bootstrap_admin_user.php
                /bin/sed -i "s;XXXXWEBMASTER_PASSWORDXXXX;${website_password};" ${webroot_directory}/bootstrap_admin_user.php
                /bin/sed -i "s/XXXXWEBMASTER_EMAILXXXX/${webmaster_email}/" ${webroot_directory}/bootstrap_admin_user.php
                cwd="`/usr/bin/pwd`"
                cd ${webroot_directory}
                /bin/cp ${config_file} ${webroot_directory}/configurations/ossn.config.db.php && /bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.db.php
                /bin/cp ${config_file_site} ${webroot_directory}/configurations/ossn.config.site.php && /bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.site.php
                /usr/bin/php ${webroot_directory}/bootstrap_admin_user.php
                /bin/rm ${webroot_directory}/bootstrap_admin_user.php
                /bin/rm ${webroot_directory}/configurations/ossn.config.db.php
                /bin/rm ${webroot_directory}/configurations/ossn.config.site.php
                cd ${cwd}
        fi


fi

#This is how we tell ourselves this is a the Open Source Social Network  application
/bin/echo "OSSN" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

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

/bin/echo "${webroot_directory}" > /var/www/html/wr.dat
/bin/chown www-data:www-data /var/www/html/wr.dat

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
fi


/bin/echo "<?php require( '${config_file}' ); ?>" > ${webroot_directory}/configurations/ossn.config.db.php
/bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.db.php
/bin/chmod 600 ${webroot_directory}/configurations/ossn.config.db.php
/bin/chown www-data:www-data ${config_file}
/bin/chmod 600 ${config_file}

if ( [ -f ${webroot_directory}/ossn.config.site.php ] )
then
        /bin/mv ${webroot_directory}/ossn.config.site.php ${config_file}
fi

/bin/echo "<?php require( '${config_file_site}' ); ?>" > ${webroot_directory}/configurations/ossn.config.site.php
/bin/chmod 600 ${webroot_directory}/configurations/ossn.config.site.php
/bin/chown www-data:www-data ${webroot_directory}/configurations/ossn.config.site.php
/bin/chown www-data:www-data ${config_file}
/bin/chmod 600 ${config_file}

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" != "1" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:baseline`" != "1" ] )
then
        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:0`" != "1" ] )
        then
                assets_directories_to_link="`/bin/grep "^ASSET_DIRECTORIES_LINKED_OUTSIDE_WEBROOT:" ${HOME}/runtime/application.dat | /bin/sed 's/ASSET_DIRECTORIES_LINKED_OUTSIDE_WEBROOT://g' | /bin/sed 's/:/ /g'`"
                for asset_directory in ${assets_directories_to_link}
                do
                        link_directory="${webroot_directory}/${asset_directory}"
                        outside_webroot_directory="/var/www/outside_webroot/${asset_directory}"

                        if ( [ -L ${link_directory} ] )
                        then
                                /usr/bin/unlink ${link_directory}
                        fi

                        if ( [ -d ${link_directory} ] )
                        then
                                if ( [ ! -d ${outside_webroot_directory} ] )
                                then
                                        /bin/mkdir -p ${outside_webroot_directory}
                                fi
                                /bin/mv ${link_directory}/* ${outside_webroot_directory}
                                /bin/rm -r ${link_directory}
                        else
                                /bin/mkdir -p ${outside_webroot_directory}
                        fi

                        /bin/chown -R www-data:www-data ${outside_webroot_directory}
                        /bin/chmod 750 ${outside_webroot_directory}
                        /bin/ln -s ${outside_webroot_directory} ${link_directory}
                done
        fi
fi

directories="`/bin/grep "^DIRECTORIES_LINKED_OUTSIDE_WEBROOT:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_LINKED_OUTSIDE_WEBROOT://g' | /bin/sed 's/:/ /g'`"
for directory in ${directories}
do
        if ( [ ! -d /var/www/outside_webroot/${directory} ] )
        then
                /bin/mkdir -p /var/www/outside_webroot/${directory}
                /bin/chown www-data:www-data /var/www/outside_webroot/${directory}
                /bin/chmod 750 /var/www/outside_webroot/${directory}
        fi

        if ( [ -f ${webroot_directory}/${directory} ] )
        then
                /bin/rm ${webroot_directory}/${directory} 
        fi

        if ( [ -L ${webroot_directory}/${directory} ] )
        then
                /bin/unlink ${webroot_directory}/${directory} 
        fi

        /bin/ln -s /var/www/outside_webroot/${directory} ${webroot_directory}/${directory}
done


directories="`/bin/grep "^DIRECTORIES_OUTSIDE_WEBROOT:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_OUTSIDE_WEBROOT://g' | /bin/sed 's/:/ /g'`"

for directory in ${directories}
do
        if ( [ ! -d /var/www/outside_webroot/${directory} ] )
        then
                /bin/mkdir -p /var/www/outside_webroot/${directory}
                /bin/chown www-data:www-data /var/www/outside_webroot/${directory}
                /bin/chmod 750 /var/www/outside_webroot/${directory}
        fi
done

#As I said we expect all files that our outside of the webroot to be accessible and updatable by the user that the webserver is running as www-data
/bin/chown -R www-data:www-data  /var/www/outside_webroot


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

        if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
        then
                /bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
        fi
else
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
fi

/usr/bin/php -ln ${config_file_site}

if ( [ "$?" = "0" ] && [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/chmod 600 ${config_file_site}
        /bin/chown www-data:www-data ${config_file_site}
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET

        if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
        then
                /bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
        fi
else
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
fi

if ( [ ! -f  ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy ossn configuration file to the live location during application initiation" "ERROR"
fi
