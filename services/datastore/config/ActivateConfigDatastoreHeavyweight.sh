#!/bin/sh
#: Name:        ActivateConfigDatastoreHeavyweight.sh
#: Purpose:     Bootstraps /var/lib/adt-config from S3 if missing and runs periodic heavyweight config sync schedules.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       ActivateConfigDatastoreHeavyweight.sh
#:              ActivateConfigDatastoreHeavyweight.sh [-h|--help]
#:
#: Parameters:
#:   None       Syncs "/var/lib/adt-config" across schedules "2 15 30 45" via FileSystemsSyncingController.sh.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/services/datastore/operations/SyncFromDatastore.sh
#:   - ${HOME}/services/datastore/operations/ListFromDatastore.sh
#:   - ${HOME}/services/datastore/filesystems-sync/heavyweight/FileSystemsSyncingController.sh
#:   - External binaries: cat, echo, grep, cut, mkdir, sleep, kill, rm
#:
#: Exit Codes:
#:   0          Daemon exited cleanly or skipped because another instance is already active
#:   1          Missing /home/homedir.dat or missing datastore/sync controller scripts
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

# Resolve the server toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
        export HOME
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

runtime_dir="${HOME}/runtime"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

pidfile="${runtime_dir}/config_heavyweight_sync.pid"
lock_acquired="0"

cleanup()
{
        exit_code="$?"
        if [ "${lock_acquired}" = "1" ]
        then
                /bin/rm -f "${pidfile}"
        fi
        exit "${exit_code}"
}
trap cleanup EXIT HUP INT QUIT ABRT ALRM TERM

# Prevent overlapping cron invocations from spawning duplicate infinite loops
if [ -f "${pidfile}" ]
then
        existing_pid="$(/bin/cat "${pidfile}" 2>/dev/null || true)"
        if [ -n "${existing_pid}" ] && /bin/kill -0 "${existing_pid}" 2>/dev/null
        then
                exit 0
        fi
        /bin/rm -f "${pidfile}"
fi

if ( set -C; printf '%s\n' "$$" > "${pidfile}" ) 2>/dev/null
then
        lock_acquired="1"
else
        exit 0
fi

sync_from="${HOME}/services/datastore/operations/SyncFromDatastore.sh"
list_from="${HOME}/services/datastore/operations/ListFromDatastore.sh"
sync_controller="${HOME}/services/datastore/filesystems-sync/heavyweight/FileSystemsSyncingController.sh"

if [ ! -x "${sync_from}" ] || [ ! -x "${list_from}" ] || [ ! -x "${sync_controller}" ]
then
        /bin/echo "Error: Required datastore sync scripts missing or not executable under ${HOME}/services/datastore/" >&2
        exit 1
fi

config_dir="/var/lib/adt-config"

if [ ! -d "${config_dir}" ]
then
        /bin/mkdir -p "${config_dir}"
        set +e
        "${sync_from}" "config" "${config_dir}"

        while [ -z "$("${list_from}" "config" "INSTALLED_SUCCESSFULLY" 2>/dev/null)" ]
        do
                /bin/sleep 1
        done

        "${sync_from}" "config" "${config_dir}"
        set -e
fi

schedules="2 15 30 45"
while true
do
        for schedule in ${schedules}
        do
                /bin/sleep 15
                set +e
                "${sync_controller}" "${schedule}" "${config_dir}" "config-sync"
                set -e
        done
done
 
