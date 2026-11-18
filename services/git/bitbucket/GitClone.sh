#!/bin/sh
########################################################################################
# @file        CloneRepository.sh
# @brief       Driver script to clone a remote Git repository from the configured provider.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This driver script resolves the toolkit layout, validates repository
#              and destination parameters, determines the active Git provider, invokes
#              the provider-specific clone_repository.sh script, and verifies that the
#              target directory was populated cleanly.
#
# @param       $1  [Required] Branch name or "--branch <name>" flag.
# @param       $2  [Required] Repository provider (e.g., bitbucket) or "default" to read software.dat.
# @param       $3  [Required] Repository username (retained for interface compatibility).
# @param       $4  [Required] Repository owner or workspace name.
# @param       $5  [Required] Repository name/slug.
# @param       $6  [Required] Local destination directory path.
#
# @env         HOME  Path to the framework root directory (read from file).
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/runtime/software.dat tracking the active GIT_PROVIDER (if $2 is default/empty).
#              - external dependencies: awk, cat, echo, tr
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Delegates credential encoding and header injection to the isolated worker script.
#              - Wraps execution statuses safely in localized variables.
#
# @exit        0  Success: Repository cloned cleanly and destination printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, or clone failure.
########################################################################################
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
########################################################################################
#set -x
set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ]
then
        /bin/echo "Error: Missing required arguments." >&2
        /bin/echo "Usage: $0 <branch_command> <repository_provider> <repository_username> <repository_ownername> <repository_name> <destination_directory>" >&2
        exit 1
fi

branch_command="${1}"
repository_provider="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
destination_directory="${6}"

# Resolve provider from software.dat if not explicitly provided
if [ -z "${repository_provider}" ] || [ "${repository_provider}" = "default" ]
then
        software_file="${HOME}/runtime/software.dat"
        if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
        then
                /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
                exit 1
        fi

        repository_provider="$(/usr/bin/awk -F':' '/^GIT_PROVIDER:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

        if [ -z "${repository_provider}" ]
        then
                /bin/echo "Error: GIT_PROVIDER not found in ${software_file}" >&2
                exit 1
        fi
fi

worker_script="${HOME}/services/git/${repository_provider}/clone_repository.sh"

if [ ! -x "${worker_script}" ]
then
        /bin/echo "Error: Provider clone script not found or not executable at ${worker_script}" >&2
        exit 1
fi

# Temporary disable set -e to evaluate git transaction failures manually
set +e
output="$(${worker_script} "${branch_command}" "${repository_ownername}" "${repository_name}" "${destination_directory}")"
clone_status="$?"
set -e

if [ "${clone_status}" -eq 0 ] && [ -d "${destination_directory}/.git" ]
then
        /bin/echo "${output}"
else
        /bin/echo "failed"
        /bin/echo "Git clone failed for ${repository_ownername}/${repository_name}. Check your API token, branch, or repository URL." >&2
        exit 1
fi

exit 0
