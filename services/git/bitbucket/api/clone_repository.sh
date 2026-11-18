#!/bin/sh
###################################################################################
# @file        clone_repository.sh
# @brief       Downloads and extracts a Bitbucket repository branch via REST API.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.1
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates target repository parameters, feeds
#              credentials securely via an ephemeral netrc file descriptor (/dev/fd/3),
#              downloads the branch tarball via Bitbucket's archive endpoint under a
#              strict HTTP status monitoring block, and extracts it into the target
#              destination directory without requiring a full Git history.
#
# @param       $1  [Required] Target branch name or "--branch <name>" flag.
# @param       $2  [Required] The Bitbucket workspace or repository owner name.
# @param       $3  [Required] The name/slug of the repository to download.
# @param       $4  [Required] Local destination directory for the extracted files.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, curl, cut, echo, grep, mkdir, mktemp, rm, sed, tar
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses --netrc-file /dev/fd/3 to avoid writing secrets to disk or exposing them in ps.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Repository archive fetched and extracted cleanly.
# @exit        *  Failure: Missing arguments, layout faults, extraction error, or non-2xx HTTP code.
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        /bin/echo "Error: Branch, repository owner, repository name, and destination directory are required." >&2
        /bin/echo "Usage: $0 <branch> <repository_ownername> <repository_name> <destination_directory>" >&2
        exit 1
fi

# Strip optional "--branch " prefix so both "main" and "--branch main" inputs work cleanly
branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (REPOSITORY_TOKEN)." >&2
        exit 1
fi

# Create a temporary file for the downloaded tarball and ensure cleanup on exit
tmp_archive="$(/bin/mktemp /tmp/repo_archive.XXXXXX.tar.gz)"

cleanup() {
        /bin/rm -f "${tmp_archive}"
}
trap cleanup EXIT INT TERM

set +e
# Open file descriptor 3 with netrc credentials in memory (no disk write)
exec 3<<EOF
machine bitbucket.org
login x-bitbucket-api-token-auth
password ${REPOSITORY_TOKEN}
EOF

# Download the branch archive via Bitbucket's archive endpoint, following redirects (-L)
HTTP_CODE=$(/usr/bin/curl -s -L --netrc-file /dev/fd/3 \
    -o "${tmp_archive}" \
    -w "%{http_code}" \
    "https://bitbucket.org{repository_ownername}/${repository_name}/get/${branch}.tar.gz")

# Immediately close file descriptor 3
exec 3<&-
set -e

# Evaluate the HTTP response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200)
        /bin/mkdir -p "${destination_directory}"
        set +e
        # Bitbucket archives wrap files in a top-level "<owner>-<repo>-<commit>/" folder; --strip-components=1 flattens it
        /bin/tar -xzf "${tmp_archive}" -C "${destination_directory}" --strip-components=1 2>&1 >&2
        tar_status="$?"
        set -e

        if [ "${tar_status}" -ne 0 ]
        then
                /bin/echo "Error: Failed to extract repository archive into ${destination_directory}." >&2
                exit 1
        fi

        /bin/echo "${destination_directory}"
        exit 0
        ;;
    400)
        /bin/echo "Error 400: Bad Request. Check branch or repository parameter syntax." >&2
        exit 400
        ;;
    401)
        /bin/echo "Error 401: Unauthorized. Your REPOSITORY_TOKEN is invalid or has expired." >&2
        exit 401
        ;;
    403)
        /bin/echo "Error 403: Forbidden. Token lacks read permissions for ${repository_ownername}/${repository_name}." >&2
        exit 403
        ;;
    404)
        /bin/echo "Error 404: Not Found. Repository ${repository_ownername}/${repository_name} or branch '${branch}' does not exist." >&2
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
        exit 1
        ;;
esac

exit 0
