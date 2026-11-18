#!/bin/sh
#: Name:        get_repository.sh
#: Purpose:     Checks a specific Bitbucket repository via REST API v2.0 using
#:              transient .netrc authentication and outputs "none", "empty", or "full".
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.1
#:
#: Usage:       get_repository.sh [workspace] [repo_slug]
#:              get_repository.sh [-h|--help]
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
#:   - CreateTransientNetrc.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, rm, curl, jq
#:
#: Output (stdout):
#:   none       Repository does not exist (HTTP 404)
#:   empty      Repository exists but has zero commits
#:   full       Repository exists and contains at least one commit
#:
#: Exit Codes:
#:   0          Repository state determined cleanly and emitted to stdout
#:   *          Missing context variables, auth error, or unexpected API failure
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

# Ensure transient .netrc directory is always removed on exit
netrc_dir=""
cleanup()
{
        [ -n "${netrc_dir}" ] && /bin/rm -rf "${netrc_dir}"
}
trap cleanup EXIT

# Fetch workspace and repository name from runtime context unless overridden via CLI
set +e
workspace="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
set -e

if [ -z "${workspace}" ] || [ -z "${raw_repo}" ]
then
        status "Error: Failed to fetch required context variables (GIT_WORKSPACE, GIT_REPOSITORY)."
        exit 1
fi

repo_slug="$(/bin/echo "${raw_repo}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"

# Generate transient .netrc directory (automatically covers api.bitbucket.org)
set +e
netrc_dir="$("${BUILD_HOME}/helpers/services/CreateTransientNetrc.sh" "bitbucket")"
netrc_exit=$?
set -e

if [ "${netrc_exit}" -ne 0 ] || [ -z "${netrc_dir}" ]
then
        status "Error: Failed to create transient .netrc authentication context."
        exit 1
fi

# Assemble endpoint from split components
api_sub="api"
api_domain="bitbucket.org"
api_path="2.0/repositories"
repo_endpoint="https://${api_sub}.${api_domain}/${api_path}/${workspace}/${repo_slug}"

# Step 1: Check whether the target repository exists
set +e
REPO_CODE=$(/usr/bin/curl --netrc-file "${netrc_dir}/.netrc" -s -o /dev/null -w "%{http_code}" "${repo_endpoint}")
curl_exit=$?
set -e

if [ "${curl_exit}" -ne 0 ]
then
        status "Error: Network or curl failure checking repository ${workspace}/${repo_slug}."
        exit 1
fi

case "${REPO_CODE}" in
        404)
                /bin/echo "none"
                exit 0
                ;;
        200)
                # Repository exists; proceed to check whether it has commits
                ;;
        401)
                status "Error 401: Unauthorized. Your Bitbucket GIT_TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks repository:read permissions for '${workspace}/${repo_slug}'."
                exit 403
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 429
                ;;
        5*)
                status "Error ${REPO_CODE}: Bitbucket Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                status "Error ${REPO_CODE}: Unexpected HTTP status checking repository existence."
                exit 1
                ;;
esac

# Step 2: Repository exists (HTTP 200) — check for at least one commit (pagelen=1)
commits_endpoint="${repo_endpoint}/commits?pagelen=1"

set +e
COMMITS_RESPONSE=$(/usr/bin/curl --netrc-file "${netrc_dir}/.netrc" -s "${commits_endpoint}" -w "\nHTTP_STATUS:%{http_code}")
commits_exit=$?
set -e

if [ "${commits_exit}" -ne 0 ]
then
        status "Error: Network or curl failure checking commits for ${workspace}/${repo_slug}."
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
                status "Error ${COMMITS_CODE}: Unexpected HTTP status checking repository commits."
                exit 1
                ;;
esac


