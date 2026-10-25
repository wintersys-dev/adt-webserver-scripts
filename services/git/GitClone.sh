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
#                                       [repository_branch] \
#                                       [destination_directory]
#
# Arguments      : $1 - repository_provider    (e.g., github, gitlab) [Required]
#                  $2 - repository_username    (Git service username) [Required]
#                  $3 - repository_ownername   (Repo owner/org name)  [Required]
#                  $4 - repository_name        (Name of the repository)[Required]
#                  $5 - repository_branch      (Target branch to clone)[Optional]
#                  $6 - destination_directory  (Local target path)    [Optional]
#
# Environment    : Depends on '/home/homedir.dat' existing and containing a 
#                  valid absolute path used to locate the git service scripts.
#
# Exit Codes     : 0 - Success
#                  1 - Invalid arguments or missing required parameters
##################################################################################
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
#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ]  )
then
        status "Error: 5 arguments are required with 1 optional argument"
        status "Usage: $0 <repository_provider> <repository_ownername> <repository_name> <repository_branch> <destination_directory> [repository_username]"
        exit 1
fi

repository_provider="${1}"
repository_ownername="${2}"
repository_name="${3}"
repository_branch="${4}"
destination_directory="${5}"
repository_username="${6}"

if ( [ "${repository_branch}" != "" ] )
then
        branch_command=" -b ${repository_branch} "
fi

${HOME}/services/git/${repository_provider}/GitClone.sh "${repository_ownername}" "${repository_name}" "${branch_command}" "${destination_directory}" "${repository_username}"
