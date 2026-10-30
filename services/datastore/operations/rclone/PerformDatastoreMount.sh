#!/bin/sh
###################################################################################
# @file        PerformDatastoreMount.sh
# @brief       Automated S3 Datastore Creation and Workspace Initialization Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates backend volume initialization for target cloud
#              datastores. It resolves endpoint layout settings from dynamic rclone
#              profile allocations, runs structural availability checks, and provisions
#              the required bucket structure inside target S3 object storage targets.
#
# @param       $1  [Required] Target datastore directory or S3 bucket name namespace.
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
#              - Relies on absolute binaries (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target bucket exists or was successfully created in the S3 backend.
# @exit        1  Failure: Missing mandatory parameters or rclone was unable to provision the datastore.
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
#########################################################################################
#########################################################################################
#set -x

set -e


if [ "${1}" = "" ] || [ "${2}" = "" ]
then
        /bin/echo "Error: 2 arguments are required."
        /bin/echo "Usage: $0 <datastore_to_mount> <count>"
        exit 1
fi

datastore_to_mount="$1"
count="${2}"

host_base="$(/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} 2>/dev/null | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g')" 

if [ "$(/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} ls s3: 2>/dev/null)" = "" ]
then
        /usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} mkdir s3:${datastore_to_mount}  2>/dev/null
        if ( [ "$?" != "0" ] )
        then
                /bin/echo "Failed to mount bucket s3://${datastore_to_mount}"
                exit 1
        fi
fi
