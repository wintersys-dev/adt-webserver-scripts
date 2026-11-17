#!/bin/sh
#: Name:        CreateRepository.sh
#: Purpose:     Provisions a new private GitLab repository/project via the GitLab REST API v4.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       CreateRepository.sh "<repository_namespace>" "<repository_name>"
#:              CreateRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] GitLab username, group, or subgroup namespace path
#:   $2         [Required] Target GitLab project/repository name to create
#:
#: Environment:
#:   HOME             Resolved automatically from /home/homedir.dat
#:   REPOSITORY_TOKEN Resolved from ExtractConfigValue.sh ('APPLICATIONREPOSITORYTOKEN') if not exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, jq, curl
#:
#: Exit Codes:
#:   0          Private GitLab repository created successfully
#:   1          Missing arguments, missing config/token, namespace lookup failure, or non-2xx API status
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

# Resolve and export the toolkit root directory from the server tracking file
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
        export HOME
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Validate required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Both repository namespace and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_namespace> <repository_name>" >&2
        exit 1
fi

repository_namespace="${1}"
repository_name="${2}"
repo_slug="$(/bin/echo "${repository_name}" | /usr/bin/tr '[:upper:]' '[:lower:]')"

# Extract GitLab access token from toolkit configuration if not already exported
if [ -z "${REPOSITORY_TOKEN}" ]
then
        REPOSITORY_TOKEN="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'APPLICATIONREPOSITORYTOKEN')"
fi

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: APPLICATIONREPOSITORYTOKEN must be configured or exported." >&2
        exit 1
fi

# Assemble base API endpoint from split components
api_sub="gitlab"
api_domain="com"
api_base="https://${api_sub}.${api_domain}/api/v4"

# Resolve numeric namespace_id so group and subgroup targets are honoured
encoded_ns="$(/bin/echo "${repository_namespace}" | /usr/bin/sed 's/\//%2F/g')"
set +e
NS_RESPONSE=$(/bin/echo "Authorization: Bearer ${REPOSITORY_TOKEN}" | /usr/bin/curl -H @- -s -X GET "${api_base}/namespaces/${encoded_ns}" -H "Accept: application/json" -w "\nHTTP_STATUS:%{http_code}")
ns_curl_status="$?"
set -e

if [ "${ns_curl_status}" -ne 0 ]
then
        /bin/echo "Error: curl namespace lookup failed with exit code ${ns_curl_status}." >&2
        exit 1
fi

NS_HTTP_CODE=$(/bin/echo "${NS_RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
NS_BODY=$(/bin/echo "${NS_RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

if [ "${NS_HTTP_CODE}" != "200" ]
then
        /bin/echo "Error ${NS_HTTP_CODE}: Could not resolve GitLab namespace '${repository_namespace}'." >&2
        /bin/echo "API Response: ${NS_BODY}" >&2
        exit 1
fi

namespace_id="$(/bin/echo "${NS_BODY}" | /usr/bin/jq -r '.id // empty' 2>/dev/null)"

if [ -z "${namespace_id}" ]
then
        /bin/echo "Error: Failed to extract numeric ID for namespace '${repository_namespace}'." >&2
        exit 1
fi

# Construct the GitLab project creation JSON payload safely via jq
repo_payload="$(/usr/bin/jq -n -c \
        --arg name "${repository_name}" \
        --arg path "${repo_slug}" \
        --argjson ns_id "${namespace_id}" \
        '{ name: $name, path: $path, namespace_id: $ns_id, visibility: "private", initialize_with_readme: false }' 2>/dev/null)"

if [ -z "${repo_payload}" ]
then
        /bin/echo "Error: Failed to construct valid repository JSON payload." >&2
        exit 1
fi

endpoint="${api_base}/projects"

# Submit the project creation POST request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${REPOSITORY_TOKEN}" | /usr/bin/curl -H @- -s -X POST "${endpoint}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${repo_payload}" -w "\nHTTP_STATUS:%{http_code}")
curl_status="$?"
set -e

if [ "${curl_status}" -ne 0 ]
then
        /bin/echo "Error: curl request to ${endpoint} failed with exit code ${curl_status}." >&2
        exit 1
fi

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and handle API errors explicitly
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "Success! Private GitLab repository '${repository_namespace}/${repo_slug}' created."
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Repository '${repo_slug}' may already exist or payload is invalid." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Check APPLICATIONREPOSITORYTOKEN." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Missing project creation permissions in '${repository_namespace}'." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Namespace '${repository_namespace}' does not exist." >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: GitLab Server Error." >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Unexpected response." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0
