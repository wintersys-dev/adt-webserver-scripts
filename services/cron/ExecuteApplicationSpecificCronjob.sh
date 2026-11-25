#!/bin/sh
#: Name:        ExecuteApplicationSpecificCronjob.sh
#: Purpose:     Configures and installs application-specific crontab entries for the www-data user.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       ExecuteApplicationSpecificCronjob.sh
#:              ExecuteApplicationSpecificCronjob.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads active APPLICATION flags via CheckConfigValue.sh.
#:
#: Environment:
#:   HOME       Root directory of the server deployment toolkit
#:
#: Dependencies:
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - External binaries: echo, grep, cut, rm, mktemp, crontab
#:
#: Exit Codes:
#:   0          Application crontab entries installed cleanly, or no entries required
#:   1          Missing HOME environment, missing CheckConfigValue.sh, or crontab installation failure
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
# along with The Wintersys Agile Deployment Toolkit.  If not, see <http://gnu.org>.
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

# Verify that HOME is set in the execution environment
if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: HOME environment variable is unset or invalid." >&2
        exit 1
fi

# Verify required configuration checker helper exists
config_checker="${HOME}/utilities/config/CheckConfigValue.sh"
if [ ! -x "${config_checker}" ]
then
        /bin/echo "Error: Configuration checker script missing or not executable at ${config_checker}" >&2
        exit 1
fi

# Stage www-data crontab entries in a temporary file before installing via crontab(1)
tmp_cron="$(/bin/mktemp)"
cleanup()
{
        /bin/rm -f "${tmp_cron}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Preserve any pre-existing www-data crontab entries outside managed toolkit lines
/usr/bin/crontab -u www-data -l 2>/dev/null | /usr/bin/grep -v -F "wp cron event run" | /usr/bin/grep -v -F "/var/www/html/admin/cli/cron.php" > "${tmp_cron}" || true

# WordPress scheduled event runner
if [ "$("${config_checker}" "APPLICATION:wordpress")" = "1" ]
then
        /bin/echo "*/30 * * * * /usr/local/bin/wp cron event run --due-now --path='/var/www/html' >/dev/null 2>&1" >> "${tmp_cron}"
fi

# Moodle background maintenance cron
if [ "$("${config_checker}" "APPLICATION:moodle")" = "1" ]
then
        /bin/echo "*/1 * * * * /usr/bin/php /var/www/html/admin/cli/cron.php >/dev/null 2>&1" >> "${tmp_cron}"
fi

# Install the staged crontab for www-data so cron(8) reloads it immediately
if [ -s "${tmp_cron}" ]
then
        if ! /usr/bin/crontab -u www-data "${tmp_cron}"
        then
                /bin/echo "Error: Failed to install www-data crontab from staging file." >&2
                exit 1
        fi
fi

exit 0


