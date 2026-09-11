#!/bin/sh
###########################################################################################################
# Description:This script will generate a /var/www/html/config.php using the values that you have set in
#
#        ${BUILD_HOME}/application/descriptors/moodle.dat
#
# If a virgin copy of moodle is being installed, then, /usr/bin/php /var/www/html/admin/cli/install_database.php is used
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin moodle application. 
# If you are deploying a baseline or a temporal backup then the config.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/moodle.dat
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


if ( [ ! -d ${HOME}/logs/moodle_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/moodle_configuration
fi

log_file="moodle_configuration_out"
err_file="moodle_configuration_err"

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/moodle_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/moodle_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/moodle_configuration/${log_file}
exec 2>>${HOME}/logs/moodle_configuration/${err_file}

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
        webroot_directory="/var/www/html/moodle"
fi

if ( [ -f ${webroot_directory}/config-dist.php ] )
then
        /bin/cp ${webroot_directory}/config-dist.php /var/www/html/config.php.default
        /bin/chown www-data:www-data /var/www/html/config.php.default
fi

if ( [ ! -d /var/www/outside_webroot ] )
then
        /bin/mkdir /var/www/outside_webroot
        /bin/chown www-data:www-data /var/www/outside_webroot
        /bin/chmod 750 /var/www/outside_webroot
fi

config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/html/config.php"
fi

if ( [ -f ${config_file} ] )
then
        /bin/rm ${config_file}
fi

if ( [ -f ${webroot_directory}/config.php ] )
then
        /bin/rm ${webroot_directory}/config.php
fi

# Make sure that the session save path directory is set and exists as sometimes this causes an issue if its not set correctly
session_save_path="`/bin/grep "^CONFIG_PHP_INI:" ${HOME}/runtime/application.dat | /bin/sed 's/:/ /g' | /bin/grep -o '[^[:space:]]*session.save_path[^[:space:]]*' | /usr/bin/awk -F'=' '{print $NF}'`"

if ( [ ! -d ${session_save_path} ] )
then
        /bin/mkdir -p ${session_save_path}
        /bin/chown www-data:www-data ${session_save_path}
        /bin/chmod 770 ${session_save_path}
fi

if ( [ -f /var/www/html/dbp.dat ] )
then
        dbprefix="`/bin/cat /var/www/html/dbp.dat`"
else
        dbprefix="adt`/usr/bin/tr -dc a-z </dev/urandom | /usr/bin/head -c 5; /bin/echo`_"
        /bin/echo ${dbprefix} > /var/www/html/dbp.dat
        /bin/chown www-data:www-data /var/www/html/dbp.dat
        /bin/chmod 600 /var/www/html/dbp.dat
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

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
then
        dbtype="mariadb"
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
then
        dbtype="mysqli"
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] )
then
        dbtype="pgsql"
fi

user="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:user=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
db="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:db=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
website_username="`/bin/grep "^WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
website_password="`/bin/grep "^WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
website_fullname="`/bin/grep "^WEBSITE_FULLNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
website_shortname="`/bin/grep "^WEBSITE_SHORTNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
webmaster_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
dbuser="`/bin/grep '^MANDATORY_INDIVIDUAL_SETTING:dbuser=' ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
dbpass="`/bin/grep '^MANDATORY_INDIVIDUAL_SETTING:dbpass=' ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
dbname="`/bin/grep '^MANDATORY_INDIVIDUAL_SETTING:dbname=' ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"

if ( [ -f ${webroot_directory}/config.php ] )
then
        /bin/rm ${webroot_directory}/config.php
fi

if ( [ -f /var/www/outside_webroot/config.php ] )
then
        /bin/rm /var/www/outside_webroot/config.php
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
then
        if ( [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
        then
                dbuser_orig="${dbuser}"
                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "0" ] )
                then
                        dbuser="${dbuser}_notls"
                fi

                PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
                /bin/sed -i 's/.*max_input_vars.*/max_input_vars = 6000/' /etc/php/${PHP_VERSION}/cli/php.ini
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"

                /usr/bin/php /var/www/html/moodle/admin/cli/install.php --skip-database --agree-license --non-interactive --adminuser="${website_username}" --adminpass="${website_password}" --adminemail="${webmaster_email}" --dbport="${DB_PORT}" --dbhost="${HOST}" --dbuser="${dbuser}" --dbpass="${dbpass}" --dbname="${dbname}" --dbtype="${dbtype}" --prefix="${dbprefix}" --wwwroot="https://${WEBSITE_URL}" --dataroot="${webroot_directory}/moodledata" --fullname="${website_fullname}" --shortname="${website_shortname}" --chmod=2750 

                if ( [ -f ${webroot_directory}/config.php ] )
                then
                        db_user=="${dbuser_orig}"
                        /bin/sed -i 's/_notls//g' ${webroot_directory}/config.php
                        /bin/sed -i "/\$CFG->dboptions/a     'ssl' => 'require'," ${webroot_directory}/config.php    
                fi

        else
                PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
                /bin/sed -i 's/.*max_input_vars.*/max_input_vars = 6000/' /etc/php/${PHP_VERSION}/cli/php.ini
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
                dbuser_orig="${dbuser}"
                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "0" ] )
                then
                        dbuser="${dbuser}_notls"
                fi
                /usr/bin/php /var/www/html/moodle/admin/cli/install.php --agree-license --non-interactive --adminuser="${website_username}" --adminpass="${website_password}" --adminemail="${webmaster_email}" --dbport="${DB_PORT}" --dbhost="${HOST}" --dbuser="${dbuser}" --dbpass="${dbpass}" --dbname="${dbname}" --dbtype="${dbtype}" --prefix="${dbprefix}" --wwwroot="https://${WEBSITE_URL}" --dataroot="/var/www/html/moodledata" --fullname="${website_fullname}" --shortname="${website_shortname}" --chmod=2750 

                if ( [ -f ${webroot_directory}/config.php ] )
                then
                        db_user="${dbuser_orig}"
                        /bin/sed -i 's/_notls//g' ${webroot_directory}/config.php
                        /bin/sed -i "/\$CFG->dboptions/a     'ssl' => 'require'," ${webroot_directory}/config.php    
                fi
        fi

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

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] )
                then
                        /bin/echo "For your information this application requires Postgres as its database" > /var/www/html/dbe.dat
                fi
        fi

        /bin/echo "`/bin/grep "\$CFG->prefix" ${webroot_directory}/config.php | /usr/bin/awk -F"'" '{print $2}'`" > /var/www/html/dbp.dat
        /bin/chown www-data:www-data /var/www/html/dbp.dat
else
        if ( [ -f /var/www/html/config.php.default ] )
        then
                /bin/cp /var/www/html/config.php.default ${config_file}
                /bin/chown www-data:www-data ${config_file}
                /bin/chmod 400 ${config_file}
        fi

        /bin/sed -i "s%\$CFG->dbuser.*$%\$CFG->dbuser = '${dbuser}';%" ${config_file}
        /bin/sed -i "s%\$CFG->dbpass.*$%\$CFG->dbpass = '${dbpass}';%" ${config_file}
        /bin/sed -i "s%\$CFG->dbname.*$%\$CFG->dbname = '${dbname}';%" ${config_file}
        /bin/sed -i "s%\$CFG->dbhost.*$%\$CFG->dbhost = '${HOST}';%" ${config_file}
        /bin/sed -i "s%\$CFG->prefix.*$%\$CFG->prefix = '${dbprefix}';%" ${config_file}
        /bin/sed -i "1,/dbport/s/.*dbport.*/'dbport'    => '${DB_PORT}',/"  ${config_file}
        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        /bin/sed -i "s%\$CFG->wwwroot.*$%\$CFG->wwwroot = 'https://${WEBSITE_URL}';%" ${config_file}
        /bin/sed -i "s%\$CFG->dataroot.*$%\$CFG->dataroot = '/var/www/html/moodledata';%" ${config_file}

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                /bin/sed -i 's/$CFG->dbtype.*$/$CFG->dbtype = "mariadb";/g' ${config_file}
        elif ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                /bin/sed -i 's/$CFG->dbtype.*$/$CFG->dbtype = "mysqli";/g' ${config_file}
        elif ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ])
        then
                /bin/sed -i 's/$CFG->dbtype.*$/$CFG->dbtype = "pgsql";/g' ${config_file}
        fi

        if ( [ -f ${HOME}/runtime/DBaaS_CERT ] )
        then
                /bin/echo "\$CFG->dboptions = array (
                        'dbpersist'         => false,
                        'dbsocket'          => false,
                        'dbcollation'       => 'utf8mb4_unicode_ci',
                        'dbport'            => '"${DB_PORT}"',
                        'dbhandlesoptions'  => false,
                        'ssl'               => 'verify_identity',   
                        'sslca'             => '"${HOME}"/runtime/DBaaS_CERT', 
                        'sslverify'         => true                                
                        );" > ${HOME}/runtime/dbaas_settings.dat

                        /usr/bin/perl -i -p0e 's/\$CFG->dboptions.*\);/XXXXDB_OPTIONSXXXX/s' ${webroot_directory}/config.php
                        /bin/sed -i -e "/XXXXDB_OPTIONSXXXX/{r ${HOME}/runtime/dbaas_settings.dat" -e 'd}' ${webroot_directory}/config.php
                        /bin/rm ${HOME}/runtime/dbaas_settings.dat
        fi

        APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION'`"
        if ( [ "`/bin/cat /var/www/html/dba.dat`" != "`/bin/echo ${APPLICATION} | /bin/tr '[:lower:]' '[:upper:]'`" ] )
        then 
                ${HOME}/services/email/SendEmail.sh "APPLICATION TYPE MISMATCH" "Your template thinks it is a different application type to your webroot" "ERROR"
        fi
fi

#This is how we tell ourselves this is a moodle application
/bin/echo "MOODLE" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat


#We are in a situation now where whatever type of install we are doing, virgin, baseline or temporal our configuration file is at ${config_file}
#which is ourside of our webroot. So we want to create a symlink from inside our webroot to the actual configuration file
if ( [ -f ${webroot_directory}/config.php ] )
then
        /bin/mv ${webroot_directory}/config.php ${config_file}
        /bin/chown www-data:www-data ${config_file}
        /bin/chmod 660 ${config_file}
        /bin/sed -i '/.*require_once.*/d' ${config_file}
        /bin/echo '$CFG->routerconfigured = true;' >> ${config_file}
        /bin/echo '$CFG->preventexecpath = true;' >> ${config_file}
        /bin/echo "require_once('"${webroot_directory}"/public/lib/setup.php');" >> ${config_file}
fi

/bin/echo "<?php require( '${config_file}' ); ?>" > ${webroot_directory}/config.php
/bin/chown www-data:www-data ${webroot_directory}/config.php
/bin/chmod 660 ${webroot_directory}/config.php


# The application descriptor lists asset directories and regular directories which are to be linked to from inside the webroot and so this bit of 
# code sets up that structure

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

if ( [ -f ${HOME}/application/configuration/cms/moodle/htaccess.txt ] )
then
        /bin/cp ${HOME}/application/configuration/cms/moodle/htaccess.txt /var/www/html/moodle/.htaccess
        /bin/chown root:www-data /var/www/html/moodle/.htaccess
fi

/usr/bin/php -ln ${config_file}

if ( [ "$?" = "0" ] )
then
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET
        #    ${HOME}/utilities/security/EnforcePermissions.sh 

        if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
        then
                /bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
        fi
else
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
fi

if ( [ ! -f  ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy moodle configuration file to the live location during application initiation" "ERROR"
fi
