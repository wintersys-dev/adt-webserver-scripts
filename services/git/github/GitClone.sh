#!/bin/sh
##################################################################################
# Script Name : GitClone.sh
# Description : Executes a shallow Git clone operation (depth = 1) for a specific 
#               GitHub repository using an authenticated HTTPS URL and custom
#               branch/destination configurations.
#
# Usage       : ./GitCloneExecution.sh "<branch_command>" \
#                                      <repository_provider> \
#                                      <repository_username> \
#                                      <repository_ownername> \
#                                      <repository_name> \
#                                      <destination_directory>
#
# Arguments   : $1 - branch_command         (e.g., "-b main" or empty string)
#               $2 - repository_provider     (Expected to be "github")
#               $3 - repository_username     (GitHub account username)
#               $4 - repository_ownername    (Repository owner or organization name)
#               $5 - repository_name         (Target repository name)
#               $6 - destination_directory   (Local path for the cloned repo)
#
# Dependencies: Requires system access to /usr/bin/git
##################################################################################
#set -x 
set -e

branch_command="${1}"
repository_provider="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
destination_directory="${6}"

/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${repository_token}@github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}
