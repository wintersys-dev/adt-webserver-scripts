#!/bin/sh
######################################################################################################
# Description: This script will install the php base
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
#set -x

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh APPLICATIONLANGUAGE:PHP`" = "0" ] )
then
        exit
fi

BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
BUILDOS_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOSVERSION'`"
PHP_VERSION="`${HOME}/utilities/config/ExtractConfigValue.sh 'PHPVERSION'`"
WEBSERVER_TYPE="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSERVERCHOICE'`"


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
HOME="`/bin/cat /home/homedir.dat`"

manager=""
options=""
tail_options=""
nala_update_command=""
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
	manager="${HOME}/installation/nala_wrapper.sh"
	tail_options="-y"
	nala_update_command="/usr/bin/nala update"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "aptitude" ] )
then
        manager="${HOME}/installation/aptitude_wrapper.sh"
        options="-y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "aptitude" ] )
then
        manager="${HOME}/installation/aptitude_wrapper.sh"
        options="-y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"
fi    

export DEBIAN_FRONTEND=noninteractive
add_repository_command="/usr/bin/add-apt-repository -y "
install_command="${manager} ${options} install "
update_command="${manager} ${options} update "

if ( [ "${manager}" != "" ] )
then
        if ( [ "${BUILDOS}" = "ubuntu" ] )
        then
                if ( [ "${BUILDOS_VERSION}" = "24.04" ] || [ "${BUILDOS_VERSION}" = "26.04" ] )
                then
                        if ( ( [ "${BUILDOS_VERSION}" = "24.04" ] && [ "${PHP_VERSION}" = "8.3" ] ) || ( [ "${BUILDOS_VERSION}" = "26.04" ] && [ "${PHP_VERSION}" = "8.5" ] ) )
                        then
                                PHP_VERSION=""
                                ${install_command} software-properties-common ${tail_options}
                                ${add_repository_command} universe
                                ${update_command}
                                ${install_command} ${tail_options}
                                ${install_command} software-properties-common ${tail_options}
                        else
                          #      ${update_command}
                          #      ${install_command} software-properties-common
                          #      ${add_repository_command} ppa:ondrej/php
                          #      if ( [ "${WEBSERVER_TYPE}" = "APACHE" ] )
                          #      then
                          #              ${add_repository_command} ppa:ondrej/apache2
                          #      fi
                          #      if ( [ "${WEBSERVER_TYPE}" = "NGINX" ] )
                          #      then
                          #              ${add_repository_command} ppa:ondrej/nginx-mainline
                          #      fi
                          #      ${update_command}
                           #     ${install_command} php${PHP_VERSION}

                                ${install_command} ca-certificates curl ${tail_options}
                                /usr/bin/curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
                                . /etc/os-release

                                if ( [ "${BUILDOS_VERSION}" = "24.04" ] )
                                then
                                        version_codename="noble"
                                fi
                                if ( [ "${BUILDOS_VERSION}" = "26.04" ] )
                                then
                                        version_codename="resolute"
                                fi

                                case "${version_codename}" in
                                  resolute|noble)
    printf '%s\n' \
      'Types: deb' \
      'URIs: https://packages.sury.org/php/' \
      "Suites: ${version_codename}" \
      'Components: main' \
      "Architectures: amd64" \
      'Signed-By: /usr/share/keyrings/deb.sury.org-php.gpg' | /usr/bin/tee /etc/apt/sources.list.d/php.sources > /dev/null
    ;;
  *)
    printf 'Supported combinations: Ubuntu 26.04 on amd64; Ubuntu 26.04,24.04 on amd64. This host reports %s/%s.\n' "${version_codename}" "amd64" >&2
    false
    ;;
                                esac

                                ${update_command}
								${nala_update_command}
                                /usr/bin/update-alternatives --set php /usr/bin/php${PHP_VERSION}
                        fi

                        php_modules="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PHP" "stripped" | /bin/sed 's/|.*//g'`"

                        for module in ${php_modules}
                        do
                                ${install_command} php${PHP_VERSION}-${module} ${tail_options}
                        done
                fi
        fi

        if ( [ "${BUILDOS}" = "debian" ] )
        then
                if ( [ "${BUILDOS_VERSION}" = "13" ] )
                then
                        if ( [ "${PHP_VERSION}" = "8.4" ] )
                        then
                                PHP_VERSION=""
                                ${install_command} lsb-release apt-transport-https ca-certificates software-properties-common  ${tail_options}
                                ${update_command}
                                ${install_command} php ${tail_options}
                        else
                                ${install_command} lsb-release apt-transport-https ca-certificates software-properties-common  ${tail_options}
                                /usr/bin/wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                                /bin/echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
                                ${update_command}
								${nala_update_command}
                                ${install_command} php${PHP_VERSION} ${tail_options}
                                /usr/bin/update-alternatives --set php /usr/bin/php${PHP_VERSION}
                        fi
                fi

                php_modules="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PHP" "stripped" | /bin/sed 's/|.*//g'`"

                for module in ${php_modules}
                do
                        ${install_command} php${PHP_VERSION}-${module} ${tail_options}
                done
                
        fi
fi

/bin/touch ${HOME}/runtime/installedsoftware/InstallPHPBase.sh
