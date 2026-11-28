#!/bin/sh
#: Name:        BackupFromCron.sh
#: Purpose:     Cron-triggered distributed leader election and webroot backup orchestrator across webservers.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       BackupFromCron.sh <periodicity>
#:              BackupFromCron.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Backup periodicity tier (e.g. "hourly", "daily", "weekly", "monthly")
#:
#: Environment:
#:   HOME       Root directory of the server deployment toolkit
#:
#: Dependencies:
#:   - ${HOME}/services/datastore/operations/GetFromDatastore.sh
#:   - ${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh
#:   - ${HOME}/services/datastore/config/wrapper/PutToDatastore.sh
#:   - ${HOME}/services/datastore/config/wrapper/DeleteFromDatastore.sh
#:   - ${HOME}/application/backup/Backup.sh
#:   - External binaries: hostname, cat, echo, grep, cut, mkdir, rm, date, shuf, sleep
#:
#: Exit Codes:
#:   0          Backup completed cleanly, or skipped (non-webserver / recent backup exists / peer authoritative)
#:   1          Missing HOME environment, missing periodicity argument, or backup execution failure
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

# Restrict execution strictly to webserver nodes (ws-*)
case "$(/usr/bin/hostname)" in
        ws-*)
                ;;
        *)
                exit 0
                ;;
esac

# Verify that HOME is set in the cron execution environment
if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: HOME environment variable is unset or invalid." >&2
        exit 1
fi

# Validate that the required backup periodicity argument was provided
if [ -z "${1}" ]
then
        /bin/echo "Error: Backup periodicity argument is required." >&2
        /bin/echo "Usage: $0 <periodicity>" >&2
        exit 1
fi

periodicity="${1}"

# Ensure local datastore staging workarea exists and remove any stale timestamp artifact
workarea="${HOME}/runtime/datastore_workarea"
timestamp_file="${workarea}/time_backup_written"

if [ ! -d "${workarea}" ]
then
        /bin/mkdir -p "${workarea}"
fi

/bin/rm -f "${timestamp_file}"

list_script="${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh"
get_script="${HOME}/services/datastore/operations/GetFromDatastore.sh"

if [ ! -x "${list_script}" ]
then
        /bin/echo "Error: Datastore list script missing or not executable at ${list_script}" >&2
        exit 1
fi

if [ ! -x "${get_script}" ]
then
        /bin/echo "Error: Datastore get script missing or not executable at ${get_script}" >&2
        exit 1
fi

running_flag="$("${list_script}" "backup-webroot" "time_backup_written")"

if [ -n "${running_flag}" ]
then
        # Fetch the last backup timestamp from the shared datastore (tolerate non-zero if no prior backup exists)
        set +e
        "${get_script}" "backup-webroot" "time_backup_written" "${workarea}" "${periodicity}"
        set -e
fi


# Skip backup cycle if another node wrote a valid timestamp within the last 300 seconds
if [ -r "${timestamp_file}" ]
then
        current_time="$(/usr/bin/date +%s)"
        backup_time="$(/bin/cat "${timestamp_file}")"

        case "${backup_time}" in
                ''|*[!0-9]*)
                        /bin/echo "Warning: Invalid backup timestamp content in ${timestamp_file}; ignoring." >&2
                        ;;
                *)
                        elapsed=$((current_time - backup_time))
                        if [ "${elapsed}" -lt 300 ]
                        then
                                exit 0
                        fi
                        ;;
        esac
fi

# Jitter startup across fleet nodes to stagger leader election
jitter="$(/usr/bin/shuf -i1-300 -n1)"
/bin/sleep "${jitter}"

# Check shared datastore lock to determine if a peer node has already claimed leadership
put_script="${HOME}/services/datastore/config/wrapper/PutToDatastore.sh"
delete_script="${HOME}/services/datastore/config/wrapper/DeleteFromDatastore.sh"

if [ ! -x "${put_script}" ] || [ ! -x "${delete_script}" ]
then
        /bin/echo "Error: One or more datastore config wrapper scripts are missing or not executable." >&2
        exit 1
fi

running_flag="$("${list_script}" "config" "BACKUP_RUNNING")"
if [ -n "${running_flag}" ]
then
        exit 0
fi

# Claim distributed backup leadership and guarantee lock cleanup on exit or failure
"${put_script}" "config" "BACKUP_RUNNING" "root" "distributed" "no"

cleanup()
{
        "${delete_script}" "config" "BACKUP_RUNNING" "distributed" >/dev/null 2>&1 || true
        /bin/rm -f "${timestamp_file}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Verify and execute the webroot backup workflow
backup_script="${HOME}/application/backup/Backup.sh"
if [ ! -x "${backup_script}" ]
then
        /bin/echo "Error: Backup script missing or not executable at ${backup_script}" >&2
        exit 1
fi

set +e
"${backup_script}" "${periodicity}"
backup_exit_code="$?"
set -e

if [ "${backup_exit_code}" -ne 0 ]
then
        /bin/echo "Error: Backup.sh failed with exit code ${backup_exit_code}." >&2
        exit 1
fi

# Hold distributed lock for 300 seconds after completion so straggling peer nodes still see it
/bin/sleep 300

exit 0



