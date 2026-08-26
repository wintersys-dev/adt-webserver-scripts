#!/bin/sh
###########################################################################################################
# Description:This script will generate a /var/www/html/wp-config.php using the values that you have set in
#
#        ${BUILD_HOME}/application/descriptors/wordpress.dat
#
# If a virgin copy of wordpress is being installed, then, /usr/local/bin/wp is used
# when making a non-interactive installation this means that the installer doesn't have to do anything once they 
# have started the build they next thing they will see is a fully configured virgin wordpress application. 
# If you are deploying a baseline or a temporal backup then the configuration.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/wordpress.dat
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
#set -x 

if ( [ ! -d ${HOME}/logs/wordpress_configuration ] )
then
        /bin/mkdir -p ${HOME}/logs/wordpress_configuration
fi

log_file="wordpress_configuration_out"
err_file="wordpress_configuration_err"

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET_FAILED ] )
then
        /bin/echo "Log file is at: ${HOME}/logs/wordpress_configuration/${log_file}"
        /bin/echo "Error file is at: ${HOME}/logs/wordpress_configuration/${err_file}"
fi

exec 1>>${HOME}/logs/wordpress_configuration/${log_file}
exec 2>>${HOME}/logs/wordpress_configuration/${err_file}


if ( [ ! -f ${HOME}/runtime/application.dat ] )
then
        exit
fi

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
        webroot_directory="/var/www/html/wordpress"
fi

#Take our own copy of the default configuration file which will still be available to work with on subsquent deployments when the
#installation folder is no longer available to work with
if ( [ -f ${webroot_directory}/wp-config-sample.php ] )
then
        /bin/cp ${webroot_directory}/wp-config-sample.php /var/www/html/wp-config.php.default
        /bin/chown www-data:www-data /var/www/html/wp-config.php.default
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
        config_file="/var/www/outside_webroot/wp-config.php"
fi

#This tests of the current deployment is intended to be interactive and if it is we block until the user has entered the requisite input data
#using their browser
if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        if ( [ ! -f ${webroot_directory}/wp-config.php ] )
        then
                while ( [ ! -f ${webroot_directory}/wp-config.php ] )
                do
                        /bin/sleep 1
                done
        fi
        /bin/echo "`/bin/grep "table_prefix" ${webroot_directory}/wp-config.php | /usr/bin/awk -F"\'" '{print $2}'`"  > /var/www/html/dbp.dat
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

        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        website_name="`/bin/grep "^WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
        website_username="`/bin/grep "^WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
        website_password="`/bin/grep "^WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
        webmaster_email="`/bin/grep "^WEBMASTER_EMAIL:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
        website_user_description="`/bin/grep "^WEBSITE_USER_DESCRIPTION:" ${HOME}/runtime/application.dat |  /usr/bin/awk -F':' '{print $NF}'`"
        db_user="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:DB_USER=" ${HOME}/runtime/application.dat |  /usr/bin/awk -F'=' '{print $NF}'`"
        db_password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:DB_PASSWORD=" ${HOME}/runtime/application.dat |  /usr/bin/awk -F'=' '{print $NF}'`"
        db_name="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:DB_NAME=" ${HOME}/runtime/application.dat |  /usr/bin/awk -F'=' '{print $NF}'`"
        webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

        if ( [ "${webroot_directory}" = "" ] )
        then
                webroot_directory="/var/www/html/wordpress"
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                /usr/bin/sudo -u www-data /usr/local/bin/wp config create --dbuser="${db_user}" --dbpass="${db_password}" --dbname="${db_name}" --dbhost="${HOST}:${DB_PORT}" --dbprefix="${dbprefix}" --config-file="${webroot_directory}/wp-config.php" --skip-check --path="${webroot_directory}"

                /usr/bin/sudo -u www-data /usr/local/bin/wp config set "MYSQL_CLIENT_FLAGS" "MYSQLI_CLIENT_SSL" --raw --config-file="${webroot_directory}/wp-config.php"

                if ( [ "`/usr/bin/sudo -u www-data /usr/local/bin/wp db check  --path="${webroot_directory}" | /bin/grep 'Success:'`" != "" ] )
                then
                        /usr/bin/sudo -u www-data /usr/local/bin/wp core install --url="${WEBSITE_URL}" --title="${website_name}" --admin_user="${website_username}" --admin_password="${website_password}" --admin_email="${webmaster_email}" --path="${webroot_directory}"

                        plugins_to_install="`/bin/grep "^PLUGINS_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed 's/PLUGINS_TO_INSTALL//g' | /bin/sed 's/:/ /g'`"

                        for plugin in ${plugins_to_install}
                        do
                                /usr/bin/sudo -u www-data /usr/local/bin/wp plugin install ${plugin} --path="${webroot_directory}"
                        done

                        /bin/mv ${webroot_directory}/wp-config.php ${config_file}
                        /bin/chmod 660 ${config_file}
                else
                        ${HOME}/services/email/SendEmail.sh "DB Check failed" "Could not verify database during wordpress installation" "ERROR"
                        exit
                fi
        else
                APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION'`"
                if ( [ "`/bin/cat /var/www/html/dba.dat`" != "`/bin/echo ${APPLICATION} | /bin/tr '[:lower:]' '[:upper:]'`" ] )
                then
                        ${HOME}/services/email/SendEmail.sh "APPLICATION TYPE MISMATCH" "Your template thinks it is a different application type to your webroot" "ERROR"
                        exit
                fi

                /usr/bin/sudo -u www-data /usr/local/bin/wp config create --dbuser="${db_user}" --dbpass="${db_password}" --dbname="${db_name}" --dbhost="${HOST}:${DB_PORT}" --dbprefix="${table_prefix}" --config-file="${config_file}" --skip-check --path="${webroot_directory}"

                /usr/bin/sudo -u www-data /usr/local/bin/wp config set "MYSQL_CLIENT_FLAGS" "MYSQLI_CLIENT_SSL" --raw --config-file="${webroot_directory}/wp-config.php"

                if ( [ "`/usr/bin/sudo -u www-data /usr/local/bin/wp db check  --path="${webroot_directory}"  | /bin/grep 'Success:'`" = "" ] )
                then
                        ${HOME}/services/email/SendEmail.sh "DB Check failed" "Could not verify database during wordpress installation" "ERROR"
                        exit
                fi
        fi
fi

#Remind ourselves at any future time that we are a wordpress application. This will be stored in the backups and the baselines and can be consulted later
/bin/echo "WORDPRESS" > /var/www/html/dba.dat
/bin/chown www-data:www-data /var/www/html/dba.dat

/bin/echo "${webroot_directory}" > /var/www/html/wr.dat
/bin/chown www-data:www-data /var/www/html/wr.dat

#We are in a situation now where whatever type of install we are doing, virgin, baseline or temporal our configuration file is at ${config_file}
#which is ourside of our webroot. So we want to create a symlink from inside our webroot to the actual configuration file
if ( [ -f ${webroot_directory}/wp-config.php ] )
then
        /bin/rm ${webroot_directory}/wp-config.php
fi

/bin/ln -s ${config_file} ${webroot_directory}/wp-config.php
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

for setting in `/bin/grep "^INDIVIDUAL_SETTING:" ${HOME}/runtime/application.dat | /bin/sed 's/^INDIVIDUAL_SETTING://g' | /usr/bin/awk -F'::' '{print $NF}' | /bin/sed 's/^://g'`
do
        label="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
        value="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $NF}'`"
        if ( [ "${label}" != "" ] && [ "${value}" != "" ] )
        then
                /usr/bin/sudo -u www-data wp config set "${label}" "${value}" --config-file="${config_file}"
        fi
done

for setting in `/bin/grep "^INDIVIDUAL_SETTING_UNQUOTED:" ${HOME}/runtime/application.dat | /bin/sed 's/^INDIVIDUAL_SETTING://g' | /usr/bin/awk -F'::' '{print $NF}' | /bin/sed 's/^://g'`
do
        label="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
        value="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $NF}'`"
        if ( [ "${label}" != "" ] && [ "${value}" != "" ] )
        then
                /usr/bin/sudo -u www-data wp config set "${label}" "${value}" --raw --config-file="${config_file}"
        fi
done

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

                if ( [ "${directory}" != "" ] )
                then
                        if ( [ -d ${directory} ] )
                        then
                                /bin/rm -r ${directory}/*
                        fi
                fi

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

if ( [ ! -f ${webroot_directory}/.htaccess ] )
then
        if ( [ -f ${HOME}/application/configuration/cms/wordpress/htaccess.txt ] )
        then
                /bin/cp ${HOME}/application/configuration/cms/wordpress/htaccess.txt ${webroot_directory}/.htaccess
        fi

        if ( [ -f ${webroot_directory}/.htaccess ] )
        then
                /bin/chown www-data:www-data ${webroot_directory}/.htaccess
                /bin/chmod 400 ${webroot_directory}/.htaccess
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
fi

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
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy wordpres configuration file to the live location during application initiation" "ERROR"
fi


