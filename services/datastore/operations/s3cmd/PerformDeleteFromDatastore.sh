#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging & Recursive Tree Deletion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level file deletion and directory scrubbing 
#              operations inside targeted cloud datastores using s3cmd. It extracts 
#              endpoint parameters from partitioned s3cmd configuration profiles, 
#              processes dynamic 'root' directory overrides for absolute tree wipes, 
#              and commands the storage engine to drop targets and prune structural paths.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to delete.
# @param       $2  [Required] Integer configuration ID used to select the targeted s3cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /usr/bin/s3cmd storage integration command-line software utility.
#              - /root/.s3cfg-${count} targeted cluster registration configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Enforces structural path filtering by scrubbing trailing "root" overrides from namespaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target object successfully purged from the datastore namespace.
# @exit        1  Failure: Missing mandatory parameters or s3cmd execution driver failure.
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

#file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/\*$//g'`"

recursive=""
if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'root$'`" != "" ] )
then
  file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed "s/root$//g"`"
  recursive="--recursive"
fi

host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd ${recursive} --force  --config=/root/.s3cfg-${count} --host=https://${host_base} del s3://${file_to_delete} 2>/dev/null

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
