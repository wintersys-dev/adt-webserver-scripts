#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This will configure an lighttpd based webserver machine
###################################################################################
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
####################################################################################
####################################################################################
set -x

if ( [ ! -d ${HOME}/logs/configure_lighttpd ] )
then
        /bin/mkdir -p ${HOME}/logs/configure_lighttpd
fi

log_file="lighttpd_out_`/bin/date | /bin/sed 's/ //g'`"
err_file="lighttpd_err_`/bin/date | /bin/sed 's/ //g'`"

/bin/echo "Log file is at: ${HOME}/logs/configure_lighttpd/${log_file}"
/bin/echo "Error file is at: ${HOME}/logs/configure_lighttpd/${err_file}"

exec 1>>${HOME}/logs/configure_lighttpd/${log_file}
exec 2>>${HOME}/logs/configure_lighttpd/${err_file}

HOME="`/bin/cat /home/homedir.dat`"
PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
APPLICATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATION' | /usr/bin/tr '[:lower:]' '[:upper:]'`"
port="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PHP" "stripped" | /usr/bin/awk -F'|' '{print $2}' | /bin/sed '/^$/d' | /bin/sed 's/ //g'`"

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
        webroot_directory="/var/www/html/`/bin/echo ${APPLICATION} | /usr/bin/tr '[:upper:]' '[:lower:]'`"
fi

if ( [ -f /etc/php/${PHP_VERSION}/fpm/php.ini ] )
then
	/bin/sed -i "/cgi.fix_pathinfo/c\ cgi.fix_pathinfo=1" /etc/php/${PHP_VERSION}/fpm/php.ini
fi

if ( [ -f /etc/lighttpd/lighttpd.conf ] )
then
	/bin/rm /etc/lighttpd/lighttpd.conf
fi

if ( [ -f /var/www/html/index.lighttpd.html ] )
then
	/bin/rm /var/www/html/index.lighttpd.html
fi

if ( [ ! -d /var/cache/lighttpd/uploads ] )
then
	/bin/mkdir -p /var/cache/lighttpd/uploads
	/bin/chown -R www-data:www-data /var/cache/lighttpd
fi

if ( [ ! -d /var/cache/lighttpd/compress ] )
then
	/bin/mkdir -p /var/cache/lighttpd/compress
	/bin/chown www-data:www-data /var/cache/lighttpd/compress
fi

/bin/sed -i "s/XXXXPHPVERSIONXXXX/${PHP_VERSION}/" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/sed -i "s/XXXXPORTXXXX/${port}/" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL}/g" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/sed -i "s,XXXXHOMEXXXX,${HOME},g" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/sed -i "s;XXXXWEBROOT_DIRECTORYXXXX;${webroot_directory};" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/sed -i "s;XXXXWEBROOT_SUBDIRECTORYXXXX;${webroot_subdirectory};" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}


if ( [ -f ${HOME}/webserver/configuration/application/lighttpd/mimetypes.conf ] )
then
	/bin/cp ${HOME}/webserver/configuration/application/lighttpd/mimetypes.conf /etc/lighttpd/mimetypes.conf
fi

if ( [ ! -d /var/lib/php/session ] )
then
	/bin/mkdir -p /var/lib/php/sessions
	/bin/chown -R www-data:www-data /var/lib/php
fi

php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
www_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
/bin/sed -i "s/^;env/env/g" ${www_conf}

if ( [ "`/bin/echo ${port} | /bin/grep -o "^[0-9]*$"`" != "" ] )
then
	/bin/sed -i "s/^listen =.*/listen = 127.0.0.1:${port}/g" ${www_conf}
	/bin/sed -i "s/^;listen.allowed_clients/listen.allowed_clients/" ${www_conf}
else
	/bin/sed -i "s,^listen =.*,listen = /var/run/php${PHP_VERSION}-fpm.sock,g" ${www_conf}
	/bin/sed -i "s/^;listen.mode/listen.mode/" ${www_conf}
fi

if ( [ "`/bin/echo ${port} | /bin/grep -o "^[0-9]*$"`" != "" ] )
then
	/bin/sed -i "s/#XXXXFASTCGIPORTXXXX//" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
else
	/bin/sed -i "s/#XXXXFASTCGISOCKETXXXX//" ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
fi

/bin/sed -i '/#XXXX.*/d' ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION}
/bin/cat -s ${HOME}/webserver/configuration/application/lighttpd/lighttpd.conf.${APPLICATION} > /etc/lighttpd/lighttpd.conf
/bin/chown root:root /etc/lighttpd/lighttpd.conf
/bin/chmod 600 /etc/lighttpd/lighttpd.conf
/bin/echo "/etc/lighttpd/lighttpd.conf" > ${HOME}/runtime/WEBSERVER_CONFIG_LOCATION.dat

config_settings="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:settings" "stripped" | /bin/sed 's/|.*//g'`"
for setting in ${config_settings}
do
	setting_name="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
	/usr/bin/find /etc/lighttpd -name '*' -type f -exec sed -i "s#.*${setting_name}.*#${setting}#" {} +
done

if ( [ ! -d /var/cache/lighttpd/uploads ] )
then
        /bin/mkdir -p /var/cache/lighttpd/uploads
        /bin/chown -R www-data:www-data /var/cache/lighttpd
fi

${HOME}/services/email/SendEmail.sh "THE LIGHTTPD WEBSERVER HAS BEEN INSTALLED" "Lighttpd webserver is installed and primed" "INFO"
