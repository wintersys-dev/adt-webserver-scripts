#!/bin/sh
#: Name:        Backup.sh
#: Purpose:     Synchronizes the active webroot, strips excluded paths, archives it, and uploads to the datastore.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       Backup.sh "<periodicity>" ["build-machine"]
#:              Backup.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Backup periodicity (hourly, daily, weekly, monthly, bimonthly, shutdown, manual)
#:   $2         [Optional] Pass "build-machine" to bypass the 300-second duplicate backup cooldown buffer
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/runtime/WEBSERVER_READY
#:   - ${HOME}/runtime/application.dat
#:   - ${HOME}/utilities/processing/GetIP.sh
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - ${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh
#:   - ${HOME}/services/datastore/operations/MountDatastore.sh
#:   - ${HOME}/services/datastore/operations/ListFromDatastore.sh
#:   - ${HOME}/services/datastore/operations/GetFromDatastore.sh
#:   - ${HOME}/services/datastore/operations/PutToDatastore.sh
#:   - ${HOME}/services/datastore/operations/MoveDatastoreObject.sh
#:   - ${HOME}/application/backup/VerifyBackupPresent.sh
#:   - ${HOME}/services/datastore/filesystems-sync/heavyweight/DeleteHistoricalAdditions.sh
#:   - External binaries: cat, echo, grep, cut, sed, awk, tr, date, mkdir, rm, touch, rsync, tar, systemd-inhibit
#:
#: Exit Codes:
#:   0          Webroot backup completed and verified (or skipped safely due to cooldown/readiness state)
#:   1          Missing arguments, invalid periodicity, or archive generation failure
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
        export HOME
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Validate required periodicity argument before redirecting output
if [ -z "${1}" ]
then
        /bin/echo "Error: This script needs to be run with the <build periodicity> parameter." >&2
        /bin/echo "Usage: $0 <hourly|daily|weekly|monthly|bimonthly|shutdown|manual> [build-machine]" >&2
        exit 1
fi

# Abort silently if installation is incomplete or the webserver is not yet ready
if [ -z "$("${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh" "config" "INSTALLED_SUCCESSFULLY")" ]
then
        exit 0
fi

if [ ! -f "${HOME}/runtime/WEBSERVER_READY" ]
then
        exit 0
fi

machine_ip="$("${HOME}/utilities/processing/GetIP.sh")"

# Initialize backup log directory and redirect stdout/stderr to timestamped log files
log_dir="${HOME}/logs/backup"
if [ ! -d "${log_dir}" ]
then
        /bin/mkdir -p "${log_dir}"
fi

timestamp="$(/bin/date +%Y%m%d%H%M%S)"
log_file="backup_out_${timestamp}"
err_file="backup_err_${timestamp}"

/bin/echo "Log file is at: ${log_dir}/${log_file} on machine with ip address ${machine_ip}"
/bin/echo "Error file is at: ${log_dir}/${err_file} on machine with ip address ${machine_ip}"

exec 1>>"${log_dir}/${log_file}"
exec 2>>"${log_dir}/${err_file}"
# Extract website and multi-region configuration values
WEBSITE_URL="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'WEBSITEURL')"
WEBSITE_NAME="$(/bin/echo "${WEBSITE_URL}" | /usr/bin/awk -F'.' '{print $2}')"
WEBSITE_SUBDOMAIN="$(/bin/echo "${WEBSITE_URL}" | /usr/bin/awk -F'.' '{print $1}')"
ROOT_DOMAIN="$(/bin/echo "${WEBSITE_URL}" | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed -e 's/^ //g' -e 's/ /./g')"

WEBSITE_DISPLAY_NAME="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'WEBSITEDISPLAYNAME' | /bin/sed 's/_/ /g')"
WEBSITE_DISPLAY_NAME_UPPER="$(/bin/echo "${WEBSITE_DISPLAY_NAME}" | /usr/bin/tr '[:lower:]' '[:upper:]')"
WEBSITE_DISPLAY_NAME_LOWER="$(/bin/echo "${WEBSITE_DISPLAY_NAME}" | /usr/bin/tr '[:upper:]' '[:lower:]')"

CLOUDHOST="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'CLOUDHOST')"
MULTI_REGION="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'MULTIREGION')"
PRIMARY_REGION="$("${HOME}/utilities/config/ExtractConfigValue.sh" 'PRIMARYREGION')"

provider_id=""
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ]
then
        provider_id="-${CLOUDHOST}"
fi

# Normalize and validate backup periodicity
period="$(/bin/echo "${1}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
build_machine="${2}"

case "${period}" in
        hourly|daily|weekly|monthly|bimonthly|shutdown|manual)
                ;;
        *)
                /bin/echo "Error: Invalid periodicity (${period}) passed to backup script." >&2
                exit 1
                ;;
esac

bucket_suffix="${period}${provider_id}"
datastore_ops="${HOME}/services/datastore/operations"

# Mount target webroot backup datastore and check duplicate-backup cooldown timestamp
"${datastore_ops}/MountDatastore.sh" "backup-webroot" "distributed" "${bucket_suffix}"

workarea_dir="${HOME}/runtime/datastore_workarea"
if [ ! -d "${workarea_dir}" ]
then
        /bin/mkdir -p "${workarea_dir}"
fi

marker_file="${workarea_dir}/time_backup_written"
/bin/rm -f "${marker_file}"

if [ -n "$("${datastore_ops}/ListFromDatastore.sh" "backup-webroot" "time_backup_written" "${bucket_suffix}")" ]
then
        "${datastore_ops}/GetFromDatastore.sh" "backup-webroot" "time_backup_written" "${workarea_dir}" "${bucket_suffix}"
fi

if [ -f "${marker_file}" ]
then
        current_time="$(/usr/bin/date +%s)"
        backup_time="$(/bin/cat "${marker_file}")"

        time_buffer="300"
        if [ "${build_machine}" = "build-machine" ]
        then
                time_buffer="0"
        fi

        elapsed="$((current_time - backup_time))"
        if [ "${elapsed}" -lt "${time_buffer}" ]
        then
                exit 0
        fi
fi

# Record updated backup timestamp marker in the webroot backup datastore
/usr/bin/date +%s > "${marker_file}"
"${datastore_ops}/PutToDatastore.sh" "backup-webroot" "${marker_file}" "root" "distributed" "no" "${bucket_suffix}"

# Prepare clean local staging workspace and synchronize active webroot
backup_dir="${HOME}/backuparea"
if [ -d "${backup_dir}" ]
then
        /bin/rm -rf "${backup_dir}"
fi

/bin/mkdir -p "${backup_dir}"
cd "${backup_dir}"

/usr/bin/rsync -av /var/www/html/ "${backup_dir}/"
# Remove configured paths excluded from backup in runtime/application.dat
app_dat="${HOME}/runtime/application.dat"
if [ -r "${app_dat}" ]
then
        sub_directory="$(/usr/bin/grep '^WEBROOT_DIRECTORY:' "${app_dat}" | /bin/sed -e 's/^WEBROOT_DIRECTORY://g' -e 's;^/var/www/html/;;' -e 's;^/var/www/html$;;' || true)"
        exclude_list="$(/usr/bin/grep '^EXCLUDE_FROM_BACKUP:' "${app_dat}" | /bin/sed -e 's/^EXCLUDE_FROM_BACKUP://g' -e 's/:/ /g' || true)"

        if [ -n "${exclude_list}" ]
        then
                for excluded in ${exclude_list}
                do
                        if [ -n "${sub_directory}" ]
                        then
                                target_exclude="${backup_dir}/${sub_directory}/${excluded}"
                        else
                                target_exclude="${backup_dir}/${excluded}"
                        fi

                        if [ -e "${target_exclude}" ] || [ -L "${target_exclude}" ]
                        then
                                /bin/rm -rf "${target_exclude}"
                        fi
                done
        fi
fi

# Add integrity verification marker file to staged webroot
/bin/touch "${backup_dir}/XXXXXX-DO_NOT_REMOVE"

# Create compressed tarball of the entire staged webroot (including dotfiles)
livebackup_dir="${HOME}/livebackup"
if [ ! -d "${livebackup_dir}" ]
then
        /bin/mkdir -p "${livebackup_dir}"
else
        /bin/rm -rf "${livebackup_dir:?}/"*
fi

backup_file="applicationsourcecode.tar.gz"
archive_path="${livebackup_dir}/${backup_file}"

/usr/bin/tar -czf "${archive_path}" -C "${backup_dir}" .

if [ ! -f "${archive_path}" ]
then
        /bin/echo "Error: Backup file ${archive_path} was not successfully generated." >&2
        exit 1
fi

# Rotate any existing backup archive in the datastore and upload the new archive
if [ -n "$("${datastore_ops}/ListFromDatastore.sh" "backup-webroot" "${backup_file}" "${bucket_suffix}")" ]
then
        archive_target="${backup_file}.ARCHIVE.$(/usr/bin/date +%F-%Hhr)"
        "${datastore_ops}/MoveDatastoreObject.sh" "backup-webroot" "${backup_file}" "${archive_target}" "distributed" "${bucket_suffix}"
fi

/bin/systemd-inhibit --why="Persisting sourcecode to datastore" "${datastore_ops}/PutToDatastore.sh" "backup-webroot" "${archive_path}" "root" "distributed" "no" "${bucket_suffix}"
/bin/rm -rf "${livebackup_dir}"

# Verify backup presence in datastore and clean up staging area
"${HOME}/application/backup/VerifyBackupPresent.sh" "${period}"

cd "${HOME}"
if [ -d "${backup_dir}" ]
then
        /bin/rm -rf "${backup_dir}"
fi

if [ "$("${HOME}/utilities/config/CheckConfigValue.sh" SYNCWEBROOTS:1)" = "1" ]
then
        "${HOME}/services/datastore/filesystems-sync/heavyweight/DeleteHistoricalAdditions.sh" "/var/www/html"
fi

exit 0
