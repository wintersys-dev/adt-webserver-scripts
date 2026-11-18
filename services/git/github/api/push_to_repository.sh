#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes a local directory to GitHub via REST API.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     2.0
#:
#: Usage:       push_to_repository.sh <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>
#:              push_to_repository.sh <source_directory> --branch <name> <repository_username> <repository_ownername> <repository_name>
#:              push_to_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Local source directory containing content to push.
#:   $2         [Required] Target branch name (or "--branch" flag followed by name in $3).
#:   $3         [Required] GitHub authentication username.
#:   $4         [Required] Repository owner or organisation.
#:   $5         [Required] Existing target repository name.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - External binaries: base64, cat, curl, cut, echo, find, grep, jq, mktemp, printf, rm, sed, tail, tr
#:
#: Exit Codes:
#:   0          Files successfully committed and pushed (remote URL printed to stdout)
#:   1          Missing arguments, configuration errors, or API failures
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
        /bin/echo "Application root configuration file missing at /home/homedir.dat." >&2
        exit 1
fi

if [ "${2}" = "--branch" ]
then
        if [ "$#" -ne 6 ] || [ -z "${3}" ]
        then
                /bin/echo "Error: Invalid arguments." >&2
                /bin/echo "Usage: $0 <source_directory> --branch <name> <repository_username> <repository_ownername> <repository_name>" >&2
                exit 1
        fi

        source_directory="${1}"
        branch="${3}"
        repository_username="${4}"
        repository_ownername="${5}"
        repository_name="${6}"
else
        if [ "$#" -ne 5 ]
        then
                /bin/echo "Error: Invalid arguments." >&2
                /bin/echo "Usage: $0 <source_directory> <branch> <repository_username> <repository_ownername> <repository_name>" >&2
                exit 1
        fi

        source_directory="${1}"
        branch="${2}"
        repository_username="${3}"
        repository_ownername="${4}"
        repository_name="${5}"
fi

if [ -z "${source_directory}" ] || [ -z "${branch}" ] || [ -z "${repository_username}" ] || [ -z "${repository_ownername}" ] || [ -z "${repository_name}" ]
then
        /bin/echo "Error: All five parameters are required." >&2
        exit 1
fi

if [ ! -d "${source_directory}" ]
then
        /bin/echo "Error: Source directory does not exist: ${source_directory}" >&2
        exit 1
fi

if [ ! -x "${HOME}/utilities/config/ExtractConfigValue.sh" ]
then
        /bin/echo "Error: ExtractConfigValue.sh is missing or not executable." >&2
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

github_api_version="2026-03-10"
api_base="https://api.github.com"
endpoint_url="${api_base}/repos/${repository_ownername}/${repository_name}"

github_api()
{
        method="${1}"
        url="${2}"
        payload="${3}"

        if [ -n "${payload}" ]
        then
                /bin/echo "Authorization: Bearer ${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -sS --globoff \
                        -X "${method}" \
                        -H @- \
                        -H "Accept: application/vnd.github+json" \
                        -H "Content-Type: application/json" \
                        -H "X-GitHub-Api-Version: ${github_api_version}" \
                        "${url}" \
                        -d "${payload}" \
                        -w '\n%{http_code}'
        else
                /bin/echo "Authorization: Bearer ${REPOSITORY_TOKEN}" | \
                        /usr/bin/curl -sS --globoff \
                        -X "${method}" \
                        -H @- \
                        -H "Accept: application/vnd.github+json" \
                        -H "Content-Type: application/json" \
                        -H "X-GitHub-Api-Version: ${github_api_version}" \
                        "${url}" \
                        -w '\n%{http_code}'
        fi
}

working_directory="$(/usr/bin/mktemp -d)"

cleanup()
{
        /bin/rm -rf "${working_directory}"
}

trap cleanup EXIT HUP INT TERM

cd "${source_directory}"

if ! /usr/bin/find . -path './.git' -prune -o -type f -print > "${working_directory}/files"
then
        /bin/echo "Error: Unable to enumerate source files." >&2
        exit 1
fi

if [ ! -s "${working_directory}/files" ]
then
        /bin/echo "Error: No files found in ${source_directory}." >&2
        exit 1
fi

: > "${working_directory}/tree_entries"

/bin/echo "Checking GitHub branch: ${branch}" >&2

set +e
ref_resp="$(github_api "GET" "${endpoint_url}/git/ref/heads/${branch}" "")"
set -e

ref_code="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/tail -n 1)"
ref_body="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/sed '$d')"

parent_sha=""
base_tree=""

if [ "${ref_code}" = "409" ]
then
        # Seed empty repository so Git Data API blobs/trees endpoints are active
        init_payload="{\"message\":\"Initial commit\",\"content\":\"Cg==\",\"branch\":\"${branch}\"}"
        set +e
        init_resp="$(github_api "PUT" "${endpoint_url}/contents/.gitkeep" "${init_payload}")"
        set -e
        init_code="$(/usr/bin/printf '%s\n' "${init_resp}" | /usr/bin/tail -n 1)"
        if [ "${init_code}" != "200" ] && [ "${init_code}" != "201" ]
        then
                /bin/echo "Error ${init_code}: Unable to initialize empty repository." >&2
                exit 1
        fi
        set +e
        ref_resp="$(github_api "GET" "${endpoint_url}/git/ref/heads/${branch}" "")"
        set -e
        ref_code="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/tail -n 1)"
        ref_body="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/sed '$d')"
fi

if [ "${ref_code}" = "200" ]
then
        parent_sha="$(/usr/bin/printf '%s\n' "${ref_body}" | /usr/bin/jq -r '.object.sha // empty')"

        if [ -z "${parent_sha}" ]
        then
                /bin/echo "Error: Unable to retrieve existing branch commit SHA." >&2
                exit 1
        fi

        set +e
        commit_resp="$(github_api "GET" "${endpoint_url}/git/commits/${parent_sha}" "")"
        set -e

        commit_code="$(/usr/bin/printf '%s\n' "${commit_resp}" | /usr/bin/tail -n 1)"
        commit_body="$(/usr/bin/printf '%s\n' "${commit_resp}" | /usr/bin/sed '$d')"

        if [ "${commit_code}" != "200" ]
        then
                /bin/echo "Error ${commit_code}: Unable to retrieve existing commit." >&2
                exit 1
        fi

        base_tree="$(/usr/bin/printf '%s\n' "${commit_body}" | /usr/bin/jq -r '.tree.sha // empty')"

        if [ -z "${base_tree}" ]
        then
                /bin/echo "Error: Unable to retrieve existing tree SHA." >&2
                exit 1
        fi
elif [ "${ref_code}" != "404" ]
then
        /bin/echo "Error ${ref_code}: Unable to inspect target branch." >&2
        /bin/echo "${ref_body}" >&2
        exit 1
fi
/bin/echo "Uploading repository files..." >&2

while IFS= read -r file
do
        clean_path="${file#./}"

        blob_content="$(/usr/bin/base64 < "${file}" | /usr/bin/tr -d '\n')"

        blob_json="$(/usr/bin/jq -n \
                --arg content "${blob_content}" \
                '{
                        "content": $content,
                        "encoding": "base64"
                }'
        )"

        set +e
        blob_resp="$(github_api "POST" "${endpoint_url}/git/blobs" "${blob_json}")"
        set -e

        blob_code="$(/usr/bin/printf '%s\n' "${blob_resp}" | /usr/bin/tail -n 1)"
        blob_body="$(/usr/bin/printf '%s\n' "${blob_resp}" | /usr/bin/sed '$d')"

        blob_sha="$(/usr/bin/printf '%s\n' "${blob_body}" | /usr/bin/jq -r '.sha // empty')"

        if [ "${blob_code}" != "201" ] || [ -z "${blob_sha}" ]
        then
                /bin/echo "Error ${blob_code}: Failed to upload ${clean_path}." >&2
                /bin/echo "${blob_body}" >&2
                exit 1
        fi

        mode="100644"

        if [ -x "${file}" ]
        then
                mode="100755"
        fi

        /usr/bin/jq -cn \
                --arg path "${clean_path}" \
                --arg mode "${mode}" \
                --arg sha "${blob_sha}" \
                '{
                        "path": $path,
                        "mode": $mode,
                        "type": "blob",
                        "sha": $sha
                }' >> "${working_directory}/tree_entries"

done < "${working_directory}/files"

/bin/echo "Creating Git tree..." >&2

if [ -n "${base_tree}" ]
then
        tree_json="$(/usr/bin/jq -n \
                --arg base_tree "${base_tree}" \
                --slurpfile tree "${working_directory}/tree_entries" \
                '{
                        "base_tree": $base_tree,
                        "tree": $tree
                }'
        )"
else
        tree_json="$(/usr/bin/jq -n \
                --slurpfile tree "${working_directory}/tree_entries" \
                '{
                        "tree": $tree
                }'
        )"
fi

set +e
tree_resp="$(github_api "POST" "${endpoint_url}/git/trees" "${tree_json}")"
set -e

tree_code="$(/usr/bin/printf '%s\n' "${tree_resp}" | /usr/bin/tail -n 1)"
tree_body="$(/usr/bin/printf '%s\n' "${tree_resp}" | /usr/bin/sed '$d')"

tree_sha="$(/usr/bin/printf '%s\n' "${tree_body}" | /usr/bin/jq -r '.sha // empty')"

if [ "${tree_code}" != "201" ] || [ -z "${tree_sha}" ]
then
        /bin/echo "Error ${tree_code}: Failed to create GitHub tree." >&2
        /bin/echo "${tree_body}" >&2
        exit 1
fi

/bin/echo "Creating Git commit..." >&2

commit_json="$(/usr/bin/jq -n \
        --arg message "Automated deployment push" \
        --arg tree "${tree_sha}" \
        --arg parent "${parent_sha}" \
        '{
                "message": $message,
                "tree": $tree
        } + (
                if $parent != ""
                then {"parents": [$parent]}
                else {}
                end
                )'
                )"

set +e
commit_resp="$(github_api "POST" "${endpoint_url}/git/commits" "${commit_json}")"
set -e

commit_code="$(/usr/bin/printf '%s\n' "${commit_resp}" | /usr/bin/tail -n 1)"
commit_body="$(/usr/bin/printf '%s\n' "${commit_resp}" | /usr/bin/sed '$d')"

commit_sha="$(/usr/bin/printf '%s\n' "${commit_body}" | /usr/bin/jq -r '.sha // empty')"

if [ "${commit_code}" != "201" ] || [ -z "${commit_sha}" ]
then
        /bin/echo "Error ${commit_code}: Failed to create GitHub commit." >&2
        /bin/echo "${commit_body}" >&2
        exit 1
fi

/bin/echo "Updating GitHub branch..." >&2

if [ -n "${parent_sha}" ]
then
        ref_json="$(/usr/bin/jq -n \
                --arg sha "${commit_sha}" \
                '{
                        "sha": $sha,
                        "force": false
                }'
        )"

        set +e
        ref_resp="$(github_api "PATCH" "${endpoint_url}/git/refs/heads/${branch}" "${ref_json}")"
        set -e

        ref_code="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/tail -n 1)"
        ref_body="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/sed '$d')"

        if [ "${ref_code}" != "200" ]
        then
                /bin/echo "Error ${ref_code}: Failed to update branch." >&2
                /bin/echo "${ref_body}" >&2
                exit 1
        fi
else
        ref_json="$(/usr/bin/jq -n \
                --arg ref "refs/heads/${branch}" \
                --arg sha "${commit_sha}" \
                '{
                        "ref": $ref,
                        "sha": $sha
                }'
        )"

        set +e
        ref_resp="$(github_api "POST" "${endpoint_url}/git/refs" "${ref_json}")"
        set -e

        ref_code="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/tail -n 1)"
        ref_body="$(/usr/bin/printf '%s\n' "${ref_resp}" | /usr/bin/sed '$d')"

        if [ "${ref_code}" != "201" ]
        then
                /bin/echo "Error ${ref_code}: Failed to create branch." >&2
                /bin/echo "${ref_body}" >&2
                exit 1
        fi
fi

/bin/echo "https://github.com/${repository_ownername}/${repository_name}.git"
exit 0
