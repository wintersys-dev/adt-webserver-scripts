#!/bin/sh
#: Name:        TrustRemoteProxy.sh
#: Purpose:     Fetches Cloudflare IPv4/IPv6 edge CIDR ranges and configures Nginx/Apache real visitor IP restoration.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     2.0
#:
#: Usage:       TrustRemoteProxy.sh
#:              TrustRemoteProxy.sh [-h|--help]
#:
#: Parameters:
#:   None       Checks DNSCHOICE:cloudflare and WEBSERVERCHOICE (NGINX/APACHE) from configuration.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - External binaries: cat, echo, printf, grep, cut, curl, mv, rm, chmod, a2enmod, a2enconf
#:
#: Exit Codes:
#:   0          Cloudflare real-IP configuration generated cleanly (or skipped when DNSCHOICE != cloudflare)
#:   1          Missing /home/homedir.dat, failed CIDR fetch/validation, or config write failure
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

if [ "$("${config_checker}" 'DNSCHOICE:cloudflare')" != "1" ]
then
        exit 0
fi

tmp_v4="/tmp/cloudflare_ips_v4.$$"
tmp_v6="/tmp/cloudflare_ips_v6.$$"
tmp_conf="/tmp/cloudflare_realip_conf.$$"

cleanup_temp()
{
        /bin/rm -f "${tmp_v4}" "${tmp_v6}" "${tmp_conf}"
}
trap cleanup_temp EXIT INT TERM

# Fetch and validate Cloudflare IPv4 and IPv6 CIDR lists before modifying web server configs
if ! /usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 "https://cloudflare.com" -o "${tmp_v4}"
then
        /bin/echo "Error: Failed to fetch Cloudflare IPv4 ranges from https://cloudflare.com" >&2
        exit 1
fi

if ! /usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 "https://cloudflare.com" -o "${tmp_v6}"
then
        /bin/echo "Error: Failed to fetch Cloudflare IPv6 ranges from https://cloudflare.com" >&2
        exit 1
fi

if [ ! -s "${tmp_v4}" ] || [ ! -s "${tmp_v6}" ]
then
        /bin/echo "Error: Cloudflare IP range response was empty." >&2
        exit 1
fi

# 1. Nginx Real-IP Configuration
if [ "$("${config_checker}" 'WEBSERVERCHOICE:NGINX')" = "1" ]
then
        cloudflare_file_path="/etc/nginx/cloudflare"

        {
                /bin/echo "# Cloudflare Real IP Ranges"
                /bin/echo ""
                /bin/echo "real_ip_header CF-Connecting-IP;"
                /bin/echo ""
                /bin/echo "# - IPv4"
                while IFS= read -r cidr
                do
                        [ -z "${cidr}" ] && continue
                        if printf '%s\n' "${cidr}" | /usr/bin/grep -Eq '^[0-9.]+/[0-9]+$'
                        then
                                /bin/echo "set_real_ip_from ${cidr};"
                        else
                                /bin/echo "Error: Invalid IPv4 CIDR received from Cloudflare: '${cidr}'" >&2
                                exit 1
                        fi
                done < "${tmp_v4}"

                /bin/echo ""
                /bin/echo "# - IPv6"
                while IFS= read -r cidr
                do
                        [ -z "${cidr}" ] && continue
                        if printf '%s\n' "${cidr}" | /usr/bin/grep -Eq '^[0-9a-fA-F:]+/[0-9]+$'
                        then
                                /bin/echo "set_real_ip_from ${cidr};"
                        else
                                /bin/echo "Error: Invalid IPv6 CIDR received from Cloudflare: '${cidr}'" >&2
                                exit 1
                        fi
                done < "${tmp_v6}"
        } > "${tmp_conf}"

        /bin/chmod 644 "${tmp_conf}"
        /bin/mv "${tmp_conf}" "${cloudflare_file_path}"
fi

# 2. Apache2 Real-IP Configuration
if [ "$("${config_checker}" 'WEBSERVERCHOICE:APACHE')" = "1" ]
then
        cloudflare_file_path="/etc/apache2/conf-available/remoteip.conf"

        {
                /bin/echo "# Cloudflare Real IP Ranges"
                /bin/echo ""
                /bin/echo "RemoteIPHeader CF-Connecting-IP"
                /bin/echo ""
                /bin/echo "# - IPv4"
                while IFS= read -r cidr
                do
                        [ -z "${cidr}" ] && continue
                        if printf '%s\n' "${cidr}" | /usr/bin/grep -Eq '^[0-9.]+/[0-9]+$'
                        then
                                /bin/echo "RemoteIPTrustedProxy ${cidr}"
                        else
                                /bin/echo "Error: Invalid IPv4 CIDR received from Cloudflare: '${cidr}'" >&2
                                exit 1
                        fi
                done < "${tmp_v4}"

                /bin/echo ""
                /bin/echo "# - IPv6"
                while IFS= read -r cidr
                do
                        [ -z "${cidr}" ] && continue
                        if printf '%s\n' "${cidr}" | /usr/bin/grep -Eq '^[0-9a-fA-F:]+/[0-9]+$'
                        then
                                /bin/echo "RemoteIPTrustedProxy ${cidr}"
                        else
                                /bin/echo "Error: Invalid IPv6 CIDR received from Cloudflare: '${cidr}'" >&2
                                exit 1
                        fi
                done < "${tmp_v6}"
        } > "${tmp_conf}"

        /bin/chmod 644 "${tmp_conf}"
        /bin/mv "${tmp_conf}" "${cloudflare_file_path}"

        if [ -x /usr/sbin/a2enmod ] && [ -x /usr/sbin/a2enconf ]
        then
                /usr/sbin/a2enmod remoteip >/dev/null 2>&1 || true
                /usr/sbin/a2enconf remoteip >/dev/null 2>&1 || true
        fi
fi

exit 0

