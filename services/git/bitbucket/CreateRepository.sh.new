#!/bin/sh
#: Name:        push_to_repository.sh
#: Purpose:     Commits and pushes the contents of a local directory to a Bitbucket
#:              repository branch using standard Git CLI commands and transient .netrc auth.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       push_to_repository.sh [source_dir] [branch] [commit_message] [workspace] [repo_slug]
#:              push_to_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Override for GIT_SOURCE_DIR from runtime context.
#:   $2         [Optional] Override for GIT_BRANCH from runtime context (defaults to "main").
#:   $3         [Optional] Commit message (defaults to "Initial deployment commit").
#:   $4         [Optional] Override for GIT_WORKSPACE from runtime context.
#:   $5         [Optional] Override for GIT_REPOSITORY from runtime context.
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
#: Exit Codes:
#:   0          Directory contents committed and pushed cleanly via Git CLI
#:   *          Missing context variables, invalid directory, or Git push failure
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
source_dir="${1:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_SOURCE_DIR)}"
branch="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_BRANCH)}"
commit_msg="${3:-Initial deployment commit}"
workspace="${4:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_WORKSPACE)}"
raw_repo="${5:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_REPOSITORY)}"
git_author_name="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_AUTHOR_NAME)"
git_author_email="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_AUTHOR_EMAIL)"
set -e

branch="${branch:-main}"
git_author_name="${git_author_name:-Wintersys Deployment}"
git_author_email="${git_author_email:-deploy@wintersys.uk}"

if [ -z "${source_dir}" ] || [ -z "${workspace}" ] || [ -z "${raw_repo}" ]
then
        status "Error: Failed to fetch required context variables (GIT_SOURCE_DIR, GIT_WORKSPACE, GIT_REPOSITORY)."
        exit 1
fi

if [ ! -d "${source_dir}" ]
then
        status "Error: Source directory does not exist at ${source_dir}."
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

# Assemble clean HTTPS remote URL (credentials supplied automatically via transient .netrc)
host_domain="bitbucket.org"
remote_url="https://${host_domain}/${workspace}/${repo_slug}.git"

cd "${source_dir}"

# Initialise repository if .git does not already exist
if [ ! -d ".git" ]
then
        /usr/bin/git init -q
fi

# Configure local repository identity
/usr/bin/git config user.name "${git_author_name}"
/usr/bin/git config user.email "${git_author_email}"

# Ensure target branch is checked out cleanly
/usr/bin/git checkout -B "${branch}" -q

# Stage all files in source_dir
/usr/bin/git add -A

# Commit only if there are staged changes or no commits exist yet
if ! /usr/bin/git diff --cached --quiet || ! /usr/bin/git rev-parse --verify HEAD >/dev/null 2>&1
then
        /usr/bin/git commit -m "${commit_msg}" -q
else
        status "No new file changes to commit in ${source_dir}; proceeding to push branch '${branch}'."
fi

# Set or update the origin remote URL cleanly
if /usr/bin/git remote get-url origin >/dev/null 2>&1
then
        /usr/bin/git remote set-url origin "${remote_url}"
else
        /usr/bin/git remote add origin "${remote_url}"
fi

status "Pushing ${source_dir} to ${workspace}/${repo_slug} [${branch}] via Git CLI..."

# Push branch to Bitbucket using isolated HOME for .netrc lookup
set +e
HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 \
        /usr/bin/git push -u origin "${branch}" -q
push_exit=$?
set -e

if [ "${push_exit}" -ne 0 ]
then
        status "Error: Git CLI push failed for ${workspace}/${repo_slug} on branch '${branch}' (exit code ${push_exit})."
        exit 1
fi

status "Successfully pushed ${source_dir} to ${workspace}/${repo_slug}@${branch} via Git CLI."
exit 0
