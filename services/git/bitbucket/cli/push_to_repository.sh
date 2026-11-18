#!/bin/sh
###################################################################################
# @file        push_to_repository.sh
# @brief       Commits and pushes a local directory to Bitbucket via Git CLI.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates the source directory, branch, and
#              target repository arguments, encodes credentials via pipe into
#              GIT_CONFIG_COUNT environment variables so no temporary files touch
#              disk or appear in process trees, initialises or updates the local
#              Git repository, commits all files, and pushes to Bitbucket.
#
# @param       $1  [Required] Local source directory containing content to push.
# @param       $2  [Required] Target branch name or "--branch <name>" flag.
# @param       $3  [Required] The Bitbucket authentication username.
# @param       $4  [Required] The Bitbucket workspace or repository owner name.
# @param       $5  [Required] The name/slug of the existing target repository.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: base64, cat, echo, find, git, printf, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Uses GIT_CONFIG_COUNT env vars so no netrc files touch disk and no secrets appear in ps.
#              - Scrubs sensitive environment variables immediately after execution.
#
# @exit        0  Success: Directory files committed and pushed cleanly via Git CLI.
# @exit        *  Failure: Missing arguments, empty directory, layout faults, or git error.
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
#set -x
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
