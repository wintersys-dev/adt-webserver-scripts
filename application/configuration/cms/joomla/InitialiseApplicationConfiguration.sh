#!/bin/sh
###########################################################################################################
# Description:This script will generate a /var/www/html/configuration.php using the values that you have set in
#
#        ${BUILD_HOME}/application/descriptors/joomla.dat
#
# If a virgin copy of joomla is being installed, then, /usr/bin/php /var/www/html/installation/joomla.php is used
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin joomla application. 
# If you are deploying a baseline or a temporal backup then the configuration.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/joomla.dat
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

if ( [ ! -d ${HOME}/logs/joomla_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/joomla_configuration
fi

log_file="joomla_configuration_out"
err_file="joomla_configuration_err"

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/joomla_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/joomla_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/joomla_configuration/${log_file}
exec 2>>${HOME}/logs/joomla_configuration/${err_file}

webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${webroot_directory}" = "" ] )
then
        webroot_directory="/var/www/html/joomla"
fi

if ( [ -f ${webroot_directory}/installation/configuration.php-dist ] )
then
        /bin/cp ${webroot_directory}/installation/configuration.php-dist /var/www/html/configuration.php.default
        /bin/chown www-data:www-data /var/www/html/configuration.php.default
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
        config_file="/var/www/outside_webroot/configuration.php"
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        if ( [ ! -f ${webroot_directory}/configuration.php ] )
        then
                while ( [ ! -f ${webroot_directory}/configuration.php ] )
                do
                        /bin/sleep 1
                done
        fi
        /bin/echo "`/bin/grep "dbprefix" ${webroot_directory}/configuration.php | /usr/bin/awk -F"'" '{print $2}'`" > /var/www/html/dbp.dat
        /bin/chown www-data:www-data /var/www/html/dbp.dat
else
        if ( [ -f ${config_file} ] )
        then
                /bin/rm ${config_file}
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

        user="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:user=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
        password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"
        db="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:db=" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}' | /bin/sed "s%'%%g"`"

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                type="mysqli"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                type="mysqli"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] )
        then
                type="pgsql"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                cd /var/www/html
                website_name="`/bin/grep "^WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                website_username="`/bin/grep "^WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                website_password="`/bin/grep "^WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                webmaster_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
                website_user_description="`/bin/grep "^WEBSITE_USER_DESCRIPTION:" ${HOME}/runtime/application.dat |  /usr/bin/awk -F':' '{print $NF}'`"

                /usr/bin/php ${webroot_directory}/installation/joomla.php install --site-name="${website_name}" --admin-user="${website_user_description}" --admin-email="${webmaster_email}" --admin-username="${website_username}" --admin-password="${website_password}"  --db-type="${type}" --db-host="${HOST}:${DB_PORT}"  --db-user=${user} --db-pass=${password} --db-name=${db}  --db-prefix=${dbprefix} --db-encryption=1 --no-interaction  

                if ( [ -f ${webroot_directory}/configuration.php ] )
                then
                        /bin/cp ${webroot_directory}/configuration.php ${config_file}
                fi
        else

                if ( [ -f /var/www/html/configuration.php.default ] && [ ! -f ${config_file} ] )
                then
                        /bin/cp /var/www/html/configuration.php.default ${config_file}
                        /bin/chown root:www-data ${config_file}
                        /bin/chmod 660 ${config_file}
                        /bin/rm ${webroot_directory}/configuration.php
                fi

                secret="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16 | /usr/bin/tr '[:upper:]' '[:lower:]'`"

                /bin/sed -i "s%\$host =.*$%\$host = '"${HOST}:${DB_PORT}"';%" ${config_file}
                /bin/sed -i "s%\$dbprefix =.*$%\$dbprefix = '"${dbprefix}"';%" ${config_file}
                /bin/sed -i "s%\$secret =.*$%\$secret = '"${secret}"';%" ${config_file}
                /bin/sed -i "s%\$user =.*$%\$user = '"${user}"';%" ${config_file}
                /bin/sed -i "s%\$password =.*$%\$password = '"${password}"';%" ${config_file}
                /bin/sed -i "s%\$db =.*$%\$db = '"${db}"';%" ${config_file}
                /bin/sed -i "s%\$type =.*$%\$type = '"${type}"';%" ${config_file}
                /bin/sed -i "s%\$dbencryption =.*$%\$dbencryption = 1;%" ${config_file}

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] )
                then
                        /bin/sed -i "s%\$dbtype =.*$%\$dbtype = '"mysqli"';%" ${config_file}
                elif ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] )
                then
                        /bin/sed -i "s%\$dbtype =.*$%\$dbtype = '"mysqli"';%" ${config_file}
                elif ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] )
                then
                        /bin/sed -i "s%\$dbtype =.*$%\$dbtype = '"pgsql"';%" ${config_file}
                fi

                APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION'`"
                if ( [ "`/bin/cat /var/www/html/dba.dat`" != "`/bin/echo ${APPLICATION} | /bin/tr '[:lower:]' '[:upper:]'`" ] )
                then
                        ${HOME}/services/email/SendEmail.sh "APPLICATION TYPE MISMATCH" "Your template thinks it is a different application type to your webroot" "ERROR"
                fi
        fi
fi

/bin/echo "JOOMLA" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

#We just set up .htaccess for regardless of webserver type. If the webserver can use the htaccess file it will if it can't, no harm done

if ( [ ! -f ${webroot_directory}/.htaccess ] && [ -f ${webroot_directory}/htaccess.default ] )
then
        /bin/cp ${webroot_directory}/htaccess.default ${webroot_directory}/.htaccess
fi

if ( [ ! -f ${webroot_directory}/.htaccess ] )
then
        if ( [ -f ${webroot_directory}/htaccess.txt ] )
        then
                if ( [ ! -f ${webroot_directory}/htaccess.default ] )
                then
                        /bin/cp ${webroot_directory}/htaccess.txt ${webroot_directory}/htaccess.default
                        /bin/rm ${webroot_directory}/htaccess.txt
                fi
                /bin/cp ${webroot_directory}/htaccess.default ${webroot_directory}/.htaccess
        fi
fi

/bin/echo '<Files configuration.php>
Order allow,deny
Deny from all
</Files>

<Files .htaccess>
Order allow,deny
Deny from all
</Files>' > ${webroot_directory}/.htaccess

if ( [ -f ${webroot_directory}/.htaccess ] )
then
        /bin/chown www-data:www-data ${webroot_directory}/.htaccess
        /bin/chmod 400 ${webroot_directory}/.htaccess
fi

for directory in `/usr/bin/find /var/www/outside_webroot -maxdepth 1 -mindepth 1 -type d`
do
	/bin/echo '<FilesMatch "\.php$">
Order deny,allow
Deny from all
</FilesMatch>' > ${directory}/.htaccess
	/bin/chown www-data:www-data ${directory}/.htaccess
	/bin/chmod 400 ${directory}/.htaccess
done

if ( [ -f ${webroot_directory}/configuration.php ] )
then
	/bin/rm ${webroot_directory}/configuration.php
fi

/bin/ln -s ${config_file} ${webroot_directory}/configuration.php
/bin/chmod 500 ${config_file}
/bin/chown www-data:www-data ${config_file}

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

for setting in `/bin/grep "^INDIVIDUAL_SETTING:" ${HOME}/runtime/application.dat | /bin/sed 's/^INDIVIDUAL_SETTING://g' | /bin/sed 's/:/ /g'`
do
        label="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
        value="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $2}'`"
        if ( [ "${label}" != "" ] && [ "${value}" != "" ] )
        then
                /bin/sed -i "s%\$${label} =.*$%\$${label} = ${value};%" ${config_file}
        fi
done

directories_outside_webroot="`/bin/grep "^DIRECTORIES_OUTSIDE_WEBROOT:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_OUTSIDE_WEBROOT://g' | /bin/sed 's/:/ /g'`"

for directory in ${directories_outside_webroot}
do
	if ( [ ! -d /var/www/outside_webroot/${directory} ] )
	then
		/bin/mkdir -p /var/www/outside_webroot/${directory}
		/bin/chown www-data:www-data /var/www/outside_webroot/${directory}
		/bin/chmod 750 /var/www/outside_webroot/${directory}
	fi
	if ( [ -d ${webroot_directory}/${directory} ] )
	then
		/bin/rm -r ${webroot_directory}/${directory}
	fi
done

directories_to_link="`/bin/grep "^DIRECTORIES_TO_LINK:" ${HOME}/runtime/application.dat | /bin/sed 's/DIRECTORIES_TO_LINK://g'`"
assets_directtories_to_link="`/bin/grep "^ASSETS_DIRECTORIES_TO_LINK:" ${HOME}/runtime/application.dat | /bin/sed 's/ASSETS_DIRECTORIES_TO_LINK://g'`"
directories_to_link="`/bin/echo ${directories_to_link}:${assets_directtories_to_link} | /bin/sed 's/:/ /g'`"

for link_and_directory in `/bin/echo ${directories_to_link} | /bin/sed 's/:/ /g'`
do
	link_directory="`/bin/echo ${link_and_directory} | /usr/bin/awk -F'|' '{print $1}'`"
	directory="`/bin/echo ${link_and_directory} | /usr/bin/awk -F'|' '{print $2}'`"

	if ( [ "${directory}" != "" ] )
	then
		if ( [ -d ${directory} ] )
		then
			/bin/rm -r ${directory}/*
		fi
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

/bin/chown -R www-data:www-data  /var/www/outside_webroot

seesion_save_path="`/bin/grep "^CONFIG_PHP_INI:" ${HOME}/runtime/application.dat | /bin/sed 's/:/ /g' | /bin/grep -o '[^[:space:]]*session.save_path[^[:space:]]*' | /usr/bin/awk -F'=' '{print $NF}'`"

if ( [ ! -d ${session_save_path} ] )
then
	/bin/mkdir -p ${session_save_path}
	/bin/chown www-data:www-data ${session_save_path}
	/bin/chmod 770 ${session_save_path}
fi



/usr/bin/php -ln ${config_file}

if ( [ "$?" = "0" ] )
then
	/bin/touch ${HOME}/runtime/INITIAL_CONFIG_SET
#	${HOME}/utilities/security/EnforcePermissions.sh 

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
