#!/bin/sh
###################################################################################
# @file        push_repository.sh
# @brief       Commits and pushes a local directory to an existing Bitbucket repository.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates the source directory, branch, and
#              target repository arguments, initialises Git if needed, stages and
#              commits all directory content, writes ephemeral mode-0600 netrc
#              credentials in an isolated temporary directory cleaned on exit, and
#              pushes the branch to Bitbucket.
#
# @param       $1  [Required] Local source directory containing content to push.
# @param       $2  [Required] Target branch name or "--branch <name>" flag.
# @param       $3  [Required] The Bitbucket authentication username.
# @param       $4  [Required] The Bitbucket workspace or repository owner name.
# @param       $5  [Required] The name/slug of the existing target repository.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, chmod, echo, git, mktemp, rm, sed
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Isolates netrc credentials in a mode-0600 ephemeral directory cleaned via trap.
#              - Keeps credentials completely out of CLI arguments, URLs, and process trees.
#
# @exit        0  Success: Directory content committed and pushed to remote repository.
# @exit        *  Failure: Missing arguments, invalid directory, layout faults, or git push error.
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
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'REPOSITORY_TOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (REPOSITORY_TOKEN)." >&2
        exit 1
fi

# Create an isolated, restrictive temporary directory for .netrc so Git can read it
netrc_dir="$(/bin/mktemp -d)"
/bin/chmod 0700 "${netrc_dir}"

cleanup() {
        /bin/rm -rf "${netrc_dir}"
}
trap cleanup EXIT INT TERM

/bin/cat <<EOF > "${netrc_dir}/.netrc"
machine bitbucket.org
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF
/bin/chmod 0600 "${netrc_dir}/.netrc"

# Scrub token from environment before invoking git
unset REPOSITORY_TOKEN

cd "${source_directory}"

set +e
# Initialise Git repository if not already initialised
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

# Ensure local commit identity is set inside the repository scope
/usr/bin/git config user.name "${repository_username}"
/usr/bin/git config user.email "${repository_username}@users.noreply.bitbucket.org"

# Stage all files in the directory
/usr/bin/git add -A

# Commit staged changes if any exist (or if repository has no commits yet)
if ! /usr/bin/git diff --cached --quiet || ! /usr/bin/git rev-parse --verify HEAD >/dev/null 2>&1
then
        /usr/bin/git commit -m "Automated deployment push" >/dev/null 2>&1
        commit_status="$?"
        if [ "${commit_status}" -ne 0 ]
        then
                /bin/echo "Error: Failed to commit changes in ${source_directory} (exit code: ${commit_status})." >&2
                exit "${commit_status}"
        fi
fi

# Configure clean remote URL without embedded credentials
remote_url="https://bitbucket.org{repository_ownername}/${repository_name}.git"
/usr/bin/git remote remove origin >/dev/null 2>&1
/usr/bin/git remote add origin "${remote_url}"

# Push branch using isolated HOME so libcurl reads ${netrc_dir}/.netrc
HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 /usr/bin/git push -u origin "${branch}" >&2
git_status="$?"
set -e

if [ "${git_status}" -ne 0 ]
then
        /bin/echo "Error: Git push to ${remote_url} on branch ${branch} failed (exit code: ${git_status})." >&2
        exit "${git_status}"
fi

/bin/echo "${remote_url}"
exit 0
