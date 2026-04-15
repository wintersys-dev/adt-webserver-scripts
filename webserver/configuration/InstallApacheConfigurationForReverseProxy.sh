#!/bin/sh
#################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This will configure an apache based webserver machine
#################################################################################
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
################################################################################
################################################################################
#set -x

BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
WEBSITE_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
ROOT_DOMAIN="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed 's/^.//' | /bin/sed 's/ /\./g'`"
MOD_SECURITY="`${HOME}/utilities/config/ExtractConfigValue.sh 'MODSECURITY'`"
NO_REVERSE_PROXY="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"
SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"
NO_AUTHENTICATORS="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOAUTHENTICATORS'`"
AUTHENTICATOR_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHENTICATORTYPE'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
port="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PHP" "stripped" | /usr/bin/awk -F'|' '{print $2}' | /bin/sed '/^$/d'`"


if ( [ -d /etc/apache2/sites-available ] && [ "`/usr/bin/find /etc/nginx/sites-available -prune -empty 2>/dev/null`" = "" ] )
then
        /bin/rm /etc/apache2/sites-available/*
else
        /bin/mkdir -p /etc/apache2/sites-available
fi

if ( [ -d /etc/apache2/sites-enabled ] && [ "`/usr/bin/find /etc/nginx/sites-enabled -prune -empty 2>/dev/null`" = "" ] )
then
        /bin/rm /etc/apache2/sites-enabled/*
else
        /bin/mkdir -p /etc/apache2/sites-enabled
fi

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'APACHE:source'`" = "1" ] )
then
        /bin/sed -i 's/#XXXXSOURCE_STYLE####//g' ${HOME}/webserver/configuration/reverseproxy/apache/apache2.conf
        /bin/cp ${HOME}/webserver/configuration/reverseproxy/apache/envvars.conf /usr/sbin/envvars
else
    #    if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh APPLICATIONLANGUAGE:PHP`" = "1" ] )
    #    then
     #           /usr/sbin/a2enmod php${PHP_VERSION}-fpm
     #           /usr/sbin/a2enconf php${PHP_VERSION}-fpm
     #   fi
        /bin/sed -i 's/#XXXXREPO_STYLE####//g' ${HOME}/webserver/configuration/reverseproxy/apache/apache2.conf
fi

/bin/sed '/#XXXX.*/d' ${HOME}/webserver/configuration/reverseproxy/apache/apache2.conf
/bin/cat -s ${HOME}/webserver/configuration/reverseproxy/apache/apache2.conf > /etc/apache2/apache2.conf

/usr/bin/openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

export HOME="`/bin/cat /home/homedir.dat`"
/bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL}/g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s,XXXXHOMEXXXX,${HOME},g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s/XXXXROOTDOMAINXXXX/${ROOT_DOMAIN}/g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s/XXXXBUILD_MACHINE_IPXXXX/${BUILD_MACHINE_IP}/g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s/XXXXWEBSITE_URLXXXXX/${WEBSERVER_URL}/g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s/XXXXPORTXXXX/${port}/" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/sed -i "s/XXXXPHPVERSIONXXXX/${PHP_VERSION}/" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf

if ( [ "${NO_AUTHENTICATORS}" != "0" ] && [ "${AUTHENTICATOR_TYPE}" = "basic-auth" ] && [ "${NO_REVERSE_PROXY}" = "1" ] )
then
        /bin/sed -i "s/#XXXXBASIC-AUTHXXXX//g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
        /bin/sed -i "s/Require all granted/#Require all granted/g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
        /bin/sed -i "s;XXXXVPC_IP_RANGEXXXX;127.0.0.1 ${VPC_IP_RANGE};g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
        /bin/touch /etc/apache2/.htpasswd
fi

if ( [ "${MOD_SECURITY}" = "1" ] && [ "${NO_REVERSE_PROXY}" = "0" ] )
then
        /bin/sed -i "s/#XXXXMODSECURITYXXXX//g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
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
        /bin/sed -i "s/#XXXXFASTCGIPORTXXXX//g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
else
        /bin/sed -i "s/#XXXXFASTCGISOCKETXXXX//g" ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
fi

/bin/sed -i '/#XXXX.*/d' ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf
/bin/cat -s ${HOME}/webserver/configuration/reverseproxy/apache/site-available.conf > /etc/apache2/sites-available/${WEBSITE_NAME}
/bin/chmod 600 /etc/apache2/sites-available/${WEBSITE_NAME}
/bin/chown root:root /etc/apache2/sites-available/${WEBSITE_NAME}
/bin/ln -s /etc/apache2/sites-available/${WEBSITE_NAME} /etc/apache2/sites-enabled/${WEBSITE_NAME}
/bin/echo "/etc/apache2/sites-available/${WEBSITE_NAME}" > ${HOME}/runtime/WEBSERVER_CONFIG_LOCATION.dat

config_settings="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE:settings" "stripped" | /bin/sed 's/|.*//g'`"
for setting in ${config_settings}
do
        setting_name="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
        setting_value="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $2}'`"
        /usr/bin/find /etc/apache2 -name '*' -type f -exec sed -i "s/^${setting_name}.*/${setting_name} ${setting_value}/" {} +
done

/bin/chown -R www-data:www-data /etc/apache2

if ( [ -f /etc/apache2/conf-enabled/sec* ] )
then
        /usr/bin/unlink /etc/apache2/conf-enabled/sec*
fi

${HOME}/utilities/processing/RunServiceCommand.sh apache2 restart

#${HOME}/services/dns/TrustRemoteProxy.sh
${HOME}/services/email/SendEmail.sh "THE APACHE WEBSERVER HAS BEEN INSTALLED" "Apache webserver built from repositories is installed and primed" "INFO"
