#!/bin/sh
####################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: This script will configure the datastore tools on your webserver
# it will configure itself based on the template in the subdirectory "init-files".
# If this tool later changes the format of its configuration the template in init-files
# will have to be updated to reflect any breaking format changes
#######################################################################################
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
set -x

export HOME="`/bin/cat /home/homedir.dat`"
SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"

if ( [ "${1}" = "" ] )
then
        S3_ACCESS_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3ACCESSKEY'`"
else
        S3_ACCESS_KEY="${1}"
fi

if ( [ "${2}" = "" ] )
then
        S3_SECRET_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3SECRETKEY'`"
else
        S3_SECRET_KEY="${2}"
fi

if ( [ "${3}" = "" ] )
then
        S3_LOCATION="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3LOCATION'`"
else
        S3_LOCATION="${3}"
fi

if ( [ "${4}" = "" ] )
then
        S3_HOST_BASE="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE'`"
else
        S3_HOST_BASE="${4}"
fi


datastore_tool="/usr/bin/s3cmd"
if ( [ -f ${HOME}/.s3cfg ] )
then
        /bin/rm ${HOME}/.s3cfg
fi

/bin/cp ${HOME}/services/datastore/init-files/s3-cfg.tmpl ${HOME}/.s3cfg

if ( [ "${S3_ACCESS_KEY}" != "" ] )
then
        /bin/sed -i "s/XXXXACCESSKEYXXXX/${S3_ACCESS_KEY}/" ${HOME}/.s3cfg
else
        /bin/echo "${0} Couldn't find the S3_ACCESS_KEY setting" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi

if ( [ "${S3_SECRET_KEY}" != "" ] )
then
        /bin/sed -i "s;XXXXSECRETKEYXXXX;${S3_SECRET_KEY};" ${HOME}/.s3cfg
else
        /bin/echo "${0} Couldn't find the S3_SECRET_KEY setting" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi

if ( [ "${S3_LOCATION}" != "" ] )
then
        /bin/sed -i "s/XXXXLOCATIONXXXX/${S3_LOCATION}/" ${HOME}/.s3cfg
else
        /bin/echo "${0} Couldn't find the S3_LOCATION setting" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi

if ( [ "${S3_HOST_BASE}" != "" ] )
then
        /bin/sed -i "s/XXXXHOSTBASEXXXX/${S3_HOST_BASE}/" ${HOME}/.s3cfg

        if ( [ "`/bin/grep '^alias s3cmd=' /root/.bashrc`" = "" ] )
        then
                /bin/echo "alias s3cmd='/usr/bin/s3cmd --config=/root/.s3cfg --host=https://${S3_HOST_BASE} '" >> /root/.bashrc
        fi
else
        /bin/echo "${0} Couldn't find the S3_HOST_BASE setting" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi


/bin/cp ${HOME}/.s3cfg /root/.s3cfg
/bin/chown ${SERVER_USER}:${SERVER_USER} ${HOME}/.s3cfg


if ( [ "$?" != "0" ] )
then
        /bin/echo "${0} Your datastore didn't configure correctly on this machine and that will cause the deployment to break" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi
