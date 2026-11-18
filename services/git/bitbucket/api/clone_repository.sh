#!/bin/sh
###################################################################################
# @file        create_repository.sh
# @brief       Creates a new private Bitbucket Git repository via API using netrc.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.1
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates the target username and repository
#              name parameters, feeds netrc credentials into curl via an ephemeral
#              file descriptor (/dev/fd/3) to prevent disk writes or process tree
#              exposure, and executes an authenticated curl POST request.
#
# @param       $1  [Required] The Bitbucket workspace or repository username.
# @param       $2  [Required] The name/slug of the repository to create.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, echo, curl, grep, cut, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses --netrc-file /dev/fd/3 to avoid writing secrets to disk or exposing them in ps.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Repository created cleanly (HTTP 200/201).
# @exit        *  Failure: Missing arguments, layout faults, or a non-2xx status 
#                 code thrown back by the remote endpoint or pipeline.
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

repository_username="${1}"
repository_name="${2}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (REPOSITORY_TOKEN)." >&2
        exit 1
fi

# Construct JSON payload
payload='{"scm": "git", "is_private": true, "fork_policy": "no_public_forks"}'

set +e
# Open file descriptor 3 with netrc formatted credentials in memory (no disk write)
exec 3<<EOF
machine api.bitbucket.org
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

# Execute curl using --netrc-file against file descriptor 3
RESPONSE=$(/usr/bin/curl -s -X POST --netrc-file /dev/fd/3 \
    -H "Content-Type: application/json" \
    "https://bitbucket.org{repository_username}/${repository_name}" \
    -d "${payload}" \
    -w "\nHTTP_STATUS:%{http_code}")

# Immediately close file descriptor 3
exec 3<&-
set -e

# Extract the HTTP status code using strict POSIX filtering
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200|201)
        /bin/echo "${RESPONSE_BODY}"
        exit 0
        ;;
    400)
        /bin/echo "Error 400: Bad Request. Repository may already exist or payload syntax is invalid." >&2
        /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
        exit 400
        ;;
    401)
        /bin/echo "Error 401: Unauthorized. Your REPOSITORY_TOKEN is invalid or has expired." >&2
        exit 401
        ;;
    403)
        /bin/echo "Error 403: Forbidden. Token lacks permissions to create repositories in this workspace." >&2
        exit 403
        ;;
    404)
        /bin/echo "Error 404: Not Found. The target workspace or user (${repository_username}) does not exist." >&2
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
