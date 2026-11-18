#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes the contents of a local directory to a Bitbucket
#:              repository branch in a single atomic commit via REST API v2.0 (/src),
#:              using transient .netrc authentication and size/file thresholds.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.2
#:
#: Usage:       push_to_repository.sh [source_dir] [branch] [commit_message] [workspace] [repo_slug]
#:              push_to_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Override for GIT_SOURCE_DIR from runtime context.
#:   $2         [Optional] Override for GIT_BRANCH from runtime context (defaults to "main").
#:   $3         [Optional] Commit message (defaults to "Initial deployment commit").
#:   $4         [Optional] Override for GIT_WORKSPACE from runtime context.
#:   $5         [Optional] Override for GIT_REPOSITORY from runtime context.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - CreateTransientNetRC.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, find, du, awk, mktemp, rm, curl
#:
#: Exit Codes:
#:   0          Directory contents committed and pushed cleanly
#:   1          Missing arguments/context, empty directory, or HTTP error
#:   2          Directory exceeds API upload size or file-count threshold (use git CLI fallback)
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

# Route status log entries strictly to stderr
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Unified cleanup handler so both temp curl config and .netrc directory are always removed
netrc_dir=""
curl_cfg=""
cleanup()
{
        [ -n "${curl_cfg}" ] && /bin/rm -f "${curl_cfg}"
        [ -n "${netrc_dir}" ] && /bin/rm -rf "${netrc_dir}"
}
trap cleanup EXIT

# API upload safety thresholds (50 MB max total payload, 250 files max)
MAX_BYTES=52428800
MAX_FILES=250

# Fetch required values from the active deployment context (allowing optional CLI overrides)
set +e
source_dir="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_SOURCE_DIR)}"
branch="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_BRANCH)}"
commit_msg="${3:-Initial deployment commit}"
workspace="${4:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${5:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
set -e

branch="${branch:-main}"

if [ -z "${source_dir}" ] || [ -z "${workspace}" ] || [ -z "${raw_repo}" ]
then
        status "Error: Failed to fetch required context variables (GIT_WORKSPACE, GIT_REPOSITORY, GIT_SOURCE_DIR)."
        exit 1
fi

if [ ! -d "${source_dir}" ]
then
        status "Error: Source directory does not exist at ${source_dir}."
        exit 1
fi

# Measure total directory byte size (excluding .git) before building curl payload
total_bytes="$(/usr/bin/du -sb --exclude='.git' "${source_dir%/}" 2>/dev/null | /usr/bin/awk '{print $1}')"
total_bytes="${total_bytes:-0}"

if [ "${total_bytes}" -gt "${MAX_BYTES}" ]
then
        status "Threshold exceeded: ${source_dir} is ${total_bytes} bytes (max ${MAX_BYTES} bytes). Use git CLI fallback."
        exit 2
fi

# Generate transient .netrc directory from active runtime context (no arguments needed)
set +e
netrc_dir="$("${BUILD_HOME}/services/git/CreateTransientNetRC.sh")"
netrc_exit=$?
set -e

if [ "${netrc_exit}" -ne 0 ] || [ -z "${netrc_dir}" ]
then
        status "Error: Failed to create transient .netrc authentication context."
        exit 1
fi

repo_slug="$(/bin/echo "${raw_repo}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"

# Assemble endpoint from split components
api_sub="api"
api_domain="bitbucket.org"
api_path="2.0/repositories"
endpoint="https://${api_sub}.${api_domain}/${api_path}/${workspace}/${repo_slug}/src"

# Build a temporary curl config file (-K) without writing any credentials into it
curl_cfg="$(/usr/bin/mktemp /tmp/adt-bb-push.XXXXXX)"

{
        /bin/echo "form = \"branch=${branch}\""
        /bin/echo "form = \"message=${commit_msg}\""
} > "${curl_cfg}"

file_count=0
# Walk all regular files inside source_dir (excluding any .git metadata directory)
while IFS= read -r abs_file
do
        file_count=$((file_count + 1))
        if [ "${file_count}" -gt "${MAX_FILES}" ]
        then
                status "Threshold exceeded: ${source_dir} contains more than ${MAX_FILES} files. Use git CLI fallback."
                exit 2
        fi

        rel_path="${abs_file#"${source_dir%/}/"}"
        # Escape backslashes and double quotes for curl config syntax
        escaped_path="$(/bin/echo "${rel_path}" | /usr/bin/sed 's/\\/\\\\/g; s/"/\\"/g')"
        escaped_abs="$(/bin/echo "${abs_file}" | /usr/bin/sed 's/\\/\\\\/g; s/"/\\"/g')"
        /bin/echo "form = \"${escaped_path}=@${escaped_abs}\"" >> "${curl_cfg}"
done <<EOF
$(/usr/bin/find "${source_dir%/}" -type f ! -path '*/.git/*')
EOF

if [ "${file_count}" -eq 0 ]
then
        status "Error: No files found inside ${source_dir} to push."
        exit 1
fi

status "Uploading ${file_count} file(s) (${total_bytes} bytes) from ${source_dir} to ${workspace}/${repo_slug} [${branch}]..."

# Submit the multipart POST request using transient .netrc and the curl form config file
set +e
RESPONSE=$(/usr/bin/curl --netrc-file "${netrc_dir}/.netrc" -s -K "${curl_cfg}" -X POST "${endpoint}" -w "\nHTTP_STATUS:%{http_code}")
curl_exit=$?
set -e

if [ "${curl_exit}" -ne 0 ]
then
        status "Error: Network or curl failure uploading directory to ${workspace}/${repo_slug}."
        exit 1
fi

HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

case "${HTTP_CODE}" in
        200|201)
                status "Successfully pushed ${file_count} file(s) to ${workspace}/${repo_slug}@${branch}."
                exit 0
                ;;
        400)
                status "Error 400: Bad Request pushing files to Bitbucket."
                status "API Detail: ${RESPONSE_BODY}"
                exit 400
                ;;
        401|403)
                status "Error ${HTTP_CODE}: Unauthorized or token lacks repository:write permission."
                exit "${HTTP_CODE}"
                ;;
        404)
                status "Error 404: Target repository '${workspace}/${repo_slug}' not found."
                exit 404
                ;;
        413)
                status "Error 413: Payload Too Large. Directory exceeds Bitbucket API upload size limits."
                exit 413
                ;;
        429)
                status "Error 429: Bitbucket API rate limit exceeded."
                exit 429
                ;;
        *)
                status "Error ${HTTP_CODE}: Unexpected HTTP response from Bitbucket /src endpoint."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
esac

