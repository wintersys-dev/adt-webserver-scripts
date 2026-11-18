#!/bin/sh
###################################################################################
# @file        clone_repository.sh
# @brief       Performs a shallow Git clone from Bitbucket using secure env headers.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates target repository parameters, injects
#              Basic authentication headers via GIT_CONFIG_COUNT environment variables
#              to prevent process-tree exposure, and executes a shallow git clone.
#
# @param       $1  [Required] Target branch name or "--branch <name>" flag.
# @param       $2  [Required] The Bitbucket workspace or repository owner name.
# @param       $3  [Required] The name/slug of the repository to clone.
# @param       $4  [Required] Local destination directory for the cloned repository.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: base64, cat, echo, git, printf, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Passes Authorization headers via GIT_CONFIG_* env vars instead of CLI args.
#              - Unsets GIT_CONFIG_* variables immediately after execution.
#
# @exit        0  Success: Repository cloned cleanly into destination directory.
# @exit        *  Failure: Missing arguments, layout faults, or non-zero git exit code.
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        /bin/echo "Error: Branch, repository owner, repository name, and destination directory are required." >&2
        /bin/echo "Usage: $0 <branch> <repository_ownername> <repository_name> <destination_directory>" >&2
        exit 1
fi

# Strip optional "--branch " prefix so both "main" and "--branch main" inputs work cleanly
branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (REPOSITORY_TOKEN)." >&2
        exit 1
fi

# Encode credentials safely using x-bitbucket-api-token-auth
encoded_auth="$(/usr/bin/printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"

if [ -z "${encoded_auth}" ]
then
        /bin/echo "Error: Failed to encode Bitbucket authentication header." >&2
        exit 1
fi

# Export transient Git HTTP header configuration to avoid exposing tokens in process trees
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.extraheader"
export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

set +e
/usr/bin/git clone \
    --depth 1 \
    --branch "${branch}" \
    -- "https://bitbucket.org/${repository_ownername}/${repository_name}.git" \
    "${destination_directory}" >&2
git_status="$?"
set -e

# Immediately scrub sensitive environment variables
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 encoded_auth REPOSITORY_TOKEN

if [ "${git_status}" -ne 0 ]
then
        /bin/echo "Error: Git clone failed for ${repository_ownername}/${repository_name} on branch ${branch} (exit code: ${git_status})." >&2
        exit "${git_status}"
fi

/bin/echo "${destination_directory}"
exit 0
