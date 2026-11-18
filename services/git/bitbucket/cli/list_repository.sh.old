#!/bin/sh
#: Name:        get_repository.sh
#: Purpose:     Checks a specific Bitbucket repository using native Git CLI (git ls-remote)
#:              and transient .netrc auth, outputting "none", "empty", or "full".
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       get_repository.sh [workspace] [repo_slug]
#:              get_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Override for GIT_WORKSPACE from runtime context.
#:   $2         [Optional] Override for GIT_REPOSITORY from runtime context.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - CreateTransientNetRC.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, rm, git
#:
#: Output (stdout):
#:   none       Repository does not exist
#:   empty      Repository exists but has zero commits/refs
#:   full       Repository exists and contains commits/refs
#:
#: Exit Codes:
#:   0          Repository state determined cleanly and emitted to stdout
#:   *          Missing context variables, auth failure, or network error
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

# Route status log entries strictly to stderr so stdout emits only none|empty|full
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Ensure transient .netrc directory is always removed on exit
netrc_dir=""
cleanup()
{
        [ -n "${netrc_dir}" ] && /bin/rm -rf "${netrc_dir}"
}
trap cleanup EXIT

# Fetch workspace and repository name from runtime context unless overridden via CLI
set +e
workspace="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
set -e

if [ -z "${workspace}" ] || [ -z "${raw_repo}" ]
then
        status "Error: Failed to fetch required context variables (GIT_WORKSPACE, GIT_REPOSITORY)."
        exit 1
fi

repo_slug="$(/bin/echo "${raw_repo}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"

# Generate transient .netrc directory from active runtime context
set +e
netrc_dir="$("${BUILD_HOME}/services/git/CreateTransientNetRC.sh")"
netrc_exit=$?
set -e

if [ "${netrc_exit}" -ne 0 ] || [ -z "${netrc_dir}" ]
then
        status "Error: Failed to create transient .netrc authentication context."
        exit 1
fi

host_domain="bitbucket.org"
remote_url="https://${host_domain}/${workspace}/${repo_slug}.git"

# Probe remote refs using git ls-remote (capturing stderr separately to distinguish 404 vs auth error)
err_file="/tmp/adt-lsremote-err-$$.log"
set +e
refs_output="$(HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 /usr/bin/git ls-remote "${remote_url}" 2>"${err_file}")"
ls_exit=$?
set -e

err_msg="$(/bin/cat "${err_file}" 2>/dev/null || true)"
/bin/rm -f "${err_file}"

if [ "${ls_exit}" -eq 0 ]
then
        if [ -n "${refs_output}" ]
        then
                /bin/echo "full"
        else
                /bin/echo "empty"
        fi
        exit 0
fi

# Inspect git ls-remote stderr to separate "not found" (none) from auth/network errors
if /bin/echo "${err_msg}" | /usr/bin/grep -qiE "not found|does not exist"
then
        /bin/echo "none"
        exit 0
fi

status "Error: Git CLI ls-remote failed for ${workspace}/${repo_slug}: ${err_msg}"
exit 1
