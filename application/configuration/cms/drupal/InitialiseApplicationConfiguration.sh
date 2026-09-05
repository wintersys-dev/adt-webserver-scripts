#!/bin/sh
###########################################################################################################
# Description:This script will generate a ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php 
# using the values that you have set in
#
#        ${BUILD_HOME}/application/descriptors/drupal.dat
#
# If a virgin copy of drupal is being installed, then, /usr/sbin/drush is used when making a non-interactive 
# installation this means that the installer doesn't have to do anything once they  have started the build the 
# next thing they will see is a fully configured virgin drupal application. 
# If you are deploying a baseline or a temporal backup then the settings.php file is manually generated
# based on the values set in 
#
#         ${BUILD_HOME}/application/descriptors/drupal.dat
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
webroot_subdirectory="`/bin/grep "^WEBROOT_SUBDIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

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
if ( [ -f ${webroot_directory}/${webroot_subdirectory}/sites/default/default.settings.php ] )
then
        /bin/cp ${webroot_directory}/${webroot_subdirectory}/sites/default/default.settings.php /var/www/html/settings.php.default
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

database_profile="`/bin/grep "^DATABASE_PROFILE:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

#This tests of the current deployment is intended to be interactive and if it is we block until the user has entered the requisite input data
#using their browser
if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] && [ "`/bin/grep "^INTERACTIVE_APPLICATION_INSTALL" ${HOME}/runtime/application.dat | /bin/sed 's/INTERACTIVE_APPLICATION_INSTALL://g' | /bin/sed 's/:/ /g'`" = "yes" ] )
then
        while ( [ ! -f ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php  ] )
        do
                /bin/touch ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
                /bin/chown www-data:www-data ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
        done

        /bin/cp ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php.orig
                
        ready="0"
        while ( [ "${ready}" = "0" ] )
        do
                if ( [ "`/usr/bin/diff ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php.orig`" != "" ] )
                then
                        ready="1"
                        /bin/rm ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php.orig
                fi
                /bin/sleep 1
        done   

        /bin/echo "`/bin/grep  "\'prefix\'" ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php  | /usr/bin/awk -F"\'" '{print $4}'`" > /var/www/html/dbp.da
        /bin/chown www-data:www-data /var/www/html/dbp.dat

        /bin/touch ${HOME}/runtime/self_managed_config.dat

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" != "1" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" != "1" ] )
        then
                /bin/echo "'pdo' => [
                \PDO::MYSQL_ATTR_SSL_CA => '',
                \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false
                ]," > ${HOME}/runtime/self_managed_config.dat
        fi

        dbprefix="`/bin/cat /var/www/html/dbp.dat`"
        /bin/sed -i "/${dbprefix}/r ${HOME}/runtime/self_managed_config.dat" ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
        /bin/rm ${HOME}/runtime/self_managed_config.dat
        /bin/cp ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php ${config_file}
        /bin/sed -i 's/_notls//g' ${config_file}     
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

        user_tls=""
        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Maria`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Maria`" = "1" ] )
        then
                driver="mysql"  
              #  if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:DBaaS`" != "1" ] )
              #  then
              #          #If you know how to get drush to do a site:install over ssl if you could show me I will get rid of this cludge
              #          user_tls="_notls"
              #  fi
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:MySQL`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:MySQL`" = "1" ] )
        then
                driver="mysql"
              #  if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:DBaaS`" != "1" ] )
              #  then
              #          #If you know how to get drush to do a site:install over ssl if you could show me I will get rid of this cludge
              #          user_tls="_notls"
              #  fi
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" = "1" ] )
        then
                driver="pgsql"
        fi

        username="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:username" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`${user_tls}"
        password="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:password" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
        database="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:database" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"        
        collation="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:collation" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
        then
                /bin/cp ${webroot_directory}/${webroot_subdirectory}/sites/default/default.settings.php  ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
                /bin/chown www-data:www-data ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
                /bin/sed -i 's/^$databases.*;/\$databases['\''default'\'']['\''default'\''] = [ #BOOTSTRAP\n '\''username'\'' => '\'${username}\'',#BOOTSTRAP\n '\''password'\'' => '\'${password}\'', #BOOTSTRAP\n '\''database'\'' => '\'${database}\'',#BOOTSTRAP\n  '\''host'\'' => '\'${HOST}\'', #BOOTSTRAP\n '\''port'\'' => '\'${DB_PORT}\'', #BOOTSTRAP\n '\'driver\'' => '\'${driver}\'', #BOOTSTRAP\n '\''prefix'\'' => '\'${dbprefix}\'',  #BOOTSTRAP\n '\''collation'\'' => '\'${collation}\'', #BOOTSTRAP\n  '\''isolation_level'\'' => '\''READ COMMITTED'\'' #BOOTSTRAP\n];#BOOTSTRAP/'  ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
               
                /bin/touch ${HOME}/runtime/self_managed_config.dat

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" != "1" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" != "1" ] )
                then
                        /bin/echo "'pdo' => [ #BOOTSTRAP
                \PDO::MYSQL_ATTR_SSL_CA => '', #BOOTSTRAP
                \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false #BOOTSTRAP
                ],#BOOTSTRAP" > ${HOME}/runtime/self_managed_config.dat
                fi

                /bin/sed -i "/${dbprefix}/r ${HOME}/runtime/self_managed_config.dat" ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
                /bin/rm ${HOME}/runtime/self_managed_config.dat
                
                /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
                website_username="`/bin/grep "WEBSITE_USERNAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /usr/bin/awk '{print $1}'`"
                website_password="`/bin/grep "WEBSITE_PASSWORD:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /usr/bin/awk '{print $1}'`"
                /usr/sbin/drush site-install ${database_profile} --no-interaction --db-url="${driver}://${username}:${password}@${HOST}:${DB_PORT}/${database}" --db-prefix="${dbprefix}" -vv
                /usr/sbin/drush cache:rebuild
                /usr/sbin/drush user:create ${website_username} --password="${website_password}"

                /bin/sed -i '/#BOOTSTRAP/d' ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php

                application_roles="`/bin/grep "^APPLICATION_ROLES:" ${HOME}/runtime/application.dat | /bin/sed 's/APPLICATION_ROLES://g'`"
                if ( [ "${application_roles}" = "" ] )
                then
                        application_roles="administrator"
                fi
                for application_role in ${application_roles}
                do
                        /usr/sbin/drush user:role:add "${application_role}" "${website_username}"
                done

        #       /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
        #
        #               #A settings.php file will have been generated during the installation but we don't want it to be in the webroot because its
        #               #considered dynamically updateable so mv it ourside of the webroot to the valuse of ${config_file} which we obtained at the top
        #               #of this script
        #
        if ( [ -f ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php  ] )
        then
                /bin/cp ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php  ${config_file}
        fi
else
        username="'${username}'"
        password="'${password}'"
        database="'${database}'"
        collation="'${collation}'"
        driver="'${driver}'"
        cd ${webroot_directory}
        /bin/cp /var/www/html/settings.php.default ${config_file}
       # /bin/sed -i 's/^$databases.*;/\$databases['\''default'\'']['\''default'\''] = [\n '\''username'\'' => '${username}', \n '\''password'\'' => '${password}', \n '\''database'\'' => '${database}',\n  '\''host'\'' => '\'${HOST}\'', \n '\''port'\'' => '${DB_PORT}', \n '\''driver'\'' => '${driver}', \n '\''prefix'\'' => '\'${dbprefix}\'',  \n '\''collation'\'' => '${collation}', \n  '\''isolation_level'\'' => '\''READ COMMITTED'\'' \n];/' /var/www/outside_webroot/settings.php
        /bin/sed -i 's/^$databases.*;/\$databases['\''default'\'']['\''default'\''] = [\n '\''username'\'' => '\'${username}\'', \n '\''password'\'' => '\'${password}\'', \n '\''database'\'' => '\'${database}\'',\n  '\''host'\'' => '\'${HOST}\'', \n '\''port'\'' => '\'${DB_PORT}\'', \n '\'driver\'' => '\'${driver}\'', \n '\''prefix'\'' => '\'${dbprefix}\'',  \n '\''collation'\'' => '\'${collation}\'', \n  '\''isolation_level'\'' => '\''READ COMMITTED'\'' \n];/'  /var/www/outside_webroot/settings.php
        hash_salt="`/bin/grep "^MANDATORY_INDIVIDUAL_SETTING:hash_salt" ${HOME}/runtime/application.dat | /usr/bin/awk -F'=' '{print $NF}'`"
        /bin/sed -i "s%\$settings.*hash_salt.*;%\$settings['hash_salt'] = '"${hash_salt}"';%" ${config_file}
        /bin/grep "ADDITIONAL_SETTING:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' >> ${config_file}

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

private_ip="`${HOME}/utilities/processing/GetIP.sh`"
BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
/bin/sed -i "s/XXXXBUILD_MACHINE_IPXXXX/${BUILD_MACHINE_IP}/" ${config_file}
/bin/sed -i "s/XXXXPRIVATE_IPXXXX/${private_ip}/" ${config_file}

if ( [ "`/bin/grep PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT ${config_file}`" = ""  ] )
then
        if ( [ -f ${HOME}/runtime/DBaaS_CERT ] )
        then
                /bin/touch ${HOME}/runtime/dbaas_config.dat

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" != "1" ] &&  [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" != "1" ] )
                then
                        /bin/echo "'pdo' => [
                \PDO::MYSQL_ATTR_SSL_CA => '${HOME}/runtime/DBaaS_CERT',
                \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true
                ]," > ${HOME}/runtime/dbaas_config.dat
                fi

                /bin/sed -i "/${dbprefix}/r ${HOME}/runtime/dbaas_config.dat" ${config_file}
                /bin/rm ${HOME}/runtime/dbaas_config.dat
        else
                /bin/touch ${HOME}/runtime/self_managed_config.dat

                if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEDBaaSINSTALLATIONTYPE:Postgres`" != "1" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh DATABASEINSTALLATIONTYPE:Postgres`" != "1" ] )
                then
                        /bin/echo "'pdo' => [
                \PDO::MYSQL_ATTR_SSL_CA => '',
                \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false
                ]," > ${HOME}/runtime/self_managed_config.dat
                fi

                /bin/sed -i "/${dbprefix}/r ${HOME}/runtime/self_managed_config.dat" ${config_file}
                /bin/rm ${HOME}/runtime/self_managed_config.dat
        fi
fi

website_name="`/bin/grep "WEBSITE_NAME:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}' | /bin/sed 's/ //g'`"

if ( [ "${website_name}" != "" ] )
then
        /usr/sbin/drush config:set system.site name "${website_name}" -y
fi

/bin/sed -i 's/_notls//g' ${config_file}

#We are in a situation now where whatever type of install we are doing, virgin, baseline or temporal our configuration file is at ${config_file}
#which is ourside of our webroot. So we want to create a symlink from inside our webroot to the actual configuration file
if ( [ -f ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php ] )
then
        /bin/rm ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php 
fi

#/bin/ln -s ${config_file} ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php 

/bin/echo "<?php require( '${config_file}' ); ?>" > ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
/bin/chown www-data:www-data ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
/bin/chmod 600 ${webroot_directory}/${webroot_subdirectory}/sites/default/settings.php
/bin/chown www-data:www-data ${config_file}
/bin/chmod 600 ${config_file}

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
                d }" ${webroot_directory}/${webroot_subdirectory}/.htaccess
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

cd ${webroot_directory}

if ( [ "`/bin/grep "^APPLICATION_TYPE:drupal" ${HOME}/runtime/application.dat`" != "" ] )
then
        tag="DRUPAL"
elif ( [ "`/bin/grep "^APPLICATION_TYPE:cms" ${HOME}/runtime/application.dat`" != "" ] )
then
        tag="DRUPALCMS"
fi

theme_list="`/bin/grep "^${tag}_THEMES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed "s/${tag}_THEMES_TO_INSTALL://g"`"

if ( [ "${theme_list}" != "" ] )
then
        for theme in ${theme_list}
        do
                /usr/bin/sudo -u www-data /usr/local/bin/composer require "drupal/${theme}"
                /usr/sbin/drush cr -y
        done
fi

module_list="`/bin/grep "^${tag}_MODULES_TO_INSTALL:" ${HOME}/runtime/application.dat | /bin/sed "s/${tag}_MODULES_TO_INSTALL://g"`"

if ( [ "${module_list}" != "" ] )
then
        for module in ${module_list}
        do
                /usr/bin/sudo -u www-data /usr/local/bin/composer require "drupal/${module}"
                module="`/bin/echo ${module} | /bin/sed 's/:.*//g'`"
                /usr/sbin/drush en ${module} -y
                /usr/sbin/drush cr -y
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
        ${HOME}/services/email/SendEmail.sh "CONFIGURATION FILE ABSENT" "Failed to copy joomla configuration file to the live location during application initiation" "ERROR"
fi
