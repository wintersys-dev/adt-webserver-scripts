#!/bin/sh
###################################################################################
# @file        list_repository.sh
# @brief       Checks a single Bitbucket repository state ("full", "empty", or "none") via API.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This script retrieves the Bitbucket authentication token and Atlassian
#              account email from the toolkit configuration, validates the target
#              owner and repository parameters, builds the Bitbucket v2.0 REST API
#              endpoint URLs, pipes netrc credentials into curl via /dev/stdin to
#              prevent disk writes or process tree exposure, and queries the
#              repository and commits endpoints to determine whether the repository
#              has commits ("full"), exists with no commits ("empty"), or does not
#              exist ("none").
#
# @param       $1  [Required] The Bitbucket workspace or repository owner name.
# @param       $2  [Required] The name/slug of the repository to inspect.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token.
# @env         ATLASSIAN_EMAIL   The Atlassian account email used for API login.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, curl, cut, echo, grep, jq, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses --netrc-file /dev/stdin to avoid writing secrets to disk or exposing them in ps.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Repository state ("full", "empty", or "none") printed to stdout.
# @exit        *  Failure: Missing arguments, layout faults, missing credentials, or auth/API error.
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
#set -x
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
        /bin/echo "Error: Repository owner name and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_ownername> <repository_name>" >&2
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
ATLASSIAN_EMAIL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYEMAIL')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN or APPLICATIONREPOSITORYEMAIL)." >&2
        exit 1
fi

# Build the Bitbucket v2.0 REST API endpoints beforehand
api_base="https://api.bitbucket.org/2.0"
repo_endpoint="${api_base}/repositories/${repository_ownername}/${repository_name}"
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

# Step 1: Check whether the repository exists
set +e
REPO_RESPONSE=$(/bin/echo "machine api.bitbucket.org login ${ATLASSIAN_EMAIL} password ${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s --netrc-file /dev/stdin \
        "${repo_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
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
                /bin/echo "Error 401: Unauthorized. Your REPOSITORY_TOKEN or ATLASSIAN_EMAIL is invalid or has expired." >&2
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
                /bin/echo "Error ${REPO_HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." >&2
                /bin/echo "API Detail: ${REPO_BODY}" >&2
                exit 1
                ;;
esac

# Step 2: Check whether the repository has any commits ("full" vs "empty")
set +e
COMMITS_RESPONSE=$(/bin/echo "machine api.bitbucket.org login ${ATLASSIAN_EMAIL} password ${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s --netrc-file /dev/stdin \
        "${commits_endpoint}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
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
                # Empty repositories with an unborn HEAD can return 404/409 on /commits
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



