#!/bin/sh
#: Name:        ObtainBasicAuthCredentials.sh
#: Purpose:     Syncs HTTP Basic Auth credential entries from S3 and updates the active webserver .htpasswd file.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       ObtainBasicAuthCredentials.sh
#:              ObtainBasicAuthCredentials.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads WEBSERVERCHOICE from configuration and syncs the "basic-auth-credentials" datastore bucket.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - ${HOME}/services/datastore/operations/SyncFromDatastore.sh
#:   - External binaries: cat, echo, printf, grep, cut, sed, mkdir, rm, touch, chmod, chown
#:
#: Exit Codes:
#:   0          Basic authentication credentials synced and applied cleanly
#:   1          Missing /home/homedir.dat, unsupported webserver choice, or sync/file failure
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

config_checker="${HOME}/utilities/config/CheckConfigValue.sh"
if [ ! -x "${config_checker}" ]
then
        /bin/echo "Error: CheckConfigValue.sh missing or not executable at ${config_checker}" >&2
        exit 1
fi

basic_auth_file=""
if [ "$("${config_checker}" 'WEBSERVERCHOICE:APACHE')" = "1" ]
then
        basic_auth_file="/etc/apache2/.htpasswd"
elif [ "$("${config_checker}" 'WEBSERVERCHOICE:NGINX')" = "1" ]
then
        basic_auth_file="/etc/nginx/.htpasswd"
elif [ "$("${config_checker}" 'WEBSERVERCHOICE:LIGHTTPD')" = "1" ]
then
        basic_auth_file="/etc/lighttpd/.htpasswd"
fi

if [ -z "${basic_auth_file}" ]
then
        /bin/echo "Error: Unable to determine target .htpasswd path from WEBSERVERCHOICE." >&2
        exit 1
fi

auth_dir="${HOME}/runtime/authenticator"
if [ ! -d "${auth_dir}" ]
then
        /bin/mkdir -p "${auth_dir}"
fi

aggregate_file="${auth_dir}/aggregate-basic-auth-$$.dat"
cleanup_temp()
{
        /bin/rm -f "${aggregate_file}"
}
trap cleanup_temp EXIT INT TERM

"${HOME}/services/datastore/operations/SyncFromDatastore.sh" "basic-auth-credentials" "${auth_dir}"

(
        umask 077
        : > "${aggregate_file}"
        for cred_file in "${auth_dir}/basic-auth-credentials"/basic-auth*
        do
                if [ -f "${cred_file}" ]
                then
                        /bin/cat "${cred_file}" >> "${aggregate_file}"
                        /bin/rm -f "${cred_file}"
                fi
        done
)

if [ ! -f "${basic_auth_file}" ]
then
        (
                umask 077
                /usr/bin/touch "${basic_auth_file}"
        )
fi

while IFS= read -r raw_line
do
        [ -z "${raw_line}" ] && continue

        clean_cred="${raw_line#NEW:}"
        username="${clean_cred%%:*}"

        if [ -z "${username}" ] || [ "${username}" = "${clean_cred}" ]
        then
                /bin/echo "Warning: Skipping malformed basic-auth entry." >&2
                continue
        fi

        # Escape regex metacharacters in username and match exact "username:" prefix
        escaped_user="$(printf '%s' "${username}" | /bin/sed -e 's/[\\.*^$[\]|]/\\&/g')"
        /bin/sed -i "/^${escaped_user}:/d" "${basic_auth_file}"
        printf '%s\n' "${clean_cred}" >> "${basic_auth_file}"
done < "${aggregate_file}"

/bin/chmod 600 "${basic_auth_file}"
/bin/chown www-data:www-data "${basic_auth_file}"

exit 0


