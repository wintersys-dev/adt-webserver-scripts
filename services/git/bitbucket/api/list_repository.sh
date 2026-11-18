#!/bin/sh
###################################################################################
# @file        list_repository.sh
# @brief       Checks a single Bitbucket repository state ("full", "empty", or "none") via API.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.1
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates the target username, owner, and
#              repository parameters, feeds netrc credentials into curl via an
#              ephemeral file descriptor (/dev/fd/3), queries Bitbucket's v2.0
#              repository and commits endpoints, and prints "full" (exists with
#              commits), "empty" (exists with no commits), or "none" (does not exist).
#
# @param       $1  [Required] The Bitbucket authentication username.
# @param       $2  [Required] The Bitbucket workspace or repository owner name.
# @param       $3  [Required] The name/slug of the repository to inspect.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, curl, cut, echo, grep, jq, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses --netrc-file /dev/fd/3 to avoid writing secrets to disk or exposing them in ps.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Repository state ("full", "empty", or "none") printed to stdout.
# @exit        *  Failure: Missing arguments, layout faults, or unexpected API/auth error.
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        /bin/echo "Error: Repository username, owner name, and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_username> <repository_ownername> <repository_name>" >&2
        exit 1
fi

repository_username="${1}"
repository_ownername="${2}"
repository_name="${3}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (REPOSITORY_TOKEN)." >&2
        exit 1
fi

# Step 1: Verify whether the repository exists via Bitbucket v2.0 repository endpoint
set +e
exec 3<<EOF
machine api.bitbucket.org
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

REPO_RESPONSE=$(/usr/bin/curl -s --netrc-file /dev/fd/3 \
    "https://bitbucket.org{repository_ownername}/${repository_name}" \
    -w "\nHTTP_STATUS:%{http_code}")

exec 3<&-
set -e

REPO_HTTP_CODE=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
REPO_BODY=$(/bin/echo "${REPO_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${REPO_HTTP_CODE}" in
    200)
        # Repository exists; proceed to check for commits
        ;;
    404)
        /bin/echo "none"
        exit 0
        ;;
    401)
        /bin/echo "Error 401: Unauthorized. Your authentication REPOSITORY_TOKEN is invalid or has expired." >&2
        exit 401
        ;;
    403)
        /bin/echo "Error 403: Forbidden. Token lacks permissions to inspect ${repository_ownername}/${repository_name}." >&2
        exit 403
        ;;
    429)
        /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
        exit 429
        ;;
    5*)
        /bin/echo "Error ${REPO_HTTP_CODE}: Bitbucket Gateway or Remote Server Exception." >&2
        exit 500
        ;;
    *)
        /bin/echo "Error ${REPO_HTTP_CODE}: Unexpected response querying repository metadata." >&2
        /bin/echo "API Detail: ${REPO_BODY}" >&2
        exit 1
        ;;
esac

# Step 2: Query the commits endpoint (pagelen=1) to distinguish "full" vs "empty"
set +e
exec 3<<EOF
machine api.bitbucket.org
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

COMMITS_RESPONSE=$(/usr/bin/curl -s --netrc-file /dev/fd/3 \
    "https://bitbucket.org{repository_ownername}/${repository_name}/commits?pagelen=1" \
    -w "\nHTTP_STATUS:%{http_code}")

exec 3<&-
set -e

COMMITS_HTTP_CODE=$(/bin/echo "${COMMITS_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
COMMITS_BODY=$(/bin/echo "${COMMITS_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${COMMITS_HTTP_CODE}" in
    200)
        commit_count="$(/bin/echo "${COMMITS_BODY}" | /usr/bin/jq '.values | length' 2>/dev/null)"
        if [ -n "${commit_count}" ] && [ "${commit_count}" -gt 0 ]
        then
                /bin/echo "full"
        else
                /bin/echo "empty"
        fi
        exit 0
        ;;
    404|409)
        # Bitbucket may return 404/409 on /commits when a newly created repo has no HEAD branch yet
        /bin/echo "empty"
        exit 0
        ;;
    *)
        /bin/echo "Error ${COMMITS_HTTP_CODE}: Unexpected response querying repository commits." >&2
        /bin/echo "API Detail: ${COMMITS_BODY}" >&2
        exit 1
        ;;
esac

exit 0



