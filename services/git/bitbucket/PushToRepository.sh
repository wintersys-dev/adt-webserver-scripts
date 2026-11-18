#!/bin/sh
########################################################################################
# @file        PushRepository.sh
# @brief       Driver script to push a local directory to an existing Git repository.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This driver script resolves the toolkit layout, validates directory and
#              repository parameters, determines the active Git provider from
#              software.dat, invokes the provider-specific push_repository.sh worker
#              script, and verifies the push status.
#
# @param       $1  [Required] Local source directory path containing content to push.
# @param       $2  [Required] Target branch name or "--branch <name>" flag.
# @param       $3  [Required] Repository authentication username.
# @param       $4  [Required] Repository workspace or owner name.
# @param       $5  [Required] Name/slug of the existing target repository.
# @param       $6  [Optional] Repository provider override (defaults to software.dat).
#
# @env         HOME  Path to the framework root directory (read from file).
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/runtime/software.dat tracking the active GIT_PROVIDER.
#              - external dependencies: awk, cat, echo, tr
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Delegates netrc credential handling entirely to the isolated worker script.
#              - Wraps execution statuses safely in localized variables.
#
# @exit        0  Success: Directory pushed cleanly and remote URL printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, or push failure.
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
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: Missing required arguments." >&2
        /bin/echo "Usage: $0 <source_directory> <branch> <repository_username> <repository_ownername> <repository_name> [repository_provider]" >&2
        exit 1
fi

source_directory="${1}"
branch="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
repository_provider="${6}"

if [ ! -d "${source_directory}" ]
then
        /bin/echo "failed"
        /bin/echo "Error: Source directory not found at ${source_directory}." >&2
        exit 1
fi

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

repository_provider="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYPROVIDER')"
if [ -z "${repository_provider}" ]
then
        /bin/echo "Error: GIT provider  not found in ${software_file}" >&2
        exit 1
fi

worker_script="${HOME}/services/git/${repository_provider}/${orchestration_tool}/push_to_repository.sh"

if [ ! -x "${worker_script}" ]
then
        /bin/echo "Error: Provider push script not found or not executable at ${worker_script}" >&2
        exit 1
fi

# Temporary disable set -e to evaluate git transaction failures manually
set +e
output="$(${worker_script} "${source_directory}" "${branch}" "${repository_username}" "${repository_ownername}" "${repository_name}")"
push_status="$?"
set -e

if [ "${push_status}" -eq 0 ] && [ -n "${output}" ]
then
        /bin/echo "${output}"
else
        /bin/echo "failed"
        /bin/echo "Git push failed for ${repository_ownername}/${repository_name}. Check your API token, branch, or repository permissions." >&2
        exit 1
fi

exit 0
