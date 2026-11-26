#!/bin/sh
#: Name:        AllowAuthenticatorIP.sh
#: Purpose:     Syncs authenticator-approved client IPs from S3 and adds them to the allowed-laptop-ips ipset.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       AllowAuthenticatorIP.sh
#:              AllowAuthenticatorIP.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads ACTIVEFIREWALLS, FIREWALL, and BUILDOS from configuration and syncs firewall-auth-laptop-ips.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#:   - ${HOME}/installation/InstallIPSet.sh
#:   - ${HOME}/services/datastore/operations/SyncFromDatastore.sh
#:   - /usr/sbin/ipset
#:   - /usr/sbin/iptables
#:   - External binaries: cat, echo, printf, grep, cut, awk, mkdir, rm, touch
#:
#: Exit Codes:
#:   0          Authenticator IP allowlist synced and applied cleanly
#:   1          Missing /home/homedir.dat, missing required tools/configs, or sync/ipset failure
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

config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"
config_checker="${HOME}/utilities/config/CheckConfigValue.sh"
style_extractor="${HOME}/utilities/config/ExtractBuildStyleValues.sh"

if [ "$("${config_checker}" 'ACTIVEFIREWALLS:1')" = "0" ] && [ "$("${config_checker}" 'ACTIVEFIREWALLS:3')" = "0" ]
then
        exit 0
fi

set +e
BUILDOS="$("${config_extractor}" 'BUILDOS')"
firewall="$("${style_extractor}" "FIREWALL" | /usr/bin/awk -F':' '{print $2}')"
set -e

if [ "${firewall}" != "ufw" ] && [ "${firewall}" != "iptables" ]
then
        exit 0
fi

# Ensure ipset and the allowed-laptop-ips set & INPUT rule exist
if ! /usr/sbin/ipset list -n allowed-laptop-ips >/dev/null 2>&1
then
        if [ ! -x /usr/sbin/ipset ]
        then
                "${HOME}/installation/InstallIPSet.sh" "${BUILDOS}"
        fi
        /usr/sbin/ipset create allowed-laptop-ips hash:ip maxelem 16777216 -exist
fi

if ! /usr/sbin/iptables -C INPUT -m set --match-set allowed-laptop-ips src -p tcp --dport 443 -j ACCEPT >/dev/null 2>&1
then
        /usr/sbin/iptables -I INPUT -m set --match-set allowed-laptop-ips src -p tcp --dport 443 -j ACCEPT
fi

auth_dir="${HOME}/runtime/authenticator"
if [ ! -d "${auth_dir}" ]
then
        /bin/mkdir -p "${auth_dir}"
fi

prev_file="${auth_dir}/previous_ipaddresses.dat"
incoming_file="${auth_dir}/incoming_ipaddresses.dat"

if [ ! -f "${prev_file}" ]
then
        /usr/bin/touch "${prev_file}"
fi

"${HOME}/services/datastore/operations/SyncFromDatastore.sh" "firewall-auth-laptop-ips" "${auth_dir}"

: > "${incoming_file}"
for f in "${auth_dir}/firewall-laptop-ips"/ipaddresses.dat*
do
        [ -f "${f}" ] && /bin/cat "${f}" >> "${incoming_file}"
done

updated="0"
while IFS= read -r ip_address
do
        [ -z "${ip_address}" ] && continue

        # Strip optional /32 suffix for validation and deduplication
        clean_ip="${ip_address%/32}"
        if ! printf '%s\n' "${clean_ip}" | /usr/bin/grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        then
                /bin/echo "Warning: Skipping invalid IPv4 entry '${ip_address}' in authenticator allowlist." >&2
                continue
        fi

        if ! /bin/grep -Fqx "${clean_ip}" "${prev_file}"
        then
                /usr/sbin/ipset add allowed-laptop-ips "${clean_ip}" -exist
                /bin/echo "${clean_ip}" >> "${prev_file}"
                updated="1"
        fi
done < "${incoming_file}"

if [ "${firewall}" = "ufw" ] && [ "${updated}" = "1" ] && [ -x /usr/sbin/ufw ]
then
        /usr/sbin/ufw reload >/dev/null 2>&1 || true
fi

/bin/rm -f "${auth_dir}/ipaddresses.dat" "${incoming_file}"

exit 0
