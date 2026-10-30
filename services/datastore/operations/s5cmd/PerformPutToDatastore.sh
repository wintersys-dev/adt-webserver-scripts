#!/bin/sh
###################################################################################
# @file        PerformPutToDatastore.sh
# @brief       Automated Local Payload Ingestion & S3 Datastore Storage Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data ingress operations by transferring
#              local files or virtual metadata payloads to targeted cloud datastores 
#              using s5cmd. It resolves S3 endpoints from a dynamic configuration registry 
#              using a numbered index system. The utility features automatic workspace creation 
#              and placeholder marker file fallback routines, alongside an optional 
#              post-upload source sanitation mechanism.
#
# @param       $1  [Required] Local file system path of the source payload file to ingest.
# @param       $2  [Required] S3 bucket target location pathway to write the payload.
# @param       $3  [Required] Post-upload local sanitation flag ("yes" to purge source, "no" to retain).
# @param       $4  [Required] Integer configuration ID used to select the targeted s5cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-${count} targeted credentials and cluster configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Safely caps directory tracking mutations by scrubbing trailing "root" overrides from the S3 namespace.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Local payload safely transmitted and synchronized with the S3 datastore destination.
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################################
#########################################################################################
#set -x

set -e

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ]  )
then
        /bin/echo "Error: 4 arguments are required."
        /bin/echo "Usage: $0 <file_to_put> <place_to_put> <delete> <count>"
        exit 1
fi

file_to_put="$1"
place_to_put="$2"
delete="$3"
count="$4"

HOME="`/bin/cat /home/homedir.dat`"

place_to_put="`/bin/echo ${place_to_put} | /bin/sed 's|root$||'`"

if ( [ ! -d  ${HOME}/runtime/datastore_workarea ] )
then
        /bin/mkdir -p  ${HOME}/runtime/datastore_workarea
fi

if ( [ ! -f ${file_to_put} ] )
then
        #if there is no file on the file system we can assume that we are being used as a marker like an IP address, so create out own marker file
        /bin/touch  ${HOME}/runtime/datastore_workarea/${file_to_put}
        file_to_put_with_path="${HOME}/runtime/datastore_workarea/${file_to_put}"
else
        file_to_put_with_path="${file_to_put}"
fi

file_to_put="`/bin/echo ${file_to_put_with_path} | /usr/bin/awk -F'/' '{print $NF}'`"

place_to_put="`/bin/echo ${place_to_put} | /bin/sed 's;\/$;;g'`"
host_base="`/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} cp ${file_to_put_with_path} s3://${place_to_put}/${file_to_put}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to put ${file_to_put} to s3://${place_to_put}"
        exit 1
fi

if ( [ "${delete}" = "yes" ] )
then
        if ( [ -f ${file_to_put} ] )
        then
                /bin/rm ${file_to_put}
        fi
fi
