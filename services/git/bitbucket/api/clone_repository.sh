#!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Downloads and extracts a Bitbucket repository branch archive via HTTPS.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       clone_repository.sh <workspace> <repo_slug> <branch_or_tag> <target_dir>
#:              clone_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Bitbucket workspace slug (e.g. "wintersys").
#:   $2         [Required] Repository slug (e.g. "my-website-repo").
#:   $3         [Required] Branch name, tag, or commit hash (e.g. "main").
#:   $4         [Required] Local directory path where files will be extracted.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, mkdir, rm, tar, curl
#:
#: Exit Codes:
#:   0          Repository archive downloaded and extracted cleanly
#:   *          Missing arguments, HTTP error, or archive extraction failure
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

# Validate all required arguments
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: Workspace, repository slug, branch/tag, and target directory are required."
        status "Usage: $0 <workspace> <repo_slug> <branch_or_tag> <target_dir>"
        exit 1
fi

workspace="${1}"
repo_slug="$(/bin/echo "${2}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"
branch="${3}"
target_dir="${4}"

# Retrieve the Bitbucket authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (GIT_TOKEN)."
        exit 1
fi

# Assemble archive download URL from split components
host_domain="bitbucket.org"
archive_url="https://${host_domain}/${workspace}/${repo_slug}/get/${branch}.tar.gz"
tmp_archive="/tmp/${repo_slug}-${branch}-$$.tar.gz"

# Download the compressed archive following redirects (-L) with token passed via stdin
set +e
HTTP_CODE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -L -o "${tmp_archive}" -w "%{http_code}" "${archive_url}")
curl_exit=$?
set -e

if [ "${curl_exit}" -ne 0 ]
then
        /bin/rm -f "${tmp_archive}"
        status "Error: Network or curl failure while downloading archive from ${archive_url}."
        exit 1
fi

case "${HTTP_CODE}" in
        200)
                /bin/mkdir -p "${target_dir}"
                # Strip Bitbucket's top-level '<workspace>-<repo>-<hash>' wrapper directory
                if /bin/tar -xzf "${tmp_archive}" -C "${target_dir}" --strip-components=1
                then
                        /bin/rm -f "${tmp_archive}"
                        status "Repository archive ${workspace}/${repo_slug}@${branch} extracted to ${target_dir}."
                        exit 0
                else
                        /bin/rm -f "${tmp_archive}"
                        status "Error: Downloaded file was not a valid tar.gz archive (check token permissions)."
                        exit 1
                fi
                ;;
        401|403)
                /bin/rm -f "${tmp_archive}"
                status "Error ${HTTP_CODE}: Unauthorized or forbidden accessing ${workspace}/${repo_slug}."
                exit "${HTTP_CODE}"
                ;;
        404)
                /bin/rm -f "${tmp_archive}"
                status "Error 404: Repository '${workspace}/${repo_slug}' or branch '${branch}' not found."
                exit 404
                ;;
        *)
                /bin/rm -f "${tmp_archive}"
                status "Error ${HTTP_CODE}: Unexpected HTTP response downloading repository archive."
                exit 1
                ;;
esac
