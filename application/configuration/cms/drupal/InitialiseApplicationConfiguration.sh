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
		
		/bin/echo "`/bin/grep  "\'prefix\'" ${webroot_directory}/web/sites/default/settings.php  | /usr/bin/awk -F"\'" '{print $4}'`" > /var/www/html/dbp.da
		/bin/chown www-data:www-data /var/www/html/dbp.dat
		
		#A settings.php file will have been generated during the installation but we don't want it to be in the webroot because its
		#considered dynamically updateable so mv it ourside of the webroot to the valuse of ${config_file} which we obtained at the top
		#of this script
        if ( [ -f ${webroot_directory}/web/sites/default/settings.php  ] )
        then
        	/bin/cp ${webroot_directory}/web/sites/default/settings.php  ${config_file}
        fi
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
            #    /bin/cp /var/www/html/settings.php.default ${webroot_directory}/web/sites/default/settings.php
            #    /bin/chown www-data:www-data ${webroot_directory}/web/sites/default/settings.php
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

#public_ip="`${HOME}/utilities/processing/GetPublicIP.sh`"
#private_ip="`${HOME}/utilities/processing/GetIP.sh`"
#/bin/sed -i "s/XXXXPUBLIC_IPXXXX/${public_ip}/" ${config_file}
#/bin/sed -i "s/XXXXPRIVATE_IPXXXX/${private_ip}/" ${config_file}

private_ip="`${HOME}/utilities/processing/GetIP.sh`"
BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
/bin/sed -i "s/XXXXBUILD_MACHINE_IPXXXX/${BUILD_MACHINE_IP}/" ${config_file}
/bin/sed -i "s/XXXXPRIVATE_IPXXXX/${private_ip}/" ${config_file}

website_name="`/bin/grep "WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /bin/sed 's/ //g'`"

if ( [ "${website_name}" != "" ] )
then
        /usr/sbin/drush config:set system.site name "${website_name}" -y
fi

#if ( [ -f ${webroot_directory}/web/sites/default/settings.php ] && [ "`/bin/grep "php require" ${webroot_directory}/web/sites/default/settings.php`" = "" ] )
#then
#        /bin/mv ${webroot_directory}/web/sites/default/settings.php ${config_file}
#        /bin/chown root:www-data ${config_file}
#        /bin/chmod 740 ${config_file}
#fi

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

# The application descriptor lists asset directories and regular directories which are to be linked to from inside the webroot and so this bit of 
# code sets up that structure

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" != "1" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:baseline`" != "1" ] )
then
	directories_to_link="`/bin/grep "^DIRECTORIES_TO_LINK:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_TO_LINK://g'`"
	assets_directories_to_link="`/bin/grep "^ASSETS_DIRECTORIES_TO_LINK:" ${HOME}/runtime/application.dat | /bin/sed 's/ASSETS_DIRECTORIES_TO_LINK://g'`"
	directories_to_link="`/bin/echo ${directories_to_link}:${assets_directories_to_link} | /bin/sed 's/:/ /g'`"

	for link_and_directory in `/bin/echo ${directories_to_link} | /bin/sed 's/:/ /g'`
	do
		link_directory="`/bin/echo ${link_and_directory} | /usr/bin/awk -F'|' '{print $1}'`"
		directory="`/bin/echo ${link_and_directory} | /usr/bin/awk -F'|' '{print $2}'`"

		if ( [ -L ${link_directory} ] )
        then
        	/usr/bin/unlink ${link_directory}
        fi

		if ( [ -d ${link_directory} ] )
		then
			if ( [ ! -d ${directory} ] )
			then
				/bin/mkdir -p ${directory}
			fi
			/bin/mv ${link_directory}/* ${directory}
			/bin/rm -r ${link_directory}
		else
			/bin/mkdir -p ${directory}
    	fi
	
		link="${link_directory}"
		/bin/chown www-data:www-data ${directory}
		/bin/chmod 750 ${directory}
		/bin/ln -s ${directory} ${link}
	done
else
	directories="`/bin/grep "^DIRECTORIES_TO_LINK:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_TO_LINK://g'`"

	for directory in `/bin/echo ${directories} | /bin/sed 's/:/ /g'`
	do
		directory="`/bin/echo ${directory} | /usr/bin/awk -F'|' '{print $1}'`"
		/bin/mkdir -p ${directory}
		/bin/chown www-data:www-data ${directory}
		/bin/chmod 750 ${directory}
	done
fi

if ( [ ! -d ${webroot_directory}/private ] )
then
	/bin/mkdir -p ${webroot_directory}/private
	/bin/chown www-data:www-data ${webroot_directory}/private
	/bin/chmod 750 ${webroot_directory}/private
fi

# Make sure that the session save path directory is set and exists as sometimes this causes an issue if its not set correctly
seesion_save_path="`/bin/grep "^CONFIG_PHP_INI:" ${HOME}/runtime/application.dat | /bin/sed 's/:/ /g' | /bin/grep -o '[^[:space:]]*session.save_path[^[:space:]]*' | /usr/bin/awk -F'=' '{print $NF}'`"

if ( [ ! -d ${session_save_path} ] )
then
	/bin/mkdir -p ${session_save_path}
	/bin/chown www-data:www-data ${session_save_path}
	/bin/chmod 770 ${session_save_path}
fi

#As I said we expect all files that our outside of the webroot to be accessible and updatable by the user that the webserver is running as www-data
/bin/chown -R www-data:www-data  /var/www/outside_webroot

# Had this problem https://www.drupal.org/project/sitemap/issues/3145126 if anyone knows a cleaner way I would be grateful
if ( [ -f ${HOME}/application/configuration/cms/drupal/htaccess.txt ] )
then
        /bin/sed -i "/RewriteEngine on/ {
                r ${HOME}/application/configuration/cms/drupal/htaccess.txt
                d }" ${webroot_directory}/web/.htaccess
fi

if ( [ -f ${HOME}/application/configuration/cms/drupal/htaccess-private.txt ] )
then
        /bin/cp ${HOME}/application/configuration/cms/drupal/htaccess-private.txt ${webroot_directory}/private/.htaccess
        /bin/chown www-data:www-data ${webroot_directory}/private/.htaccess
        /bin/chmod 400 ${webroot_directory}/private/.htaccess
fi

#Because the directories outside of the webroot might be used to upload files make double sure that no malicious php files can get through to
#our directories and if the do they won't be accessible

for directory in `/usr/bin/find /var/www/outside_webroot -maxdepth 1 -mindepth 1 -type d`
do
	/bin/echo '<FilesMatch "\.php$">
Require all granted
</FilesMatch>' > ${directory}/.htaccess
	/bin/chown www-data:www-data ${directory}/.htaccess
	/bin/chmod 400 ${directory}/.htaccess
done

# Do a final integrity check on the config_file
/usr/bin/php -ln ${config_file}

if ( [ "$?" = "0" ] )
then
	/bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET

	if ( [ -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
	then
		/bin/rm ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
	fi
else
	/bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED
fi

#If anything went wrong, fire off an email
if ( [ ! -f  ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
	${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy joomla configuration file to the live location during application initiation" "ERROR"
fi
