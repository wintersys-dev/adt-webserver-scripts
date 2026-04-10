#!/bin/sh
######################################################################################################
# Description: This script will install the nginx webserver
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

MOD_SECURITY="`${HOME}/utilities/config/ExtractConfigValue.sh 'MODSECURITY'`"
NO_REVERSE_PROXY="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"


apt=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt" ] )
then
        apt="/usr/bin/apt"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
        apt="/usr/bin/apt-get"
fi

${HOME}/installation/PurgeApache.sh

export DEBIAN_FRONTEND=noninteractive
update_command="${apt} -o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y update " 
install_command="${apt} -o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y install " 
install_command_confold="${apt} -o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -o Dpkg::Options::=--force-confold -qq -y install " 

${HOME}/installation/PurgeApache.sh

count="0"
while ( [ ! -f /usr/sbin/nginx ] && [ "${count}" -lt "5" ] )
do
        if ( [ "${apt}" != "" ] )
        then
                if ( [ "${BUILDOS}" = "ubuntu" ] )
                then
                        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
                        then
                                eval ${install_command} apache2-utils
                        fi
                        if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX" | /usr/bin/awk -F':' '{print $NF}'`" != "cloud-init" ] )
                        then
                                if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:source'`" = "1" ] )
                                then
                                        if ( [ ! -f /etc/nginx/BUILT_FROM_SOURCE ] )
                                        then
                                                software_package_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:software-packages" "stripped"`"
                                                if ( [ "${software_package_list}" != "" ] )
                                                then
                                                        eval ${install_command} ${software_package_list}
                                                fi
                                                if ( [ "${MOD_SECURITY}" = "1" ] )
                                                then
                                                        if ( ( [ "${NO_REVERSE_PROXY}" = "0" ] || ( [ "${NO_REVERSE_PROXY}" != "0" ] && [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] ) ) || [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
                                                        then
                                                                ${install_command} g++ apt-utils autoconf automake build-essential libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev libtool libxml2-dev libyajl-dev pkgconf zlib1g-dev
                                                                ${HOME}/installation/modsecurity/ConfigureModSecurityForNginx.sh
                                                        fi
                                                fi
                                                ${HOME}/installation/nginx/BuildNginxFromSource.sh "Ubuntu"  
                                        fi

                                        #Make sure nginx avaiable as a service and enable and start it
                                        if ( [ ! -f /lib/systemd/services/nginx.service ] )
                                        then
                                                /bin/cp ${HOME}/installation/nginx/nginx.service /lib/systemd/services/nginx.service
                                                ${HOME}/utilities/processing/RunServiceCommand.sh nginx restart
                                        fi
                                elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:repo:os'`" = "1" ] )
                                then
                                        eval ${install_command} nginx
								elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:repo:official'`" = "1" ] )
                                then		
                                        eval ${install_command} curl gnupg2 ca-certificates lsb-release ubuntu-keyring
                                        /usr/bin/curl https://nginx.org/keys/nginx_signing.key | /usr/bin/gpg --dearmor | /usr/bin/tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
                                        if ( [ "`/usr/bin/gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg | /bin/egrep "8540A6F18833A80E9C1653A42FD21310B49F6B46|573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62|9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3" | /usr/bin/wc -l`" = "3" ] )
                                        then
											if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:mainline'`" = "1" ] )
											then
	                                        	/bin/echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | /usr/bin/tee /etc/apt/sources.list.d/nginx.list		
	                                        else
												/bin/echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | /usr/bin/tee /etc/apt/sources.list.d/nginx.list		
											fi
											/bin/echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | /usr/bin/tee /etc/apt/preferences.d/99nginx
	                                        eval ${update_command} 
	                                        eval ${install_command_confold} nginx
                                        else
                                                exit
                                        fi
                                        ${HOME}/utilities/processing/RunServiceCommand.sh "unmask" "nginx"

                                        if (  [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
                                        then
                                                modules_list=""
                                        elif ( [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] )
                                        then
                                                modules_list=""
                                        elif ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] )
                                        then
                                                modules_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:modules-list" "stripped"`"
                                        fi

                                        if ( [ "${modules_list}" != "" ] )
                                        then
                                                eval ${install_command} ${modules_list}
                                        fi
                                        /bin/touch /etc/nginx/BUILT_FROM_REPO
                                fi
                        fi
                fi

                if ( [ "${BUILDOS}" = "debian" ] )
                then
                        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
                        then
                                eval ${install_command} apache2-utils
                        fi
                        if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX" | /usr/bin/awk -F':' '{print $NF}'`" != "cloud-init" ] )
                        then
                                if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:source'`" = "1" ] )
                                then
                                        if ( [ ! -f /etc/nginx/BUILT_FROM_SOURCE ] )
                                        then
                                                software_package_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:software-packages" "stripped"`"
                                                if ( [ "${software_package_list}" != "" ] )
                                                then
                                                        eval ${install_command} ${software_package_list}
                                                fi

                                                if ( [ "${MOD_SECURITY}" = "1" ] )
                                                then
                                                        if ( ( [ "${NO_REVERSE_PROXY}" = "0" ] || ( [ "${NO_REVERSE_PROXY}" != "0" ] && [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] ) ) || [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
                                                        then
                                                                ${install_command} g++ apt-utils autoconf automake build-essential libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev libtool libxml2-dev libyajl-dev pkgconf zlib1g-dev
                                                                ${HOME}/installation/modsecurity/ConfigureModSecurityForNginx.sh
                                                        fi
                                                fi
                                                ${HOME}/installation/nginx/BuildNginxFromSource.sh "Debian"        
                                        fi
                                        #Make sure nginx avaiable as a service and enable and start it
                                        if ( [ ! -f /lib/systemd/services/nginx.service ] )
                                        then
                                                /bin/cp ${HOME}/installation/nginx/nginx.service /lib/systemd/services/nginx.service
                                                ${HOME}/utilities/processing/RunServiceCommand.sh nginx restart
                                        fi
								elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:repo:os'`" = "1" ] )
                                then  
                                        eval ${install_command} nginx
								elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:repo:official'`" = "1" ] )
								then
                                        eval ${install_command} curl gnupg2 ca-certificates lsb-release debian-archive-keyring
                                        /bin/mkdir /root/.gnupg && /bin/chmod 700 /root/.gnupg
                                        /bin/mkdir ${HOME}/.gnupg && /bin/chmod 700 ${HOME}/.gnupg
                                        /usr/bin/curl https://nginx.org/keys/nginx_signing.key | /usr/bin/gpg --dearmor | /usr/bin/tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
                                        if ( [ "`/usr/bin/gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg | /bin/egrep "8540A6F18833A80E9C1653A42FD21310B49F6B46|573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62|9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3" | /usr/bin/wc -l`" = "3" ] )
                                        then
												if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:mainline'`" = "1" ] )
												then
										        	/bin/echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | /usr/bin/tee /etc/apt/sources.list.d/nginx.list
												else
                                                	/bin/echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian `lsb_release -cs` nginx" | /usr/bin/tee /etc/apt/sources.list.d/nginx.list
                                                fi
												/bin/echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | /usr/bin/tee /etc/apt/preferences.d/99nginx
                                                eval ${update_command} 
                                                eval ${install_command_confold} nginx
                                        else
                                                exit
                                        fi

                                        if (  [ "`/usr/bin/hostname | /bin/grep 'auth-'`" != "" ] )
                                        then
                                                modules_list=""
                                        elif ( [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] )
                                        then
                                                modules_list=""
                                        elif ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] )
                                        then
                                                modules_list="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:modules-list" "stripped"`"
                                        fi

                                        if ( [ "${modules_list}" != "" ] )
                                        then
                                                eval ${install_command} ${modules_list}
                                        fi
                                        ${HOME}/utilities/processing/RunServiceCommand.sh "unmask" "nginx"
                                        /bin/touch /etc/nginx/BUILT_FROM_REPO
                                fi
                        fi
                fi
        fi
        count="`/usr/bin/expr ${count} + 1`"
done

if ( [ ! -x /usr/sbin/nginx ] && [ "${count}" = "5" ] )
then
        ${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR NGINX" "I believe that nginx hasn't installed correctly, please investigate" "ERROR"
else
        /bin/touch ${HOME}/runtime/installedsoftware/InstallNGINX.sh
fi

