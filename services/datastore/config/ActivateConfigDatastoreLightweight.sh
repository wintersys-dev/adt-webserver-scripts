#!/bin/sh
#: Name:        ActivateConfigDatastoreLightweight.sh
#: Purpose:     Cron-invoked wrapper that initiates lightweight filesystem syncing for /var/lib/adt-config.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       ActivateConfigDatastoreLightweight.sh
#:              ActivateConfigDatastoreLightweight.sh [-h|--help]
#:
#: Parameters:
#:   None       Invokes FileSystemSyncController.sh against "/var/lib/adt-config" in "config" mode.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - /var/lib/adt-config
#:   - ${HOME}/services/datastore/filesystems-sync/lightweight/FileSystemSyncController.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Lightweight config filesystem sync controller dispatched cleanly
#:   1          Missing /home/homedir.dat, missing /var/lib/adt-config, or missing sync controller
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

config_dir="/var/lib/adt-config"
if [ ! -d "${config_dir}" ]
then
        /bin/echo "Error: Configuration directory missing at ${config_dir}" >&2
        exit 1
fi

sync_controller="${HOME}/services/datastore/filesystems-sync/lightweight/FileSystemSyncController.sh"
if [ ! -x "${sync_controller}" ]
then
        /bin/echo "Error: FileSystemSyncController.sh missing or not executable at ${sync_controller}" >&2
        exit 1
fi

"${sync_controller}" "${config_dir}" "config" &

exit 0
