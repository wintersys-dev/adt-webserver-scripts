#!/bin/sh
######################################################################################################
# Description: This script will install ansible for use with Linode
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

HOME="`/bin/cat /home/homedir.dat`"

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
	manager="${HOME}/installation/nala_wrapper.sh"
	tail_options="-y"
elif ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "PACKAGEMANAGER" | /usr/bin/awk -F':' '{print $NF}'`" = "aptitude" ] )
then
        manager="${HOME}/installation/aptitude_wrapper.sh"
        options="-y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"
fi

export DEBIAN_FRONTEND=noninteractive
install_command="${manager} ${options} install "
update_command="${manager} ${options} update "


if ( [ "${manager}" != "" ] )
then
	if ( [ "${BUILDOS}" = "ubuntu" ] )
	then
		eval ${update_command}
		eval ${install_command} ansible-core
                        
		if ( [ ! -d ${HOME}/runtime/ansible-env ] )
		then
			/bin/mkdir -p ${HOME}/runtime/ansible-env
		fi

		python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"
		eval ${install_command} python${python_version}-venv ${tail_options}

		# 1. Create a virtual environment (e.g., named 'ansible-env')        
		python3 -m venv ${HOME}/runtime/ansible-env

		# 2. Activate the virtual environment
		. ${HOME}/runtime/ansible-env/bin/activate

		# 3. Upgrade pip and install the requirements securely
		pip install --upgrade pip

		/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

		if [ $? -eq 0 ]
		then
			cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
		fi
		pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt
	fi

	if ( [ "${BUILDOS}" = "debian" ] )
	then
		eval ${update_command}
		eval ${install_command} ansible-core

		if ( [ ! -d ${HOME}/runtime/ansible-env ] )
		then
			/bin/mkdir -p ${HOME}/runtime/ansible-env
		fi

		python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"
		eval ${install_command} python${python_version}-venv ${tail_options}

		# 1. Create a virtual environment (e.g., named 'ansible-env')        
		python3 -m venv ${HOME}/runtime/ansible-env

		# 2. Activate the virtual environment
		. ${HOME}/runtime/ansible-env/bin/activate

		# 3. Upgrade pip and install the requirements securely
		pip install --upgrade pip

		/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

		if [ $? -eq 0 ]
		then
			cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
		fi
		pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt
	fi
fi


if ( [ ! -x /usr/bin/ansible-playbook ] || [ "`ANSIBLE_LOAD_CALLBACK_PLUGINS=1 ANSIBLE_STDOUT_CALLBACK=json ansible localhost -m ping | jq -r '.plays[0].tasks[0].hosts.localhost.ping'`" != "pong" ] )
then
	${HOME}/services/email/SendEmail.sh "INSTALLATION ERROR ANSIBLE" "I believe that ansible hasn't installed correctly, please investigate" "ERROR"
else
	/bin/touch ${HOME}/runtime/installedsoftware/InstallLinodeAnsible.sh	
fi


