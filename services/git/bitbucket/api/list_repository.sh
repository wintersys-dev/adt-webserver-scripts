#!/bin/sh
#: Name:        check_repository.sh
#: Purpose:     Checks whether a Bitbucket repository exists and classifies its
#:              content state as "none", "empty", or "full" via REST API v2.0.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       check_repository.sh [workspace] [repo_slug]
#:              check_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Override for GIT_WORKSPACE from runtime context.
#:   $2         [Optional] Override for GIT_REPOSITORY from runtime context.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, curl, jq
#:
#: Output (stdout):
#:   none       Repository does not exist (HTTP 404)
#:   empty      Repository exists but has zero commits/content
#:   full       Repository exists and contains at least one commit
#:
#: Exit Codes:
#:   0          Repository state successfully determined and emitted to stdout
#:   *          Missing context variables, auth error, or unexpected API response
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

# Exit immediately if any command exits with a non-zero status
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries strictly to stderr so stdout emits only none|empty|full
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Fetch required values from the active deployment context (allowing optional CLI overrides)
set +e
workspace="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_TOKEN)"
set -e

if [ -z "${workspace}" ] || [ -z "${raw_repo}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (GIT_WORKSPACE, GIT_REPOSITORY, GIT_TOKEN)."
        exit 1
fi

repo_slug="$(/bin/echo "${raw_repo}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="bitbucket.org"
api_path="2.0/repositories"
repo_endpoint="https://${api_sub}.${api_domain}/${api_path}/${workspace}/${repo_slug}"

# Step 1: Check whether the repository exists
set +e
REPO_CODE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -o /dev/null -w "%{http_code}" "${repo_endpoint}")
curl_exit=$?
set -e

if [ "${curl_exit}" -ne 0 ]
then
        status "Error: Network or curl failure checking Bitbucket repository ${workspace}/${repo_slug}."
        exit 1
fi

case "${REPO_CODE}" in
        404)
                /bin/echo "none"
                exit 0
                ;;
        200)
                # Repository exists; proceed to check for commits/content
                ;;
        401|403)
                status "Error ${REPO_CODE}: Unauthorized or forbidden checking ${workspace}/${repo_slug}."
                exit "${REPO_CODE}"
                ;;
        429)
                status "Error 429: Bitbucket API rate limit exceeded."
                exit 429
                ;;
        *)
                status "Error ${REPO_CODE}: Unexpected HTTP status checking repository existence."
                exit 1
                ;;
esac

# Step 2: Repository exists (HTTP 200) — check whether any commits exist (pagelen=1)
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

set +e
COMMITS_RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "${commits_endpoint}" -w "\nHTTP_STATUS:%{http_code}")
commits_exit=$?
set -e

if [ "${commits_exit}" -ne 0 ]
then
        status "Error: Network failure checking commit history for ${workspace}/${repo_slug}."
        exit 1
fi

COMMITS_CODE=$(/bin/echo "${COMMITS_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
COMMITS_BODY=$(/bin/echo "${COMMITS_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${COMMITS_CODE}" in
        200)
                commit_count=$(/bin/echo "${COMMITS_BODY}" | /usr/bin/jq -r '.values | length // 0' 2>/dev/null)
                if [ "${commit_count}" -gt 0 ]
                then
                        /bin/echo "full"
                else
                        /bin/echo "empty"
                fi
                exit 0
                ;;
        404)
                # Uninitialised repositories occasionally return 404 on /commits
                /bin/echo "empty"
                exit 0
                ;;
        *)
                status "Error ${COMMITS_CODE}: Unexpected HTTP status checking repository content."
                exit 1
                ;;
esac
