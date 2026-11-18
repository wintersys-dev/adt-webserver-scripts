#!/bin/sh
########################################################################################
# @file        ListRepository.sh
# @brief       Checks whether a single remote repository is "full", "empty", or "none".
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This driver script resolves the toolkit layout, reads the configured
#              Git provider from software.dat, invokes the underlying list_repository.sh
#              worker script, and returns "full" (exists with commits), "empty" (exists
#              with no commits), or "none" (does not exist) to stdout.
#
# @param       $1  [Required] The repository workspace or owner name.
# @param       $2  [Required] The name/slug of the repository to inspect.
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
# @exit        0  Success: Repository state ("full", "empty", or "none") printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, or worker execution error.
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
if [ -z "${1}" ] || [ -z "${2}" ] 
then
        /bin/echo "Error: Repository owner name, and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_ownername> <repository_name>" >&2
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"

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

worker_script="${HOME}/services/git/bitbucket/${orchestration_tool}/list_repository.sh"

if [ ! -x "${worker_script}" ]
then
        /bin/echo "Error: Provider repository check script not found or not executable at ${worker_script}" >&2
        exit 1
fi

# Temporary disable set -e to evaluate worker execution failures manually
set +e
output="$(${worker_script} "${repository_ownername}" "${repository_name}")"
worker_status="$?"
set -e

if [ "${worker_status}" -eq 0 ] && [ -n "${output}" ]
then
        case "${output}" in
                full|empty|none)
                        /bin/echo "${output}"
                        exit 0
                        ;;
                *)
                        /bin/echo "none"
                        /bin/echo "Error: Unexpected repository state returned: ${output}" >&2
                        exit 1
                        ;;
        esac
else
        /bin/echo "none"
        /bin/echo "Repository check failed for ${repository_ownername}/${repository_name}. Check your API token or configuration." >&2
        exit 1
fi

exit 0

