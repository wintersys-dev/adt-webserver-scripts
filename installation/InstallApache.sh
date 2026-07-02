#!/bin/sh
######################################################################################################
# Description: This script will install the apache webserver
# Author: Peter Winter
# Date: 17/01/2017
#######################################################################################################
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

if ( [ "${1}" != "" ] )
then
	buildos="${1}"
fi

if ( [ "${buildos}" = "" ] )
then
	BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
else 
	BUILDOS="${buildos}"
fi

PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
MOD_SECURITY="`${HOME}/utilities/config/ExtractConfigValue.sh 'MODSECURITY'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"

manager=""
options=""
tail_options=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt" ] )
then
	manager="/usr/bin/apt"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
	manager="/usr/bin/apt-get"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "nala" ] )
then
	manager="/usr/bin/nala"
	tail_options="-y"
fi

export DEBIAN_FRONTEND=noninteractive
install_command="${manager} ${options} install " 

${HOME}/installation/PurgeApache.sh

count="0"
while ( [ ! -f /usr/sbin/apache2 ] && [ "${count}" -lt "5" ] )
do
	if ( [ "${manager}" != "" ] )
	then
		if ( [ "${BUILDOS}" = "ubuntu" ] )
		then
			if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
			then
				eval ${install_command} apache2-utils ${tail_options}
			fi
			if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE" | /usr/bin/awk -F':' '{print $NF}'`" != "cloud-init" ] )
			then
				if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'APACHE:source'`" = "1" ] )
				then
					if ( [ ! -f /etc/apache2/BUILT_FROM_SOURCE ] )
					then    		     		
						software_package_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE:software-packages" "stripped"`"
						if ( [ "${software_package_list}" != "" ] )
						then
							eval ${install_command} ${software_package_list} ${tail_options}
						fi	
						
						${HOME}/installation/apache/BuildApacheFromSource.sh  "Ubuntu" 		
					fi
				elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'APACHE:repo'`" = "1" ] )
				then
					eval ${install_command} apache2 ${tail_options}
					
					if (  [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
					then
						modules_list="mpm_event ssl headers proxy_fcgi"
					elif ( [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] )
					then
						modules_list="proxy proxy_http headers ssl proxy_balancer lbmethod_byrequests slotmem_shm authz_core rewrite remoteip"
					elif ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] )
					then
						modules_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE:modules-list" "stripped"`"
					fi
					if ( [ "${modules_list}" != "" ] )
					then
						for module in ${modules_list}
						do
							if ( [ "`/bin/echo ${module} | /bin/grep 'mpm_'`" != "" ] )
							then
								/usr/sbin/a2dismod mpm_prefork
							fi
							/usr/sbin/a2enmod ${module}
							/usr/sbin/a2enconf ${module}
						done
					fi
					/bin/touch /etc/apache2/BUILT_FROM_REPO
				fi
			fi   

			if ( [ "${MOD_SECURITY}" = "1" ] )
			then
				if ( ( [ "${NO_REVERSE_PROXIES}" = "0" ] || ( [ "${NO_REVERSE_PROXIES}" != "0" ] && [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] ) ) || [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
				then
					${install_command} libapache2-mod-security2 ${tail_options}
					${HOME}/installation/modsecurity/ConfigureModSecurityForApache.sh
				fi
			fi
		fi

		if ( [ "${BUILDOS}" = "debian" ] )
		then
			if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
			then
				eval ${install_command} apache2-utils ${tail_options}
			fi
			
			if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE" | /usr/bin/awk -F':' '{print $NF}'`" != "cloud-init" ] )
			then
				if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'APACHE:source'`" = "1" ] )
				then
					if ( [ ! -f /etc/apache2/BUILT_FROM_SOURCE ] )
					then
						${HOME}/installation/PurgeApache.sh
						software_package_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE:software-packages" "stripped"`"
						if ( [ "${software_package_list}" != "" ] )
						then
							eval ${install_command} ${software_package_list} ${tail_options}
						fi 
						${HOME}/installation/apache/BuildApacheFromSource.sh  "Debian" 	
					fi
				elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'APACHE:repo'`" = "1" ] )
				then
					eval ${install_command} apache2 ${tail_options}
					if (  [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
					then
						modules_list="mpm_event ssl headers proxy_fcgi"
					elif ( [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] )
					then
						modules_list="proxy proxy_http headers ssl proxy_balancer lbmethod_byrequests slotmem_shm authz_core rewrite remoteip"
					elif ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] )
					then
						modules_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "APACHE:modules-list" "stripped"`"
					fi
					if ( [ "${modules_list}" != "" ] )
					then
						for module in ${modules_list}
						do
							if ( [ "`/bin/echo ${module} | /bin/grep 'mpm_'`" != "" ] )
							then
								/usr/sbin/a2dismod mpm_prefork
							fi
							/usr/sbin/a2enmod ${module}
							/usr/sbin/a2enconf ${module}
						done
					fi
					/bin/touch /etc/apache2/BUILT_FROM_REPO
				fi
			fi

			if ( [ "${MOD_SECURITY}" = "1" ] )
			then
				if ( ( [ "${NO_REVERSE_PROXIES}" = "0" ] || ( [ "${NO_REVERSE_PROXIES}" != "0" ] && [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] ) ) || [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
				then
					${install_command} libapache2-mod-security2 ${tail_options}
					${HOME}/installation/modsecurity/ConfigureModSecurityForApache.sh
				fi
			fi
		fi
	fi
	count="`/usr/bin/expr ${count} + 1`"
done

if ( ( [ ! -x /usr/sbin/apache2 ] && [ ! -x /usr/local/apache2/bin/httpd ] ) && [ "${count}" = "5" ] )
then
	${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR APACHE" "I believe that apache hasn't installed correctly, please investigate" "ERROR"
else
	/bin/touch ${HOME}/runtime/installedsoftware/InstallApache.sh				
fi

