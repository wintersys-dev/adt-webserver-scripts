#!/bin/sh
#####################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Setup the firewall
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
set -x 

export HOME="`/bin/cat /home/homedir.dat`"


BUILD_MACHINE_IP="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDMACHINEIP'`"
SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
VPC_IP_RANGE="`${HOME}/utilities/config/ExtractConfigValue.sh 'VPCIPRANGE'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"


if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FAIL2BAN" | /usr/bin/awk -F':' '{print $NF}'`" = "active" ] )
then
        if ( [ ! -f /etc/fail2ban/jail.d/jail.local ] )
        then
                if ( [ ! -d /etc/fail2ban/jail.d ] )
                then
                        /bin/mkdir -p /etc/fail2ban/jail.d
                fi
        fi

        if ( [ -d /etc/fail2ban/jail.d ] && ( [ ! -f /etc/fail2ban/jail.d/jail.local ] || [ "`/bin/grep '#ADTFAIL2BAN' /etc/fail2ban/jail.d/jail.local`" = "" ] ) )
        then
                /bin/cp ${HOME}/services/security/config/fail2ban.conf /etc/fail2ban/jail.d/jail.local
                /bin/sed -i "s/XXXXSSHPORTXXXX/${SSH_PORT}/g" /etc/fail2ban/jail.d/jail.local
                /bin/sed -i "s;#XXXXVPCIPRANGEXXXX;${VPC_IP_RANGE};g" /etc/fail2ban/jail.d/jail.local
                /bin/sed -i "s;#XXXXBUILDMACHINEIPXXXX;${BUILD_MACHINE_IP}/32;g" /etc/fail2ban/jail.d/jail.local
                ${HOME}/utilities/processing/RunServiceCommand.sh fail2ban restart
        fi
fi

if ( [ -f ${HOME}/runtime/firewall.dat ] && [ "`/usr/bin/find ${HOME}/runtime/firewall.dat -mmin -1 -print`" != "" ] )
then
        /bin/rm ${HOME}/runtime/FIREWALL-ACTIVE
fi

if ( [ -f ${HOME}/runtime/FIREWALL-ACTIVE ] )
then
        exit
fi

allow_vpc="sshd : `/bin/echo "${VPC_IP_RANGE}" | /usr/bin/awk -F'.' '{print $1,$2,$3.}' | /bin/sed 's/ /./g'`."
/bin/echo "${allow_vpc}" >> /etc/hosts.allow
/bin/echo "sshd : ${BUILD_MACHINE_IP}" >> /etc/hosts.allow

/bin/echo "ALL : ALL" >> /etc/hosts.deny

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh ACTIVEFIREWALLS:1`" = "0" ] && [ "`${HOME}/utilities/config/CheckConfigValue.sh ACTIVEFIREWALLS:3`" = "0" ] )
then
        exit
fi

openness=""
if ( [ "`${HOME}/utilities/config/ExtractBuildStyleValues.sh "FIREWALL" | /usr/bin/awk -F':' '{print $3}'`" = "limit" ] )
then
        openness="limit"
else
        openness="allow"
fi

if ( [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] && [ "${NO_REVERSE_PROXIES}" != "0" ] )
then
        openness="allow"
fi

if ( [ ! -f ${HOME}/runtime/FIREWALL-ACTIVE ] )
then
        if ( [ -f ${HOME}/runtime/authenticator/ipaddresses.dat ] )
        then
                /bin/rm ${HOME}/runtime/authenticator/ipaddresses.dat
        fi
fi

updated_ssh="0"
if ( [ "`/bin/grep ${VPC_IP_RANGE} /etc/ssh/sshd_config`" = "" ] )
then
        if ( [ "${SERVER_USER}" != "" ] && [ "${VPC_IP_RANGE}" != "" ] )
        then
                if ( [ "`/bin/grep "AllowUsers" /etc/ssh/sshd_config.d/99-hardening.conf | /bin/grep "${SERVER_USER}" | /bin/grep "${VPC_IP_RANGE}"`" = "" ] )
                then
                        /bin/echo "AllowUsers ${SERVER_USER}@${VPC_IP_RANGE}" >> /etc/ssh/sshd_config.d/99-hardening.conf
                        updated_ssh="1"
                fi
        fi
fi

if ( [ "`/bin/grep ${BUILD_MACHINE_IP} /etc/ssh/sshd_config`" = "" ] )
then
        if ( [ "${SERVER_USER}" != "" ] && [ "${BUILD_MACHINE_IP}" != "" ] )
        then
                if ( [ "`/bin/grep "AllowUsers" /etc/ssh/sshd_config.d/99-hardening.conf | /bin/grep "${SERVER_USER}" | /bin/grep "${BUILD_MACHINE_IP}"`" = "" ] )
                then
                        /bin/echo "AllowUsers ${SERVER_USER}@${BUILD_MACHINE_IP}" >> /etc/ssh/sshd_config.d/99-hardening.conf
                        updated_ssh="1"
                fi
        fi
fi

if ( [ "${updated_ssh}" = "1" ] )
then
        ${HOME}/utilities/processing/RunServiceCommand.sh "ssh" restart
fi

${HOME}/services/security/firewall/ufw/InitialiseFirewall.sh

status="$?"
if [ "${status}" = "10" ]
then
        initialised="1"
fi

${HOME}/services/security/firewall/ufw/KnickersUp.sh
${HOME}/services/security/firewall/ufw/DenyAuthenticator.sh
${HOME}/services/security/firewall/ufw/AllowWireguard.sh
status="$?"
if [ "${status}" = "10" ]
then
        updated="1"
fi
${HOME}/services/security/firewall/ufw/AllowBuildMachine.sh
status="$?"
if [ "${status}" = "10" ]
then
        updated="1"
fi
${HOME}/services/security/firewall/ufw/AllowVPC.sh
status="$?"
if [ "${status}" = "10" ]
then
        updated="1"
fi
${HOME}/services/security/firewall/ufw/AllowCustomPorts.sh
status="$?"
if [ "${status}" = "10" ]
then
        updated="1"
fi
${HOME}/services/security/firewall/ufw/ReloadFirewall.sh ${updated} ${initialised}


