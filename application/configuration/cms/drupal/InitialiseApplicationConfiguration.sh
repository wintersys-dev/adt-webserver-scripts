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

webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${webroot_directory}" = "" ] )
then
        webroot_directory="/var/www/html/web"
fi

if ( [ -f ${webroot_directory}/web/sites/default/default.settings.php ] )
then
        /bin/cp ${webroot_directory}/web/sites/default/default.settings.php /var/www/html/settings.php.default
        /bin/chown www-data:www-data /var/www/html/settings.php.default
fi

config_file="`/bin/grep "^CONFIG_FILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${config_file}" = "" ] )
then
        config_file="/var/www/html/settings.php"
fi

if ( [ -f ${webroot_directory}/web/sites/default/settings.php ] )
then
        /bin/rm ${webroot_directory}/web/sites/default/settings.php
fi

if ( [ -f /var/www/html/dbp.dat ] )
then
        dbprefix="`/bin/cat /var/www/html/dbp.dat`"
else
        dbprefix="adt`/usr/bin/tr -dc a-z0-9 </dev/urandom | /usr/bin/head -c 5; /bin/echo`_"
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
        /usr/sbin/drush si --no-interaction --db-url="mysql://${username}:${password}@${HOST}:${DB_PORT}/${database}?module=mysql#${dbprefix} --sites-subdir=${webroot_directory}/web"
        /usr/sbin/drush cr
        /usr/sbin/drush user:create ${website_username} --password="${website_password}"
        /usr/sbin/drush user:role:add "administrator" "${website_username}"
        /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${webroot_directory}/web/sites/default/settings.php
        /bin/chown www-data:www-data ${webroot_directory}/web/sites/default/files
fi

        /bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET
