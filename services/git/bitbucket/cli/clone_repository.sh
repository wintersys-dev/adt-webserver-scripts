#!/bin/sh
#: Name:        clone_repository.sh
#: Purpose:     Clones a Bitbucket repository branch using standard Git CLI commands
#:              and transient .netrc authentication resolved from runtime context.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       clone_repository.sh [workspace] [repo_slug] [branch_or_tag] [target_dir]
#:              clone_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Override for GIT_WORKSPACE from runtime context.
#:   $2         [Optional] Override for GIT_REPOSITORY from runtime context.
#:   $3         [Optional] Override for GIT_BRANCH from runtime context.
#:   $4         [Optional] Override for GIT_TARGET_DIR from runtime context.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - CreateTransientNetrc.sh
#:   - External binaries: cat, echo, grep, cut, sed, tr, mkdir, rm, git
#:
#: Exit Codes:
#:   0          Repository cloned cleanly into target directory
#:   *          Missing context variables, non-empty target directory, or Git clone failure
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

# Ensure transient .netrc directory is always removed on exit
netrc_dir=""
cleanup()
{
        [ -n "${netrc_dir}" ] && /bin/rm -rf "${netrc_dir}"
}
trap cleanup EXIT

# Fetch required values from the active deployment context (allowing optional CLI overrides)
set +e
workspace="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
branch="${3:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_BRANCH)}"
target_dir="${4:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_TARGET_DIR)}"
set -e

if [ -z "${workspace}" ] || [ -z "${raw_repo}" ] || [ -z "${branch}" ] || [ -z "${target_dir}" ]
then
        status "Error: Failed to fetch required context variables (GIT_WORKSPACE, GIT_REPOSITORY, GIT_BRANCH, GIT_TARGET_DIR)."
        exit 1
fi

# Prevent git clone from failing unexpectedly if target_dir already exists and is non-empty
if [ -d "${target_dir}" ] && [ -n "$(/bin/ls -A "${target_dir}" 2>/dev/null)" ]
then
        status "Error: Target directory '${target_dir}' already exists and is not empty."
        exit 1
fi

# Generate transient .netrc directory from active runtime context (no arguments needed)
set +e
netrc_dir="$("${BUILD_HOME}/services/git/CreateTransientNetRC.sh")"
netrc_exit=$?
set -e

if [ "${netrc_exit}" -ne 0 ] || [ -z "${netrc_dir}" ]
then
        status "Error: Failed to create transient .netrc authentication context."
        exit 1
fi

repo_slug="$(/bin/echo "${raw_repo}" | /usr/bin/tr '[:upper:]' '[:lower:]' | /usr/bin/tr -cs 'a-z0-9_-' '-' | /usr/bin/sed 's/^-//;s/-$//')"

# Assemble clean HTTPS clone URL (credentials supplied automatically via transient .netrc)
host_domain="bitbucket.org"
clone_url="https://${host_domain}/${workspace}/${repo_slug}.git"

# Ensure parent directory exists before cloning
/bin/mkdir -p "$(/usr/bin/dirname "${target_dir}")"

status "Cloning ${workspace}/${repo_slug} [${branch}] into ${target_dir} via Git CLI..."

# Perform a shallow single-branch clone using isolated HOME for .netrc lookup
set +e
HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 \
        /usr/bin/git clone --depth 1 --branch "${branch}" --single-branch "${clone_url}" "${target_dir}" -q
clone_exit=$?
set -e

if [ "${clone_exit}" -ne 0 ]
then
        status "Error: Git CLI clone failed for ${workspace}/${repo_slug} on branch '${branch}' (exit code ${clone_exit})."
        exit 1
fi

status "Successfully cloned ${workspace}/${repo_slug}@${branch} into ${target_dir}."
exit 0
