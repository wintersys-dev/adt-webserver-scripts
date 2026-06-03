#!/bin/sh
#####################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: This will add a webserver UP address to  the current list of active 
# webserver IP addresses in a reverse proxy machine. 
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
######################################################################################
######################################################################################
#set -x

WEBSITE_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME'`"

reverseproxy_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "reverseproxyips/*"`"
updated="0"

for reverseproxy_ip in ${reverseproxy_ips}
do
	if ( [ -f /etc/apache2/sites-available/${WEBSITE_NAME} ] )
	then
		if ( [ "`/bin/grep ${reverseproxy_ip} /etc/apache2/sites-available/${WEBSITE_NAME}`" = "" ] )
		then
			if ( [ "`/usr/bin/curl -m 2 --insecure -I 'https://'${reverseproxy_ip}':443/index.php' 2>&1 | /bin/grep 'HTTP' | /bin/grep -w '200\|301\|302\|303'`" != "" ] )
			then
				node_no="`/bin/grep "BalancerMember" /etc/apache2/sites-available/${WEBSITE_NAME} | /usr/bin/wc -l`"
				node_no="`/usr/bin/expr ${node_no} + 1`"
				/bin/sed -i "/xxxxREVERSEPROXYIPHTTPSxxxx/a         BalancerMember https://${reverseproxy_ip}:443 route=node${node_no}" /etc/apache2/sites-available/${WEBSITE_NAME}
				updated="1"
			fi
		fi
	fi

	if ( [ -f /etc/nginx/sites-available/${WEBSITE_NAME} ] )
	then
		if ( [ "`/bin/grep ${reverseproxy_ip} /etc/nginx/sites-available/${WEBSITE_NAME}`" = "" ] )
		then
			if ( [ "`/usr/bin/curl -m 2 --insecure -I 'https://'${reverseproxy_ip}':443/index.php' 2>&1 | /bin/grep 'HTTP' | /bin/grep -w '200\|301\|302\|303'`" != "" ] )
			then
				/bin/sed -i "/xxxxREVERSEPROXYIPHTTPSxxxx/a         server ${reverseproxy_ip}:443;" /etc/nginx/sites-available/${WEBSITE_NAME}
				updated="1"
			fi
        fi
	fi

	if ( [ -f /etc/lighttpd/lighttpd.conf ] )
	then
		if ( [ "`/bin/grep ${reverseproxy_ip} /etc/lighttpd/lighttpd.conf`" = "" ] )
		then
			if ( [ "`/usr/bin/curl -m 2 --insecure -I 'https://'${reverseproxy_ip}':443/index.php' 2>&1 | /bin/grep 'HTTP' | /bin/grep -w '200\|301\|302\|303'`" != "" ] )
			then
				/bin/sed -i '/xxxxREVERSEPROXYIPHTTPSxxxx/a          ( "host" => "'${reverseproxy_ip}'", "port" => 80 )' /etc/lighttpd/lighttpd.conf
                /bin/sed -i "s/80 )$/80 ),/g" /etc/lighttpd/lighttpd.conf
                /bin/sed -zEi '$ s/(.*),/\1/' /etc/lighttpd/lighttpd.conf
                updated="1"
            fi
        fi
	fi
done

if ( [ "${updated}" = "1" ] )
then
        ${HOME}/webserver/ReloadWebserver.sh
fi
