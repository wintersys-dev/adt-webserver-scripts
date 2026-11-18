#!/bin/sh
########################################################################################
# @file        CreateRepository.sh
# @brief       Creates a new private remote Git repository via the configured provider.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This driver script resolves the toolkit layout, reads the configured
#              Git provider from software.dat, resolves the target username and
#              repository name, calls the underlying provider API script, and
#              validates the creation status.
#
# @param       $1  [Required] The name/slug of the repository to create.
# @param       $2  [Optional] The repository username/workspace (falls back to config).
#
# @env         HOME                 Path to the framework root directory (read from file).
# @env         REPOSITORY_USERNAME  The default repository username/workspace from config.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - ${HOME}/runtime/software.dat tracking the active GIT_PROVIDER.
#              - external dependencies: awk, cat, echo, jq, tr
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Delegates netrc credential handling entirely to the provider worker script.
#              - Wraps API data extractions safely in localized variables.
#
# @exit        0  Success: Repository was created and its clone URL printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, or API failure.
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
if [ -z "${1}" ]
then
        /bin/echo "Error: Repository name argument is required." >&2
        /bin/echo "Usage: $0 <repository_name> [repository_username]" >&2
        exit 1
fi

repository_name="${1}"

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

git_provider="$(/usr/bin/awk -F':' '/^GIT_PROVIDER:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${git_provider}" ]
then
        /bin/echo "Error: GIT_PROVIDER not found in ${software_file}" >&2
        exit 1
fi

if [ -n "${2}" ]
then
        repository_username="${2}"
else
        set +e
        repository_username="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_USERNAME')"
        set -e
fi

if [ -z "${repository_username}" ]
then
        /bin/echo "Error: REPOSITORY_USERNAME not found in arguments or configuration." >&2
        exit 1
fi

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(${HOME}/services/git/${git_provider}/create_repository.sh "${repository_username}" "${repository_name}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r '.links.clone[] | select(.name == "https").href')"

        if [ -z "${output}" ]
        then
                /bin/echo "failed"
                /bin/echo "Error: Repository created, but could not extract clone URL for ${repository_name}." >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "failed"
        /bin/echo "Network request failed. Check your API token, username, or repository name." >&2
        exit 1
fi

exit 0
