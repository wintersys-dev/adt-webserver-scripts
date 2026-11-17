#!/bin/sh
#: Name:        GitLSRemote.sh
#: Purpose:     Probes a remote Bitbucket Cloud repository and classifies its state as "full", "empty", or "none".
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       GitLSRemote.sh "<workspace_id>" "<repository_name>"
#:              GitLSRemote.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Bitbucket workspace ID or account namespace (e.g. agiledeployer)
#:   $2         [Required] Slug/name of the target Bitbucket repository
#:
#: Environment:
#:   HOME             Resolved automatically from /home/homedir.dat
#:   REPOSITORY_TOKEN Resolved from ExtractConfigValue.sh ('APPLICATIONREPOSITORYTOKEN') if not exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/.netrc (created transiently with mode 600 and removed on exit)
#:   - External binaries: cat, echo, grep, cut, tr, chmod, rm, mktemp, git
#:
#: Exit Codes:
#:   0          Repository probe completed; emits "full", "empty", or "none" on stdout
#:   1          Missing required arguments or unreadable /home/homedir.dat
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

# Construct temporary .netrc with restricted permissions and guaranteed cleanup on exit
netrc_file="${HOME}/.netrc"
tmp_dir=""
trap '/bin/rm -rf "${tmp_dir}" "${netrc_file}"' EXIT

if [ -z "${REPOSITORY_TOKEN}" ] && [ -x "${HOME}/utilities/config/ExtractConfigValue.sh" ]
then
        REPOSITORY_TOKEN="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'APPLICATIONREPOSITORYTOKEN')"
fi

if [ -n "${REPOSITORY_TOKEN}" ]
then
        (
                umask 077
                /bin/cat << EOF > "${netrc_file}"
machine bitbucket.org
login x-bitbucket-api-token-auth
password ${REPOSITORY_TOKEN}
EOF
        )
        /bin/chmod 600 "${netrc_file}"
fi

# Assemble target Bitbucket repository URL from split components
git_host="bitbucket.org"
repo_url="https://${git_host}/${workspace_id}/${repo_slug}.git"

# Step 1: Perform non-interactive remote ref lookup (immune to set -e via 'if !')
if ! remote_refs="$(GIT_TERMINAL_PROMPT=0 /usr/bin/git -c credential.helper= ls-remote "${repo_url}" 2>/dev/null)"
then
        /bin/echo "none"
        exit 0
fi

# Zero refs indicates a brand-new repository with 0 commits
if [ -z "${remote_refs}" ]
then
        /bin/echo "empty"
        exit 0
fi

# Step 2: Repository has commit history; perform treeless shallow clone to check for files at HEAD
tmp_dir="$(/usr/bin/mktemp -d)"

if GIT_TERMINAL_PROMPT=0 /usr/bin/git -c credential.helper= clone --depth 1 --filter=blob:none --no-checkout "${repo_url}" "${tmp_dir}" >/dev/null 2>&1
then
        tracked_files="$(/usr/bin/git -C "${tmp_dir}" ls-tree -r --name-only HEAD 2>/dev/null || true)"
        if [ -n "${tracked_files}" ]
        then
                /bin/echo "full"
        else
                /bin/echo "empty"
        fi
else
        /bin/echo "none"
fi

exit 0
