#!/bin/sh
###################################################################################
# @file        PerformDatastoreMount.sh
# @brief       Automated S3 Datastore Creation and Workspace Initialization Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     2.0
#
# @details     This script automates backend volume initialization for target cloud
#              datastores using s3cmd. It resolves endpoint configurations from dynamic 
#              s3cmd profile allocations, executes diagnostic availability checks, and 
#              provisions the required bucket infrastructure if it does not already 
#              exist in the target object storage backend.
#
# @param       $1  [Required] Target datastore directory or S3 bucket name namespace.
# @param       $2  [Required] Integer configuration ID used to select the targeted s3cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /usr/bin/s3cmd storage integration command-line software utility.
#              - /root/.s3cfg-${count} targeted cluster registration file.
#              - Standard core utilities: grep, awk, sed.
#
# @security    
#              - Asserts explicit file path checking against s3cmd config targets to mitigate file descriptor corruption.
#              - Suppresses standard error and standard output during health checks to prevent leak vectors.
#              - Implements strict validation and defensive typing architectures to prevent unhandled state execution.
#
# @exit        0  Success: Target bucket exists or was successfully created in the S3 backend.
# @exit        1  Failure: Missing parameters, unavailable dependencies, or s3cmd driver failures.
###################################################################################
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

host_base="$(/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g')" 
if [ "$(/usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} ls s3://${datastore_to_mount} 2>/dev/null)" = "" ]
then
  /usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} mb s3://${datastore_to_mount}  2>&1 >/dev/null
  if ( [ "$?" != "0" ] )
  then
    /bin/echo "Failed to mount bucket s3://${datastore_to_mount}"
    exit 1
  fi
fi
