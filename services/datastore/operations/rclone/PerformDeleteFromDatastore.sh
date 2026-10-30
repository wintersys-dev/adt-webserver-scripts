#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging & Empty Directory Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data removal operations inside targeted
#              cloud datastores. It parses endpoints directly from partitioned rclone
#              profile configurations, processes special 'root' overrides for tree 
#              wipes, and commands the underlying storage layout engine to delete objects
#              and prune unmapped parent directory trees safely.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to delete.
# @param       $2  [Required] Integer configuration ID used to select the targeted rclone profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /usr/bin/rclone storage integration engine software utility.
#              - /root/.config/rclone/rclone.conf-${count} targeted cluster registration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target object successfully purged from the datastore namespace.
# @exit        1  Failure: Missing mandatory parameters or rclone execution driver failure.
###################################################################################
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

rmdirs=""
if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'root$'`" != "" ] )
then
  file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed "s/root$//g"`"
  rmdirs="--rmdirs"
fi

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /bin/grep "^endpoint" | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} delete s3:${file_to_delete} ${rmdirs} 2>/dev/null

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
