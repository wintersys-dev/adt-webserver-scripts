#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes a local directory to GitHub via REST API (Git Data API).
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.1
#:
#: Usage:       push_to_repository.sh <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>
#:              push_to_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Local source directory containing content to push.
#:   $2         [Required] Target branch name or "--branch <name>" flag.
#:   $3         [Required] The GitHub authentication username.
#:   $4         [Required] The GitHub organisation or repository owner name.
#:   $5         [Required] The name/slug of the existing target repository.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: cat, curl, cut, echo, find, grep, jq, sed, tail
#:
#: Exit Codes:
#:   0          Directory files committed and pushed cleanly via GitHub API
#:   1          Missing arguments, invalid or empty directory, layout faults, missing credentials, or API error
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

#set -x
set -e

if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: Source directory, branch, username, owner name, and repository name are required." >&2
        /bin/echo "Usage: $0 <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>" >&2
        exit 1
fi

source_directory="${1}"
branch="$(/bin/echo "${2}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"

if [ ! -d "${source_directory}" ]
then
        /bin/echo "Error: Source directory does not exist at ${source_directory}." >&2
        exit 1
fi

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN)." >&2
        exit 1
fi

cd "${source_directory}"

if [ -z "$(/usr/bin/find . -path './.git' -prune -o -type f -print)" ]
then
        /bin/echo "Error: No files found to push in ${source_directory}." >&2
        exit 1
fi

repo_endpoint="https://github.com/${repository_ownername}/${repository_name}"

github_api() {
        /bin/echo "Authorization: Bearer ${REPOSITORY_TOKEN}" | \
                /usr/bin/curl -s -X "${1}" -H @- \
                -H "Accept: application/vnd.github+json" \
                -H "Content-Type: application/json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "${2}" ${3:+-d "${3}"} -w "\n%{http_code}"
}

# Initialize empty repositories so Git Data API refs exist
set +e
resp="$(github_api "GET" "${repo_endpoint}/commits?per_page=1")"
set -e
if [ "$(/bin/echo "${resp}" | /usr/bin/tail -n1)" = "409" ]
then
        init_json="{\"message\":\"Initial commit\",\"content\":\"Cg==\",\"branch\":\"${branch}\"}"
        github_api "PUT" "${repo_endpoint}/contents/.gitkeep" "${init_json}" >/dev/null
fi
# Build the entire tree JSON in one stream (no per-file blob uploads or temp files)
tree_json="$(
        /usr/bin/find . -path './.git' -prune -o -type f -print | while IFS= read -r rel_path
        do
                clean_path="${rel_path#./}"
                mode="100644"
                [ -x "${clean_path}" ] && mode="100755"
                /usr/bin/jq -n --arg p "${clean_path}" --arg m "${mode}" --rawfile c "${clean_path}" \
                        '{"path":$p,"mode":$m,"type":"blob","content":$c}'
        done | /usr/bin/jq -s '{"tree":.}'
)"

# 1. Create Tree
set +e
tree_resp="$(github_api "POST" "${repo_endpoint}/git/trees" "${tree_json}")"
set -e
tree_code="$(/bin/echo "${tree_resp}" | /usr/bin/tail -n1)"
tree_sha="$(/bin/echo "${tree_resp}" | /usr/bin/sed '$d' | /usr/bin/jq -r '.sha // empty')"

if [ "${tree_code}" != "201" ] || [ -z "${tree_sha}" ]
then
        /bin/echo "Error ${tree_code}: Failed to create GitHub tree object." >&2
        exit 1
fi

# 2. Create Commit
commit_json="$(/usr/bin/jq -n \
        --arg m "Automated deployment push" \
        --arg t "${tree_sha}" \
        --arg n "${repository_username}" \
        --arg e "${repository_username}@://github.com" \
        '{"message":$m,"tree":$t,"author":{"name":$n,"email":$e}}')"

set +e
commit_resp="$(github_api "POST" "${repo_endpoint}/git/commits" "${commit_json}")"
set -e
commit_code="$(/bin/echo "${commit_resp}" | /usr/bin/tail -n1)"
commit_sha="$(/bin/echo "${commit_resp}" | /usr/bin/sed '$d' | /usr/bin/jq -r '.sha // empty')"

if [ "${commit_code}" != "201" ] || [ -z "${commit_sha}" ]
then
        /bin/echo "Error ${commit_code}: Failed to create GitHub commit object." >&2
        exit 1
fi

# 3. Force-update existing branch ref or create it if missing
set +e
ref_resp="$(github_api "PATCH" "${repo_endpoint}/git/refs/heads/${branch}" "{\"sha\":\"${commit_sha}\",\"force\":true}")"
set -e
ref_code="$(/bin/echo "${ref_resp}" | /usr/bin/tail -n1)"

if [ "${ref_code}" != "200" ]
then
        set +e
        create_resp="$(github_api "POST" "${repo_endpoint}/git/refs" "{\"ref\":\"refs/heads/${branch}\",\"sha\":\"${commit_sha}\"}")"
        set -e
        create_code="$(/bin/echo "${create_resp}" | /usr/bin/tail -n1)"
        if [ "${create_code}" != "201" ]
        then
                /bin/echo "Error ${create_code}: Failed to update or create branch '${branch}'." >&2
                exit 1
        fi
fi

/bin/echo "https://github.com/${repository_ownername}/${repository_name}.git"
exit 0
