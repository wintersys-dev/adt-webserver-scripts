#!/bin/sh
#: Name:        CreateTransientNetrc.sh
#: Purpose:     Creates an isolated transient HOME directory containing a 0600 .netrc
#:              file covering both Git CLI domains and REST API endpoints across
#:              GitHub, GitLab, Bitbucket, and Codeberg.
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.1
#:
#: Usage:       CreateTransientNetrc.sh [provider] [token] [custom_host]
#:              CreateTransientNetrc.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Git provider (github|gitlab|bitbucket|codeberg). Defaults to GIT_CHOICE.
#:   $2         [Optional] Access token override. Defaults to GIT_TOKEN from runtime context.
#:   $3         [Optional] Custom hostname override (for self-hosted GitLab/Forgejo instances).
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, tr, install, mktemp, rm
#:
#: Output (stdout):
#:   Path to the temporary directory containing .netrc (caller must remove on exit)
#:
#: Exit Codes:
#:   0          Transient .netrc directory created cleanly and path emitted to stdout
#:   1          Missing context variables, unsupported provider, or filesystem error
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

# Route status log entries strictly to stderr so stdout emits only the temp path
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Fetch provider and token from runtime context unless overridden via arguments
set +e
raw_provider="${1:-$("${BUILD_HOME}/services/git/GitProviderURL.sh")}"
token="${2:-$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" GIT_TOKEN)}"
custom_host="${3}"
set -e

if [ -z "${raw_provider}" ] || [ -z "${token}" ]
then
        status "Error: Failed to resolve required Git authentication context (GIT_CHOICE, GIT_TOKEN)."
        exit 1
fi

provider="$(/bin/echo "${raw_provider}" | /usr/bin/tr '[:upper:]' '[:lower:]')"

# Map each Git provider to its Git CLI host, REST API host, and token login username
case "${provider}" in
        github)
                git_host="${custom_host:-github.com}"
                api_host="${custom_host:://github.com}"
                netrc_login="x-access-token"
                ;;
        gitlab)
                git_host="${custom_host:-gitlab.com}"
                api_host="${custom_host:-gitlab.com}"
                netrc_login="oauth2"
                ;;
        bitbucket)
                git_host="${custom_host:-bitbucket.org}"
                api_host="${custom_host:-api.bitbucket.org}"
                netrc_login="x-token-auth"
                ;;
        *)
                status "Error: Unsupported Git provider '${provider}' for transient .netrc generation."
                exit 1
                ;;
esac

# Create isolated temp directory and pre-create .netrc with strict 0600 permissions
netrc_dir="$(/usr/bin/mktemp -d /tmp/adt-netrc.XXXXXX)"

if ! /usr/bin/install -m 600 /dev/null "${netrc_dir}/.netrc"
then
        /bin/rm -rf "${netrc_dir}"
        status "Error: Failed to initialise 0600 .netrc file inside ${netrc_dir}."
        exit 1
fi

# Write primary Git host entry
{
        /bin/echo "machine ${git_host}"
        /bin/echo "login ${netrc_login}"
        /bin/echo "password ${token}"
} > "${netrc_dir}/.netrc"

# Append separate API host entry when the provider uses a distinct API subdomain
if [ "${api_host}" != "${git_host}" ]
then
        {
                /bin/echo ""
                /bin/echo "machine ${api_host}"
                /bin/echo "login ${netrc_login}"
                /bin/echo "password ${token}"
        } >> "${netrc_dir}/.netrc"
fi

# Emit the temporary directory path to stdout for the calling script
/bin/echo "${netrc_dir}"
exit 0

