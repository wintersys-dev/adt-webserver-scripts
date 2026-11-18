#!/bin/sh

set -e

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

# Encode credentials via pipe without writing any temporary files to disk
encoded_auth="$(/usr/bin/printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"
unset REPOSITORY_TOKEN

if [ -z "${encoded_auth}" ]
then
        /bin/echo "Error: Failed to encode Bitbucket authentication header." >&2
        exit 1
fi

# Build the full Git remote URL beforehand
git_base="https://bitbucket.org"
remote_url="${git_base}/${repository_ownername}/${repository_name}.git"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.extraheader"
export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"
export GIT_TERMINAL_PROMPT=0

set +e
if [ ! -d "${source_directory}/.git" ]
then
        /usr/bin/git init -b "${branch}" >/dev/null 2>&1
        if [ "$?" -ne 0 ]
        then
                /usr/bin/git init >/dev/null 2>&1
                /usr/bin/git checkout -b "${branch}" >/dev/null 2>&1
        fi
else
        /usr/bin/git checkout -B "${branch}" >/dev/null 2>&1
fi

/usr/bin/git config user.name "${repository_username}"
/usr/bin/git config user.email "${repository_username}@users.noreply.bitbucket.org"

/usr/bin/git add -A

if ! /usr/bin/git diff --cached --quiet || ! /usr/bin/git rev-parse --verify HEAD >/dev/null 2>&1
then
        /usr/bin/git commit -m "Automated deployment push" >/dev/null 2>&1
        commit_status="$?"
        if [ "${commit_status}" -ne 0 ]
        then
                unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_TERMINAL_PROMPT encoded_auth
                /bin/echo "Error: Failed to commit changes in ${source_directory} (exit code: ${commit_status})." >&2
                exit "${commit_status}"
        fi
fi

/usr/bin/git remote remove origin >/dev/null 2>&1
/usr/bin/git remote add origin "${remote_url}"

/usr/bin/git push -f -u origin "${branch}" >&2
git_status="$?"
set -e

unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_TERMINAL_PROMPT encoded_auth

if [ "${git_status}" -ne 0 ]
then
        /bin/echo "Error: Git push to ${remote_url} on branch ${branch} failed (exit code: ${git_status})." >&2
        exit "${git_status}"
fi

/bin/echo "${remote_url}"
exit 0
