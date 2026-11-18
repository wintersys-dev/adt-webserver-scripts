#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes a local directory to Bitbucket via REST API (/src) using netrc stdin.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       push_to_repository.sh <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>
#:
#: Parameters:
#:   $1         [Required] Local source directory containing content to push.
#:   $2         [Required] Target branch name or "--branch <name>" flag.
#:   $3         [Required] The Bitbucket authentication username.
#:   $4         [Required] The Bitbucket workspace or repository owner name.
#:   $5         [Required] The name/slug of the existing target repository.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, curl, cut, echo, find, grep, sed
#:
#: Exit Codes:
#:   0          Directory files committed and pushed cleanly via API (HTTP 200/201)
#:   1          Missing arguments, invalid or empty directory, layout faults, missing credentials, or unexpected HTTP code
#:   400        Bad Request (invalid branch name, file paths, or payload formatting)
#:   401        Unauthorized (invalid or expired APPLICATIONREPOSITORYTOKEN or email)
#:   403        Forbidden (token lacks repository write permissions)
#:   404        Not Found (target repository does not exist)
#:   429        Rate Limit Exceeded
#:   500        Bitbucket Gateway or Remote Server Exception (5xx)
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


set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: Source directory, branch, username, owner name, and repository name are required." >&2
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
ATLASSIAN_EMAIL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYEMAIL')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN or APPLICATIONREPOSITORYEMAIL)." >&2
        exit 1
fi

cd "${source_directory}"

file_args="$(/usr/bin/find . -path './.git' -prune -o -type f -printf '-F %P=@%p ')"

if [ -z "${file_args}" ]
then
        /bin/echo "Error: No files found to push in ${source_directory}." >&2
        exit 1
fi

set +e
RESPONSE=$(
        /bin/echo "machine api.bitbucket.org login ${ATLASSIAN_EMAIL} password ${REPOSITORY_TOKEN}" |
                /usr/bin/curl -sS \
                -X POST \
                --netrc-file /dev/stdin \
                -F "branch=${branch}" \
                -F "message=Automated deployment push" \
                ${file_args} \
                "https://api.bitbucket.org/2.0/repositories/${repository_ownername}/${repository_name}/src" \
                -w "\nHTTP_STATUS:%{http_code}"
        )
        set -e

# Extract the HTTP status code using strict POSIX filtering
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "https://api.bitbucket.org/2.0/repositories/${repository_ownername}/${repository_name}" 
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check branch name, file paths, or payload formatting." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 400
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your authentication REPOSITORY_TOKEN is invalid or has expired." >&2
                exit 401
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Token lacks repository write permissions." >&2
                exit 403
                ;;
        404)
                /bin/echo "Error 404: Not Found. Target repository (${repository_ownername}/${repository_name}) does not exist." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 404
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 429
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Bitbucket Gateway or Remote Server Exception." >&2
                exit 500
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0
