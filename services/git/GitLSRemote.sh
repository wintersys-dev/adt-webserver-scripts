#!/bin/sh
##################################################################################
# Script Name : GitLSRemote.sh
# Author      : Peter Winter
# Date        : 13/06/2016
# Description : This script serves as a wrapper to query a remote Git repository's
#               references (refs/heads, tags, etc.) by setting up authentication
#               and forwarding arguments to an underlying GitLSRemote.sh service.
#
# Usage       : ./GitLSRemoteWrapper.sh <repository_provider> 
#                                        <repository_username> 
#                                        <repository_ownername> 
#                                        <repository_name> 
#                                        [repository_token]
#
# Arguments   : $1 - repository_provider  (e.g., github, gitlab)  [Required]
#               $2 - repository_username  (Git service username)  [Required]
#               $3 - repository_ownername (Repo owner or org name) [Required]
#               $4 - repository_name      (Name of the repository) [Required]
#               $5 - repository_token     (Personal Access Token)  [Optional]
#
# Requirements: Requires a valid home path defined inside '/home/homedir.dat'
#               to locate the internal Git service scripts.
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

repository_provider="${1}"
repository_username="${2}"
repository_ownername="${3}"
repository_name="${4}"
repository_token="${5}"

authentication_token=""

if ( [ "${repository_token}" != "" ] )
then
        authentication_token=":${repository_token}"
fi

${HOME}/services/git/${repository_provider}/GitLSRemote.sh "${repository_username}" "${repository_ownername}" "${repository_name}" "${authentication_token}" 


