#!/bin/sh
###################################################################################
# @file        list_repository.sh
# @brief       Checks a single Bitbucket Git repository state ("full", "empty", or "none") via netrc.
# @author      Peter Winter
# @date        18/11/2026
# @version     1.0
#
# @details     This script retrieves the Bitbucket authentication token from the
#              toolkit configuration, validates the target username, owner, and
#              repository parameters, writes ephemeral mode-0600 netrc credentials
#              inside an isolated temporary directory cleaned on exit, and runs
#              git ls-remote to determine whether the repository has commits ("full"),
#              exists with no commits ("empty"), or does not exist ("none").
#
# @param       $1  [Required] The Bitbucket workspace or repository owner name.
# @param       $2  [Required] The name/slug of the repository to inspect.
#
# @env         HOME              Path to the toolkit core framework layout directory.
# @env         REPOSITORY_TOKEN  The Bitbucket API access token or App Password.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active framework layout.
#              - external dependencies: cat, chmod, echo, git, grep, mktemp, rm
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Isolates netrc credentials in a mode-0600 ephemeral directory cleaned via trap.
#              - Keeps credentials completely out of CLI arguments, URLs, and process trees.
#
# @exit        0  Success: Repository state ("full", "empty", or "none") printed to stdout.
# @exit        *  Failure: Missing arguments, layout faults, or missing credentials.
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

if [ -z "${1}" ] || [ -z "${2}" ] 
then
        /bin/echo "Error: Repository owner name, and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_ownername> <repository_name>" >&2
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] 
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN)." >&2
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
login x-bitbucket-api-token-auth
password ${REPOSITORY_TOKEN}
EOF
/bin/chmod 0600 "${netrc_dir}/.netrc"

unset REPOSITORY_TOKEN

set +e
ls_output="$(HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 /usr/bin/git ls-remote "https://bitbucket.org/${repository_ownername}/${repository_name}.git" 2>/dev/null)"
git_status="$?"
set -e

if [ "${git_status}" -ne 0 ]
then
        /bin/echo "none"
        exit 0
fi

if /bin/echo "${ls_output}" | /bin/grep -q 'HEAD'
then
        /bin/echo "full"
else
        /bin/echo "empty"
fi

exit 0

