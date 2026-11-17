#!/bin/sh
#: Name:        VerifyBackupPresent.sh
#: Purpose:     Downloads the webroot backup archive from the datastore, extracts it, and verifies the integrity marker.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       VerifyBackupPresent.sh "<periodicity>"
#:              VerifyBackupPresent.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Backup periodicity (hourly, daily, weekly, monthly, bimonthly, shutdown, manual)
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/datastore/operations/GetFromDatastore.sh
#:   - ${HOME}/services/email/SendEmail.sh
#:   - External binaries: cat, echo, grep, cut, awk, mkdir, rm, tar
#:
#: Exit Codes:
#:   0          Webroot backup archive retrieved and verified as consistent
#:   1          Missing arguments, missing config, extraction failure, or missing integrity marker
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
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the server tracking file
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Validate required periodicity argument
if [ -z "${1}" ]
then
        /bin/echo "Error: Backup periodicity parameter is required." >&2
        /bin/echo "Usage: $0 <hourly|daily|weekly|monthly|bimonthly|shutdown|manual>" >&2
        exit 1
fi

period="${1}"

# Extract website, build, and multi-region configuration values
WEBSITE_URL="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'WEBSITEURL')"
WEBSITE_SUBDOMAIN="$(/bin/echo "${WEBSITE_URL}" | /usr/bin/awk -F'.' '{print $1}')"
WEBSITE_NAME="$(/bin/echo "${WEBSITE_URL}" | /usr/bin/awk -F'.' '{print $2}')"
BUILD_ARCHIVE_CHOICE="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'BUILDARCHIVECHOICE')"
BUILD_IDENTIFIER="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'BUILDIDENTIFIER')"
CLOUDHOST="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'CLOUDHOST')"
MULTI_REGION="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'MULTIREGION')"
PRIMARY_REGION="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'PRIMARYREGION')"

provider_id=""
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ]
then
        provider_id="-${CLOUDHOST}"
fi

bucket_suffix="${period}${provider_id}"
APPLICATION_REPOSITORY_NAME="${WEBSITE_SUBDOMAIN}-${WEBSITE_NAME}-webroot-sourcecode-${period}-${BUILD_IDENTIFIER}"

# Prepare clean verification workspace and guarantee cleanup on exit
verify_dir="${HOME}/backupverification"
trap 'cd "${HOME}" && /bin/rm -rf "${verify_dir}"' EXIT

if [ -d "${verify_dir}" ]
then
        /bin/rm -rf "${verify_dir}"
fi
/bin/mkdir -p "${verify_dir}"

cd "${verify_dir}"

# Retrieve and extract backup archive from datastore
backup_file="applicationsourcecode.tar.gz"
archive_path="${verify_dir}/${backup_file}"

set +e
"${HOME}/services/datastore/operations/GetFromDatastore.sh" "backup-webroot" "${backup_file}" "." "${bucket_suffix}"
get_status="$?"
set -e

if [ "${get_status}" -eq 0 ] && [ -f "${archive_path}" ]
then
        set +e
        /bin/tar -xzf "${archive_path}" -C "${verify_dir}"
        tar_status="$?"
        set -e
else
        tar_status="1"
fi

# Verify integrity marker presence and dispatch notification
if [ "${tar_status}" -ne 0 ] || [ ! -f "${verify_dir}/XXXXXX-DO_NOT_REMOVE" ]
then
        /bin/echo "Backup not verified as consistent" >&2
        "${HOME}/services/email/SendEmail.sh" "Potential missing webroot backup for periodicity ${period} (${BUILD_ARCHIVE_CHOICE}) in your datastore" "A backup that I expected (${APPLICATION_REPOSITORY_NAME}) seems to be missing or corrupt in the datastore." "ERROR"
        exit 1
else
        /bin/echo "Backup verified as consistent"
        "${HOME}/services/email/SendEmail.sh" "Backup has been made to your datastore" "A backup (${APPLICATION_REPOSITORY_NAME}) has been successfully written and verified in your datastore." "INFO"
fi

exit 0
