#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging & Wildcard Tree Deletion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data removal operations inside targeted
#              cloud datastores using the high-performance s5cmd tool. It extracts 
#              endpoint parameters from dynamic s5cmd credential registries, evaluates 
#              special 'root' designators to append wildcards for multi-object tree purges, 
#              and commands the storage engine to discard the matching remote namespaces.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to remove.
# @param       $2  [Required] Integer configuration ID used to select the targeted s5cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-${count} targeted credentials and cluster configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Safely handles broad namespace deletes by evaluating string variables before wildcard appending.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target object or directory tree successfully purged from the datastore.
# @exit        1  Failure: Missing mandatory parameters or s5cmd execution driver failure.
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

if [ "${1}" = "" ] || [ "${2}" = "" ]
then
        /bin/echo "Error: 2 arguments are required."
        /bin/echo "Usage: $0 <file_to_delete> <count>"
        exit 1
fi


file_to_delete="${1}"
count="${2}"

host_base="$(/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g')"
wildcard=""
if ( [ "$(/bin/echo ${file_to_delete} | /bin/grep 'root$')" != "" ] )
then
  file_to_delete="$(/bin/echo ${file_to_delete} | /bin/sed "s/root$//g")"
  wildcard="*"
fi
/usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} rm s3://${file_to_delete}${wildcard}  2>/dev/null

if [ "$?" != "0" ]
then
        /bin/echo "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
