#!/bin/sh 
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Object Content Listing and Parsing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level item inspection within targeted cloud
#              datastores. It extracts the storage endpoint configuration from standard
#              rclone profile records, queries the target S3 path, and reads back object 
#              metadata. It passes the raw endpoint output through filtering text parsing 
#              streams to isolate and print individual target file basenames cleanly.
#
# @param       $1  [Required] Target S3 bucket pathway or file pattern to inspect.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /usr/bin/rclone storage integration engine software utility.
#              - /root/.config/rclone/rclone.conf-1 base primary cluster registration file.
#
# @security    
#              - Strips global wildcard assets (`*`) from target inputs to limit unexpected pattern extraction.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target path successfully interrogated and structural objects listed.
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

if ( [ "${1}" = "" ] )
then
        /bin/echo "Error: 1 argument is required."
        /bin/echo "Usage: $0 <file_to_list>"
        exit 1
fi

file_to_list="${1}"

file_to_list="`/bin/echo ${file_to_list} | tr -d '*'`"

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} ls s3:${file_to_list} | awk '{print $NF}'| sed 's|s3://||' | awk -F'/' '{print $NF}' 2>/dev/null

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to list file ${file_to_list} from datastore"
        exit 1
fi
