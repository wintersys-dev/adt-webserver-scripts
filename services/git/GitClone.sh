#!/bin/sh
# ==============================================================================
# Script Name    : GitClone.sh
# Description    : A wrapper script that validates arguments, configures 
#                  authentication tokens and branch parameters, and invokes an
#                  underlying GitClone.sh service to clone a repository.
# Author         : Peter Winter
# Date Created   : 2021-10-24
# ==============================================================================
# Usage          : ./GitCloneWrapper.sh <repository_provider> \
#                                       <repository_username> \
#                                       <repository_ownername> \
#                                       <repository_name> \
#                                       <repository_token> \
#                                       [repository_branch] \
#                                       [destination_directory]
#
# Arguments      : $1 - repository_provider    (e.g., github, gitlab) [Required]
#                  $2 - repository_username    (Git service username) [Required]
#                  $3 - repository_ownername   (Repo owner/org name)  [Required]
#                  $4 - repository_name        (Name of the repository)[Required]
#                  $5 - repository_token       (Personal Access Token) [Required]
#                  $6 - repository_branch      (Target branch to clone)[Optional]
#                  $7 - destination_directory  (Local target path)    [Optional]
#
# Environment    : Depends on '/home/homedir.dat' existing and containing a 
#                  valid absolute path used to locate the git service scripts.
#
# Exit Codes     : 0 - Success
#                  1 - Invalid arguments or missing required parameters
# ==============================================================================
#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ] )
then
        status "Error: 5 arguments are required with 2 optional arguments"
        status "Usage: $0 <repository_provider> <repository_username> <repository_ownername> <repository_name> <repository_token> <repository_branch> <destination_directory>"
        exit 1
fi


repository_provider="${1}"
repository_username="${2}"
repository_ownername="${3}"
repository_name="${4}"
repository_token="${5}"
repository_branch="${6}"
destination_directory="${7}"

authentication_token=""

if ( [ "${repository_token}" != "" ] )
then
        authentication_token=":${repository_token}"
fi

branch_command=""

if ( [ "${repository_branch}" != "" ] )
then
        branch_command=" -b ${repository_branch} "
else 
        branch_command=" -b main "
fi

${HOME}/services/git/${repository_provider}/GitClone.sh "${branch_command}" "${repository_provider}" "${authentication_token}" "${repository_username}" "${repository_ownername}" "${repository_name}" "${destination_directory}"


