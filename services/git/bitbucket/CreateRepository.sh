#!/bin/sh
#: Name:        CreateRepository.sh
#: Purpose:     Provisions a new private Bitbucket Cloud Git repository via the Bitbucket REST API 2.0.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       CreateRepository.sh "<workspace_id>" "<repository_name>"
#:              CreateRepository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Bitbucket workspace ID or account username namespace
#:   $2         [Required] Target repository name to create
#:
#: Environment:
#:   HOME             Resolved automatically from /home/homedir.dat
#:   REPOSITORY_TOKEN Resolved from ExtractConfigValue.sh ('APPLICATIONREPOSITORYTOKEN') if not exported
#:   ATLASSIAN_EMAIL  Resolved from ExtractConfigValue.sh ('APPLICATIONREPOSITORYEMAIL') if not exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/.netrc (created transiently with mode 600 and removed on exit)
#:   - External binaries: cat, echo, grep, cut, sed, tr, chmod, rm, jq, curl
#:
#: Exit Codes:
#:   0          Private Bitbucket repository created successfully
#:   1          Missing arguments, missing config/credentials, JSON encoding failure, or non-2xx API status
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
        /bin/echo "Error: Both workspace ID and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <workspace_id> <repository_name>" >&2
        exit 1
fi

workspace_id="${1}"
repository_name="${2}"
repo_slug="$(/bin/echo "${repository_name}" | /usr/bin/tr '[:upper:]' '[:lower:]')"

# Extract token and Atlassian login email from toolkit configuration if not already exported
if [ -z "${REPOSITORY_TOKEN}" ]
then
        REPOSITORY_TOKEN="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'APPLICATIONREPOSITORYTOKEN')"
fi

if [ -z "${ATLASSIAN_EMAIL}" ]
then
        ATLASSIAN_EMAIL="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'APPLICATIONREPOSITORYOWNER')"
fi

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        /bin/echo "Error: Both APPLICATIONREPOSITORYTOKEN and APPLICATIONREPOSITORYEMAIL must be configured." >&2
        exit 1
fi

netrc_file="${HOME}/.netrc"
trap '/bin/rm -f "${netrc_file}"' EXIT

(
        umask 077
        /bin/cat << EOF > "${netrc_file}"
machine api.bitbucket.org
login ${ATLASSIAN_EMAIL}
password ${REPOSITORY_TOKEN}
EOF
)
/bin/chmod 600 "${netrc_file}"

# Construct the Bitbucket repository creation JSON payload safely via jq
repo_payload="$(/usr/bin/jq -n -c --arg name "${repository_name}" '{ scm: "git", name: $name, is_private: true, fork_policy: "no_public_forks" }' 2>/dev/null)"

if [ -z "${repo_payload}" ]
then
        /bin/echo "Error: Failed to construct valid repository JSON payload." >&2
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="bitbucket.org"
api_path="2.0/repositories/${workspace_id}/${repo_slug}"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the repository creation POST request using .netrc credentials
set +e
RESPONSE=$(/usr/bin/curl --netrc -s -X POST "${endpoint}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${repo_payload}" -w "\nHTTP_STATUS:%{http_code}")
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
                /bin/echo "Success! Private Bitbucket repository '${workspace_id}/${repo_slug}' created."
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Repository '${repo_slug}' may already exist or payload is invalid." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Check APPLICATIONREPOSITORYEMAIL and APPLICATIONREPOSITORYTOKEN." >&2
                exit 1
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Missing repository or project creation permissions." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
        404)
                /bin/echo "Error 404: Not Found. Workspace '${workspace_id}' does not exist." >&2
                exit 1
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded." >&2
                exit 1
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Bitbucket Server Error." >&2
                exit 1
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Unexpected response." >&2
                /bin/echo "API Response: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0
