#!/bin/sh

set -x

if ( [ ! -d ${HOME}/logs/drupal_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/drupal_configuration
fi

log_file="drupal_configuration_out"
err_file="drupal_configuration_err"

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/drupal_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/drupal_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/drupal_configuration/${log_file}
exec 2>>${HOME}/logs/drupal_configuration/${err_file}

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
        webroot_directory="/var/www/html/drupal"
fi

#Take our own copy of the default configuration file which will still be available to work with on subsquent deployments when the
#installation folder is no longer available to work with
if ( [ -f ${webroot_directory}/web/sites/default/default.settings.php ] )
then
        /bin/cp ${webroot_directory}/web/sites/default/default.settings.php /var/www/html/settings.php.default
        /bin/chown www-data:www-data /var/www/html/settings.php.default
fi

#Create the standard ourside webroot folder which is used throughout the toolkit as the directory outside of the webroot where
#parts of the system that require dynamic access by users and admins are separated and secured away from the core system
if ( [ ! -d /var/www/outside_webroot ] )
then
        /bin/mkdir /var/www/outside_webroot
        /bin/chown www-data:www-data /var/www/outside_webroot
        /bin/chmod 750 /var/www/outside_webroot
fi

#Extract the configuration filename from the application descriptor and if its not available fallback to a default value
#This will be where the actual configuration.php file is stored and is linked to using a symlink from within the webroot
config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/outside_webroot/settings.php"
fi

#This tests of the current deployment is intended to be interactive and if it is we block until the user has entered the requisite input data
#using their browser
if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        if ( [ ! -f ${webroot_directory}/web/sites/default/settings.php  ] )
        then
                while ( [ ! -f ${webroot_directory}/web/sites/default/settings.php  ] )
                do
                        /bin/sleep 1
                done
        fi
        /bin/echo "`/bin/grep "dbprefix" ${webroot_directory}/web/sites/default/settings.php| /usr/bin/awk -F"'" '{print $2}'`" > /var/www/html/dbp.dat
        /bin/chown www-data:www-data /var/www/html/dbp.dat
else
	#If we are here then this is a non-interactive install and all our configuration parameters will be taken from the application.dat file
	#It is expected that this will be the more common case than an interactive installation
        if ( [ -f ${config_file} ] )
        then
                /bin/rm ${config_file}
        fi

	#In the case of a subsquent deployment it is expected that the database prefix will have been stored along with the application code
	#in the webroot, but, if it isn virgin installation we will generate the database prefix for ourselves
        if ( [ -f /var/www/html/dbp.dat ] )
        then
                dbprefix="`/bin/cat /var/www/html/dbp.dat`"
        else
                dbprefix="adt`/usr/bin/tr -dc a-z0-9 </dev/urandom | /usr/bin/head -c 5; /bin/echo`_"
                /bin/echo ${dbprefix} > /var/www/html/dbp.dat
                /bin/chown www-data:www-data /var/www/html/dbp.dat
                /bin/chmod 600 /var/www/html/dbp.dat
        fi

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

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                driver="mysql"       
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                driver="mysql"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] )
        then
                driver="pgsql"
        fi

        username="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:username" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`_notls"
        password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
        database="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:database" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"        
        collation="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:collation" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                website_username="`/bin/grep "WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /usr/bin/awk '{print $1}'`"
                website_password="`/bin/grep "WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /usr/bin/awk '{print $1}'`"
                /bin/cp /var/www/html/settings.php.default ${webroot_directory}/web/sites/default/settings.php
                /bin/chown www-data:www-data ${webroot_directory}/web/sites/default/settings.php
                /usr/sbin/drush si --no-interaction --db-url="mysql://${username}:${password}@${HOST}:${DB_PORT}/${database}?module=${driver}#${dbprefix} --db-prefix=${dbprefix}"
                /usr/sbin/drush cr
                /usr/sbin/drush user:create ${website_username} --password="${website_password}"
                /usr/sbin/drush user:role:add "administrator" "${website_username}"
                /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${webroot_directory}/web/sites/default/settings.php
        else
                username="'${username}'"
                password="'${password}'"
                database="'${database}'"
                collation="'${collation}'"
                driver="'${driver}'"
                cd ${webroot_directory}
                /bin/cp /var/www/html/settings.php.default ${webroot_directory}/web/sites/default/settings.php
                /bin/sed -i 's/^$databases.*;/\$databases['\''default'\'']['\''default'\''] = ['\''username'\'' => '${username}', '\''password'\'' => '${password}', '\''database'\'' => '${database}', '\''host'\'' => '\'${HOST}\'', '\''port'\'' => '${DB_PORT}', '\''driver'\'' => '${driver}', '\''prefix'\'' => '\'${dbprefix}\'',  '\''collation'\'' => '${collation}', '\''isolation_level'\'' => '\''READ COMMITTED'\'', ];/' ${webroot_directory}/web/sites/default/settings.php
                hash_salt="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:hash_salt" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
                /bin/sed -i "s%\$settings.*hash_salt.*;%\$settings['hash_salt'] = '"${hash_salt}"';%" ${webroot_directory}/web/sites/default/settings.php
                /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${webroot_directory}/web/sites/default/settings.php
                APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION'`"
                if ( [ "`/bin/cat /var/www/html/dba.dat`" != "`/bin/echo ${APPLICATION} | /bin/tr '[:lower:]' '[:upper:]'`" ] )
                then
                        ${HOME}/services/email/SendEmail.sh "APPLICATION TYPE MISMATCH" "Your template thinks it is a different application type to your webroot" "ERROR"
                fi
        fi
fi

#Remind ourselves at any future time that we are a Joomla application. This will be stored in the backups and the baselines and can be consulted later
/bin/echo "DRUPAL" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

/bin/echo "${webroot_directory}" > /var/www/html/wr.dat
/bin/chown www-data:www-data /var/www/html/wr.dat

#We are in a situation now where whatever type of install we are doing, virgin, baseline or temporal our configuration file is at ${config_file}
#which is ourside of our webroot. So we want to create a symlink from inside our webroot to the actual configuration file
if ( [ -f ${webroot_directory}/web/sites/default/settings.php ] )
then
	/bin/rm ${webroot_directory}/web/sites/default/settings.php 
fi

/bin/ln -s ${config_file} ${webroot_directory}/web/sites/default/settings.php 
/bin/chmod 500 ${config_file}
/bin/chown www-data:www-data ${config_file}

#If we are looking at our webroot sourcecode we might have forgotten which database type this webroot is associated or was built against so
#write a little note to ourselved to remind us whether we are expecting mariadb, mysql or postgres to be running
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

public_ip="`${HOME}/utilities/processing/GetPublicIP.sh`"
private_ip="`${HOME}/utilities/processing/GetIP.sh`"
/bin/sed -i "s/XXXXPUBLIC_IPXXXX/${public_ip}/" ${webroot_directory}/web/sites/default/settings.php
/bin/sed -i "s/XXXXPRIVATE_IPXXXX/${private_ip}/" ${webroot_directory}/web/sites/default/settings.php

website_name="`/bin/grep "WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /bin/sed 's/ //g'`"

if ( [ "${website_name}" != "" ] )
then
        /usr/sbin/drush config:set system.site name "${website_name}" -y
fi

#This is how we tell ourselves this is a drupal application
/bin/echo "DRUPAL" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

if ( [ -f ${webroot_directory}/web/sites/default/settings.php ] && [ "`/bin/grep "php require" ${webroot_directory}/web/sites/default/settings.php`" = "" ] )
then
        /bin/mv ${webroot_directory}/web/sites/default/settings.php ${config_file}
        /bin/chown root:www-data ${config_file}
        /bin/chmod 740 ${config_file}
fi

/bin/echo "<?php require( '${config_file}' ); ?>" > ${webroot_directory}/web/sites/default/settings.php

/bin/chown www-data:www-data ${webroot_directory}/web/sites/default/settings.php
/bin/chmod 400 ${webroot_directory}/web/sites/default/settings.php

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

        if ( [ -f /var/www/html/dbe.dat ] )
        then
                /bin/chown www-data:www-data /var/www/html/dbe.dat
                /bin/chmod 600 /var/www/html/dbe.dat
        fi
fi

# Had this problem https://www.drupal.org/project/sitemap/issues/3145126 if anyone knows a cleaner way I would be grateful
if ( [ -f ${HOME}/application/configuration/cms/drupal/htaccess.txt ] )
then
        /bin/sed -i "/RewriteEngine on/ {
                r ${HOME}/application/configuration/cms/drupal/htaccess.txt
                d }" /var/www/html/drupal/.htaccess
fi

if ( [ -f ${HOME}/application/configuration/cms/drupal/htaccess-private.txt ] )
then
        /bin/cp ${HOME}/application/configuration/cms/drupal/htaccess-private.txt /var/www/html/private/.htaccess
        /bin/chown www-data:www-data /var/www/html/private/.htaccess
        /bin/chmod 400 /var/www/html/private/.htaccess
fi

if ( [ "`/bin/grep "^ASSETS_OUTSIDE_WEBROOT:yes" ${HOME}/runtime/application.dat`" != "" ] )
then
        dirs_to_link="`/bin/grep "^LINK_INSIDE_WEBROOT:" ${HOME}/runtime/application.dat | /bin/sed 's/LINK_INSIDE_WEBROOT://g' | /bin/sed 's/:/ /g'`"

        for asset_directory in `/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`
        do
                if ( [ ! -d /var/www/html/${asset_directory} ] )
                then
                        /bin/mv ${webroot_directory}/${asset_directory} /var/www/html        
                fi

                if ( [ "`/bin/echo ${asset_directory} | /bin/grep '/'`" != "" ] )
                then
                        outside_asset_directory="`/bin/echo ${asset_directory} | /usr/bin/awk -F'/' '{print $NF}'`"
                else
                        outside_asset_directory="${asset_directory}"
                fi

                if ( [ "`/bin/echo ${dirs_to_link} | /bin/grep ${asset_directory}`" != "" ] )
                then
                        /bin/ln -s /var/www/html/${outside_asset_directory} ${webroot_directory}/${asset_directory}
                        /bin/chown www-data:www-data ${webroot_directory}/${asset_directory}
                        /bin/chmod 777 ${webroot_directory}/${asset_directory}
                fi
        done
fi

/bin/mkdir -p `/bin/grep "^CONFIG_PHP_INI:" ${HOME}/runtime/application.dat | /bin/sed 's/:/ /g' | /bin/grep -o '[^[:space:]]*session.save_path[^[:space:]]*' | /usr/bin/awk -F'=' '{print $NF}'`
/usr/bin/php -ln ${config_file}

if ( [ "$?" = "0" ] )
then
        /bin/chmod 600 ${config_file}
        /bin/chown root:www-data ${config_file}
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET
     #   ${HOME}/utilities/security/EnforcePermissions.sh 

        if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
        then
                /bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
        fi
else
        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
fi

if ( [ ! -f  ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy joomla configuration file to the live location during application initiation" "ERROR"
fi
