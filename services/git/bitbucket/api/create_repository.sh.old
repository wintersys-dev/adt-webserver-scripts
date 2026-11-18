#!/bin/sh
#: Name:        create_repository.sh
#: Purpose:     Creates a new Git repository within a Bitbucket workspace via REST API v2.0
#:              using transient .netrc authentication.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.1
#:
#: Usage:       create_repository.sh <workspace> <repo_slug> <json_payload>
#:              create_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Bitbucket workspace slug (e.g. "wintersys").
#:   $2         [Required] Lowercase repository slug (e.g. "my-website-repo").
#:   $3         [Required] The JSON payload defining the repository attributes.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - CreateTransientNetrc.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, rm, curl, jq
#:
#: Exit Codes:
#:   0          Bitbucket repository created cleanly
#:   *          Missing arguments, layout faults, or non-2xx HTTP status code
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

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
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

# Validate that all required positional arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: Workspace, repository slug, and JSON payload arguments are required."
        status "Usage: $0 <workspace> <repo_slug> <json_payload>"
        exit 1
fi

workspace="${1}"
# Ensure repository slug conforms to Bitbucket's lowercase alphanumeric/hyphen rules
repo_slug="$(/bin/echo "${2}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"
json_payload="${3}"

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="bitbucket.org"
api_path="2.0/repositories"
api_host="${api_sub}.${api_domain}"

endpoint="https://${api_host}/${api_path}/${workspace}/${repo_slug}"

# Generate transient .netrc directory scoped to api.bitbucket.org
set +e
netrc_dir="$("${BUILD_HOME}/services/git/CreateTransientNetRC.sh")"
netrc_exit=$?
set -e

if [ "${netrc_exit}" -ne 0 ] || [ -z "${netrc_dir}" ]
then
        status "Error: Failed to create transient .netrc authentication context."
        exit 1
fi

# Submit the repository creation POST request using transient .netrc authentication
set +e
RESPONSE=$(/usr/bin/curl --netrc-file "${netrc_dir}/.netrc" -s -X POST -H "Content-Type: application/json" -d "${json_payload}" "${endpoint}" -w "\nHTTP_STATUS:%{http_code}")
curl_exit=$?
set -e

if [ "${curl_exit}" -ne 0 ]
then
        status "Error: Network or curl failure submitting repository creation request to ${endpoint}."
        exit 1
fi

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and emit response JSON on success
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "${RESPONSE_BODY}" | /usr/bin/jq '.'
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Repository may already exist or JSON payload/slug is invalid."
                status "API Detail: ${RESPONSE_BODY}"
                exit 400
                ;;
        401)
                status "Error 401: Unauthorized. Your Bitbucket GIT_TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks repository:write permissions in workspace '${workspace}'."
                exit 403
                ;;
        404)
                status "Error 404: Not Found. Target Bitbucket workspace '${workspace}' does not exist."
                exit 404
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 429
                ;;
        5*)
                status "Error ${HTTP_CODE}: Bitbucket Gateway or Remote Server Exception."
                exit 500
                ;;
        *)
                status "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
esac

exit 0

