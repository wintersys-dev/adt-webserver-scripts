#!/bin/sh
#: Name:        AllowAuthenticatorIPAddress.sh
#: Purpose:     Syncs authenticator-approved client IPs from S3, updates the webserver IP whitelist, and reloads the webserver.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       AllowAuthenticatorIPAddress.sh
#:              AllowAuthenticatorIPAddress.sh [-h|--help]
#:
#: Parameters:
#:   None       Checks ACTIVEFIREWALLS from configuration and syncs the "whitelist-auth-laptop-ips" datastore namespace.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - ${HOME}/services/datastore/operations/SyncFromDatastore.sh
#:   - ${HOME}/webserver/configuration/reverseproxy/whitelist/AllowIPAddress.sh
#:   - ${HOME}/webserver/ReloadWebserver.sh
#:   - External binaries: cat, echo, printf, grep, cut, mkdir, rm, touch
#:
#: Exit Codes:
#:   0          Webserver IP whitelist synced and reloaded cleanly (or skipped when inactive)
#:   1          Missing /home/homedir.dat, missing helper scripts, or sync/reload failure
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

if [ "$("${config_checker}" 'ACTIVEFIREWALLS:1')" = "0" ] && [ "$("${config_checker}" 'ACTIVEFIREWALLS:3')" = "0" ]
then
        exit 0
fi

allow_ip_script="${HOME}/webserver/configuration/reverseproxy/whitelist/AllowIPAddress.sh"
reload_webserver="${HOME}/webserver/ReloadWebserver.sh"

if [ ! -x "${allow_ip_script}" ] || [ ! -x "${reload_webserver}" ]
then
        /bin/echo "Error: Required webserver whitelist or reload scripts missing under ${HOME}/webserver/" >&2
        exit 1
fi

auth_dir="${HOME}/runtime/authenticator"
if [ ! -d "${auth_dir}" ]
then
        /bin/mkdir -p "${auth_dir}"
fi

incoming_file="${auth_dir}/incoming_ipaddresses-$$.dat"
processed_file="${auth_dir}/processed_ipaddresses.dat"
whitelist_file="${auth_dir}/webserver_ip_whitelist.dat"

cleanup_temp()
{
        /bin/rm -f "${incoming_file}" "${auth_dir}/incoming_ipaddresses.dat"
}
trap cleanup_temp EXIT INT TERM

"${HOME}/services/datastore/operations/SyncFromDatastore.sh" "whitelist-auth-laptop-ips" "${auth_dir}"

: > "${incoming_file}"
for f in "${auth_dir}/whitelist-laptop-ips"/ipaddresses.dat*
do
        [ -f "${f}" ] && /bin/cat "${f}" >> "${incoming_file}"
done

updated="0"
while IFS= read -r ip_address
do
        [ -z "${ip_address}" ] && continue

        clean_ip="${ip_address%/32}"
        if ! printf '%s\n' "${clean_ip}" | /usr/bin/grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        then
                /bin/echo "Warning: Skipping invalid IPv4 entry '${ip_address}' in webserver whitelist." >&2
                continue
        fi

        if [ -f "${processed_file}" ] && /bin/grep -Fqx "${clean_ip}" "${processed_file}"
        then
                continue
        fi

        if [ -f "${whitelist_file}" ] && /bin/grep -Fqx "${clean_ip}" "${whitelist_file}"
        then
                continue
        fi

        "${allow_ip_script}" "${clean_ip}"
        /bin/echo "${clean_ip}" >> "${processed_file}"
        updated="1"
done < "${incoming_file}"

if [ "${updated}" = "1" ]
then
        "${reload_webserver}"
fi

exit 0

