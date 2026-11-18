#!/bin/sh
#: Name:        create_repository.sh
#: Purpose:     Creates a new Bitbucket repository when orchestration is set to CLI mode
#:              by delegating cleanly to the Bitbucket REST API create_repository.sh wrapper
#:              (as Bitbucket Cloud lacks an official repository-creation CLI).
#: Author:      Peter Winter
#: Date:        18/11/2026
#: Version:     1.0
#:
#: Usage:       create_repository.sh <workspace> <repo_slug> <json_payload>
#:              create_repository.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target Bitbucket workspace slug (e.g. "wintersys").
#:   $2         [Required] Lowercase repository slug (e.g. "my-website-repo").
#:   $3         [Required] The JSON payload defining the repository attributes.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - ${BUILD_HOME}/services/git/bitbucket/api/create_repository.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Bitbucket repository created cleanly
#:   *          Missing arguments, missing API delegate script, or API error code
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

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

api_script="${BUILD_HOME}/services/git/bitbucket/api/create_repository.sh"

if [ ! -x "${api_script}" ]
then
        status "Error: Bitbucket API delegate script missing or not executable at ${api_script}."
        exit 1
fi

status "Bitbucket Cloud has no native CLI for repository creation; delegating to REST API wrapper..."

exec "${api_script}" "$@"
