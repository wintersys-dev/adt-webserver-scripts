#!/bin/sh
###################################################################################
# @file        create_repository.sh
# @brief       Redirects repository creation requests to the Bitbucket API worker.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     Because Bitbucket Cloud does not support automatic repository
#              provisioning via native Git push operations, this router script
#              validates incoming repository creation requests and delegates execution
#              directly to the API-backed create_repository.sh implementation.
#
# @param       $1  [Required] The Bitbucket workspace or repository username.
# @param       $2  [Required] The name/slug of the repository to create.
#
# @env         HOME  Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/services/git/bitbucket/api/create_repository.sh
#              - external dependencies: cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Quotes all passed arguments ("$@") to prevent word-splitting or injection.
#
# @exit        0  Success: Request delegated and repository created via API.
# @exit        *  Failure: Missing configuration, missing API script, or API error code.
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
####################################################################################
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Repository username and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_username> <repository_name>" >&2
        exit 1
fi

api_script="${HOME}/services/git/bitbucket/api/create_repository.sh"

if [ ! -x "${api_script}" ]
then
        /bin/echo "Error: API repository creation script not found or not executable at ${api_script}" >&2
        exit 1
fi

# Replace current shell process with the API script, preserving all arguments and exit codes
exec "${api_script}" "$@"
