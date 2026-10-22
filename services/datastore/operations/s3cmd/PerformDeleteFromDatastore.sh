#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Implement the deletion of a file from a datastore
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
#set -x

file_to_delete="${1}"
count="${2}"
datastore_tool=""

recursive=""

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:s3cmd'`" = "1" ] )
then
        datastore_tool="/usr/bin/s3cmd"
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:s5cmd'`" = "1" ]  )
then
        datastore_tool="/usr/bin/s5cmd"
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:rclone'`" = "1" ]  )
then
        datastore_tool="/usr/bin/rclone"
fi

if ( [ "${datastore_tool}" = "/usr/bin/s3cmd" ] )
then
        if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'delete-all$'`" != "" ] )
        then
                recursive=" --recursive"
                file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/delete-all//g'`"
        fi

        host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
        datastore_cmd="${datastore_tool} --recursive --force  --config=/root/.s3cfg-${count} --host=https://${host_base} del s3://"
elif ( [ "${datastore_tool}" = "/usr/bin/s5cmd" ] )
then
        if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'delete-all$'`" != "" ] )
        then
                file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/delete-all//g'`"
                file_to_delete="${file_to_delete}\*"
        fi
        host_base="`/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="/usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} rm s3://"
elif ( [ "${datastore_tool}" = "/usr/bin/rclone" ] )
then
        host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /bin/grep "^endpoint" | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        delete_all="0"
        if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'delete-all$'`" != "" ] )
        then
                delete_all="1"
                file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/delete-all//g'`"
        elif ( [ "${file_to_delete}" != "" ] && [ "`/bin/echo ${file_to_delete} | /bin/grep '*'`" != "" ] )
        then
                file_to_include="`/bin/echo ${file_to_delete} | /usr/bin/awk -F'/' '{print $NF}'`"
                include="--filter '+ "${file_to_include}"'"
                file_to_delete="`/bin/echo ${file_to_delete} | /usr/bin/cut -d'/' -f1`"
        fi

        datastore_cmd="${datastore_tool} --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} ${include} delete s3:"
fi

if ( [ "${delete_all}" = "1" ] )
then
        eval ${datastore_cmd}${file_to_delete} ${recursive} --include \"*\"
else
        eval ${datastore_cmd}${file_to_delete} ${recursive} 
fi

#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Tool/Script: Automated S3 Utility to delete a file in the datastore
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates the deletion of a specific file from a datastore
#
# Arguments:
#              $1 - <file_to_delete>     : File held in the datastore to be deleted
#              $2 - <count>              : Integer ID used to select the rclone config profile.
#
# Requirements:
#              - /usr/bin/s3cmd installed and accessible.
#              - A valid profile located at /root/.config/rclone/rclone.conf-${count}
#              - Standard output/logging routes configured on File Descriptors 3 and 4.
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
######################################################################################
######################################################################################
#set -x

set -e

if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        /bin/echo "Error: 2 arguments are required."
        /bin/echo "Usage: $0 <file_to_delete> <count>"
        exit 1
fi

file_to_delete="${1}"
count="${2}"

file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/\*$//g'`"
host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd --recursive --force  --config=/root/.s3cfg-${count} --host=https://${host_base} del s3://${file_to_delete} 2>/dev/null

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
