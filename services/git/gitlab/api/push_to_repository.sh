#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes a local directory to GitLab via REST API v4 (Commits API).
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       push_to_repository.sh <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>
#:              push_to_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Local source directory containing content to push.
#:   $2         [Required] Target branch name or "--branch <name>" flag.
#:   $3         [Required] The GitLab authentication username.
#:   $4         [Required] The GitLab username or group path (repository owner).
#:   $5         [Required] The name/slug of the existing target GitLab project.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: base64, cat, curl, cut, echo, find, grep, jq, sed, tail
#:
#: Exit Codes:
#:   0          Directory files committed and pushed cleanly via GitLab API (HTTP 201)
#:   1          Missing arguments, invalid or empty directory, layout faults, missing credentials, or API error
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
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

#set -x
set -e

if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: Source directory, branch, username, owner name, and project name are required." >&2
        /bin/echo "Usage: $0 <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>" >&2
        exit 1
fi

source_directory="${1}"
branch="$(/bin/echo "${2}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"

if [ ! -d "${source_directory}" ]
then
        /bin/echo "Error: Source directory does not exist at ${source_directory}." >&2
        exit 1
fi

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN)." >&2
        exit 1
fi

cd "${source_directory}"

if [ -z "$(/usr/bin/find . -path './.git' -prune -o -type f -print)" ]
then
        /bin/echo "Error: No files found to push in ${source_directory}." >&2
        exit 1
fi

encoded_project="$(/bin/echo "${repository_ownername}/${repository_name}" | /usr/bin/sed 's/\//%2F/g')"
commits_endpoint="https://gitlab.com{encoded_project}/repository/commits"

# Build the batch commit actions array in a single stream (supports text and binary files via base64)
actions_json="$(
        /usr/bin/find . -path './.git' -prune -o -type f -print | while IFS= read -r rel_path
        do
                clean_path="${rel_path#./}"
                exec_flag="false"
                [ -x "${clean_path}" ] && exec_flag="true"
                b64_data="$(/usr/bin/base64 -w0 "${clean_path}")"

                /usr/bin/jq -n \
                        --arg path "${clean_path}" \
                        --arg content "${b64_data}" \
                        --argjson exec "${exec_flag}" \
                        '{"action":"create","file_path":$path,"content":$content,"encoding":"base64","execute_filemode":$exec}'
        done | /usr/bin/jq -s '.'
)"

payload="$(/usr/bin/jq -n \
        --arg branch "${branch}" \
        --arg msg "Automated deployment push" \
        --arg name "${repository_username}" \
        --arg email "${repository_username}@://gitlab.com" \
        --argjson actions "${actions_json}" \
        '{"branch":$branch,"commit_message":$msg,"author_name":$name,"author_email":$email,"force":true,"actions":$actions}')"

set +e
RESPONSE=$(/bin/echo "PRIVATE-TOKEN: ${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s -X POST -H @- \
        -H "Content-Type: application/json" \
        "${commits_endpoint}" \
        -d "${payload}" \
        -w "\n%{http_code}")
set -e

HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/tail -n1)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '$d')"

if [ "${HTTP_CODE}" != "201" ]
then
        /bin/echo "Error ${HTTP_CODE}: GitLab API commit push failed for ${repository_ownername}/${repository_name}." >&2
        /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
        exit 1
fi

/bin/echo "https://gitlab.com{repository_ownername}/${repository_name}.git"
exit 0
