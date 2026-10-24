#!/bin/sh
##################################################################################
# Script Name : GitClone.sh
# Description : Executes a shallow Git clone operation (depth = 1) for a specific 
#               GitHub repository using an authenticated HTTPS URL and custom
#               branch/destination configurations.
#
# Usage       : ./GitCloneExecution.sh "<branch_command>" \
#                                      <repository_provider> \
#                                      <repository_token> \
#                                      <repository_username> \
#                                      <repository_ownername> \
#                                      <repository_name> \
#                                      <destination_directory>
#
# Arguments   : $1 - branch_command         (e.g., "-b main" or empty string)
#               $2 - repository_provider     (Expected to be "github")
#               $3 - repository_token        (Formatted token string, e.g., ":PAT")
#               $4 - repository_username     (GitHub account username)
#               $5 - repository_ownername    (Repository owner or organization name)
#               $6 - repository_name         (Target repository name)
#               $7 - destination_directory   (Local path for the cloned repo)
#
# Dependencies: Requires system access to /usr/bin/git
# Security    : The repository token and username are exposed in the process tree
#               during the execution of the git clone command.
##################################################################################


#!/bin/sh

branch_command="${1}"
repository_provider="${2}"
repository_token="${3}"
repository_username="${4}"
repository_ownername="${5}"
repository_name="${6}"
destination_directory="${7}"

/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${repository_token}@github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}
