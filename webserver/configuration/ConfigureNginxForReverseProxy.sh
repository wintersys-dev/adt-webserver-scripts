#!/bin/sh
#####################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will perform a base installation of Nginx from repo. You are welcome
# to modify it to your needs.
#####################################################################################
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
##################################################################################
##################################################################################
#set -x

HOME="`/bin/cat /home/homedir.dat`"
DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
WEBSITE_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
AUTHENTICATOR_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHENTICATORTYPE'`"
MOD_SECURITY="`${HOME}/utilities/config/ExtractConfigValue.sh 'MODSECURITY'`"
NO_REVERSE_PROXY="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"
NO_AUTHENTICATORS="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOAUTHENTICATORS'`"
AUTH_SERVER_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
LOAD_BALANCER="`${HOME}/utilities/config/ExtractConfigValue.sh 'LOADBALANCER'`"
SECRET_IDENTIFIER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SECRETIDENTIFIER'`"
S3_HOST_BASE="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE' | /usr/bin/awk -F'|' '{print $1}'`"

if ( [ -d /etc/nginx/sites-available ] && [ "`/usr/bin/find /etc/nginx/sites-available -prune -empty 2>/dev/null`" = "" ] )
then
	/bin/rm /etc/nginx/sites-available/*
else
	/bin/mkdir -p /etc/nginx/sites-available
fi

if ( [ -f /etc/nginx/fastcgi.conf ] )
then
	/bin/cp /etc/nginx/fastcgi.conf /etc/nginx/fastcgi_params
fi

if ( [ -d /etc/nginx/sites-enabled ] && [ "`/usr/bin/find /etc/nginx/sites-enabled -prune -empty 2>/dev/null`" = "" ] )
then
	/bin/rm /etc/nginx/sites-enabled/*
else
	/bin/mkdir -p /etc/nginx/sites-enabled
fi

/usr/bin/openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096

/bin/sed -i "s/XXXXWEBSITEURLXXXX/${WEBSITE_URL}/g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
/bin/sed -i "s;XXXXHOMEXXXX;${HOME};g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
#/bin/sed -i "s;XXXXVPC_IP_RANGEXXXX;${VPC_IP_RANGE};g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf


if ( [ "${NO_AUTHENTICATORS}" != "0" ] && [ "${AUTHENTICATOR_TYPE}" = "basic-auth" ] && [ "${NO_REVERSE_PROXY}" != "0" ] )
then
	/bin/sed -i "s/#XXXXBASIC-AUTHXXXX//g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
	/bin/touch /etc/nginx/.htpasswd

	if ( [ "${LOAD_BALANCER}" = "1" ] )
    then
    #	/bin/sed -i "s;XXXXVPC_IP_RANGEXXXX;127.0.0.1 ${BUILD_MACHINE_IP};g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
    	/bin/sed -i "/XXXXVPC_IP_RANGEXXXX/d" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
		/bin/sed -i "s/XXXXAUTH-SERVER-URLXXXX/${AUTH_SERVER_URL}/g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
		/bin/sed -i "s/XXXXBUILD_MACHINE_IPXXXX/${BUILD_MACHINE_IP}/g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
	else
    	/bin/sed -i "s;XXXXVPC_IP_RANGEXXXX;${VPC_IP_RANGE};g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
    fi
fi

if ( [ "${NO_AUTHENTICATORS}" != "0" ] && [ "${AUTHENTICATOR_TYPE}" = "whitelist" ] && [ "${NO_REVERSE_PROXY}" != "0" ] )
then
        if ( [ ! -f ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat ] )
        then
                /bin/echo "allow ${VPC_IP_RANGE};" > ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
                /bin/echo "allow ip 127.0.0.1;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
			    /bin/echo "deny all;" >> ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat
        fi
        /bin/sed -i "s,#XXXXWHITE-LISTXXXX,include ${HOME}/runtime/authenticator/webserver_ip_whitelist.dat;,g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
		/bin/cp ${HOME}webserver/configuration/reverseproxy/whitelist/403-error.html /etc/nginx/403-error.html
else
        /bin/sed -i "s/#XXXXOPEN-PROXYXXXX/            Require all granted/g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
fi

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:source'`" = "1" ] )
then
	if ( [ "${MOD_SECURITY}" = "1" ] && [ "${NO_REVERSE_PROXY}" != "0" ] )
	then
		/bin/sed -i "s/#XXXXMODSECURITYXXXX//g" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf
	fi
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:2`" = "1" ] )
then
        application_asset_dirs="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"
        count="0"
        for application_assets_directory in ${application_asset_dirs}
        do
                asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${application_assets_directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g' -e 's/_/-/g'`"
                full_bucket_url="${asset_bucket}.${S3_HOST_BASE}"
                /bin/cp ${HOME}/webserver/configuration/reverseproxy/nginx/redirection-template.conf ${HOME}/runtime/redirection.conf.${count}
                /bin/sed -i "s;XXXXASSETSXXXX;${application_assets_directory};g" ${HOME}/runtime/redirection.conf.${count}
                /bin/sed -i "s/XXXXS3_HOST_URLXXXX/${full_bucket_url}/" ${HOME}/runtime/redirection.conf.${count}
                /bin/sed -i "s/XXXXREFERERXXXX/${WEBSITE_URL}-${SECRET_IDENTIFIER}/g" ${HOME}/runtime/redirection.conf.${count}
                /bin/sed -i -e "/#XXXXS3_REDIRECTIONXXXX/{r ${HOME}/runtime/redirection.conf.${count}" -e 'd}' ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf    
                /bin/rm ${HOME}/runtime/redirection.conf.${count}
                count="`/usr/bin/expr ${count} + 1`"
        done
fi

/bin/sed -i "/#XXXX/d" ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf

/bin/cat -s ${HOME}/webserver/configuration/reverseproxy/nginx/site-available.conf > /etc/nginx/sites-available/${WEBSITE_NAME}

if ( [ -f /etc/nginx/sites-available/${WEBSITE_NAME} ] )
then
	/bin/chmod 600 /etc/nginx/sites-available/${WEBSITE_NAME}
	/bin/chown root:root /etc/nginx/sites-available/${WEBSITE_NAME}
fi

if ( [ -f ${HOME}/webserver/configuration/reverseproxy/nginx/nginx.conf ] )
then
	if ( [ "${DNS_CHOICE}" = "cloudflare" ] )
	then
		${HOME}/services/dns/TrustRemoteProxy.sh
		/bin/sed -i "s,#XXXXCLOUDFLAREXXXX,include /etc/nginx/cloudflare;,g" ${HOME}/webserver/configuration/reverseproxy/nginx/nginx.conf
	fi
	/bin/cat -s ${HOME}/webserver/configuration/reverseproxy/nginx/nginx.conf > /etc/nginx/nginx.conf
	/bin/chmod 600  /etc/nginx/nginx.conf
	/bin/chown root:root  /etc/nginx/nginx.conf
fi

if ( [ -f /etc/nginx/sites-available/${WEBSITE_NAME} ] )
then
	/bin/ln -s /etc/nginx/sites-available/${WEBSITE_NAME} /etc/nginx/sites-enabled/${WEBSITE_NAME}
fi

/bin/echo "/etc/nginx/sites-available/${WEBSITE_NAME}" > ${HOME}/runtime/WEBSERVER_CONFIG_LOCATION.dat

config_settings="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:settings" "stripped" | /bin/sed 's/|.*//g'`"

for setting in ${config_settings}
do
	setting_name="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $1}'`"
	setting_value="`/bin/echo ${setting} | /usr/bin/awk -F'=' '{print $2}'`"
	/usr/bin/find /etc/nginx -name '*' -type f -exec sed -i "s/${setting_name}.*/${setting_name} ${setting_value};/" {} +
done

if ( [ -f ${HOME}/webserver/configuration/reverseproxy/nginx/logrotate.conf ] )
then
	/bin/cp ${HOME}/webserver/configuration/reverseproxy/nginx/logrotate.conf /etc/logrotate.d/nginx
fi

if ( [ -d /var/www/html/html ] )
then
        /bin/rm -r /var/www/html/html
fi

${HOME}/utilities/processing/RunServiceCommand.sh nginx.service restart &
${HOME}/services/email/SendEmail.sh "THE NGINX WEBSERVER HAS BEEN INSTALLED" "Nginx reverse proxy is installed and primed" "INFO"
