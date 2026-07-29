#!/bin/sh
###########################################################################################################
# Description: This will generate the wireguard server interface for this reverse proxy machine. 
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
#set -x

export HOME="`/bin/cat /home/homedir.dat`"
SSH_PORT="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSHPORT'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL'`"
wireguard_port="`/usr/bin/expr ${SSH_PORT} + 1`"

if ( [ ! -f /etc/wireguard/postup.sh ] && [ -f ${HOME}/webserver/configuration/reverseproxy/wire-guard/postup.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/reverseproxy/wire-guard/postup.sh /etc/wireguard
        /bin/sed -i "s/XXXXWG_PORTXXXX/${wireguard_port}/g" /etc/wireguard/postup.sh
        /bin/chmod 750 /etc/wireguard/postup.sh
fi

if ( [ ! -f /etc/wireguard/postdown.sh ]  && [ -f ${HOME}/webserver/configuration/reverseproxy/wire-guard/postdown.sh ] )
then
        /bin/cp ${HOME}/webserver/configuration/reverseproxy/wire-guard/postdown.sh /etc/wireguard
        /bin/sed -i "s/XXXXWG_PORTXXXX/${wireguard_port}/g" /etc/wireguard/postdown.sh
        /bin/chmod 750 /etc/wireguard/postdown.sh
fi

if ( [ ! -d ${HOME}/runtime/wire-guard/server ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/server
fi

if ( [ ! -f /etc/wireguard/wg0.conf ] )
then
        if ( [ ! -f ${HOME}/runtime/wire-guard/server/server_private.key ] )
        then
                umask 077
                /usr/bin/wg genkey > ${HOME}/runtime/wire-guard/server/server_private.key
                /bin/chmod 600 ${HOME}/runtime/wire-guard/server/server_private.key
                /bin/cat ${HOME}/runtime//wire-guard/server/server_private.key | /usr/bin/wg pubkey > ${HOME}/runtime/wire-guard/server/server_public.key

                server_private_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_private.key`"
                server_public_key="`/bin/cat ${HOME}/runtime/wire-guard/server/server_public.key`"

                /bin/echo "[Interface]
                PrivateKey = ${server_private_key}
                Address = 10.`/usr/bin/hostname | /usr/bin/awk -F'-' '{print $2}'`.0.1/32 
                MTU = 1380
                ListenPort = ${wireguard_port}
                SaveConfig = false
                PostUp = /etc/wireguard/postup.sh
                PostDown = /etc/wireguard/postdown.sh" > /etc/wireguard/wg0.conf
                
                # Write the wireguard wg0.conf to the datastore with reverse proxy number in it and check for it when a machine first boots. If there is a wg0 available for 
                # reverse proxy 1 or reverse proxy 2 then download the wg0 file to the reverse proxy with the same index and restart wireguard
                # Send an email telling the user that the endpoint IP address has changed (maybe record the original IP address in the datastore)
        fi
fi

