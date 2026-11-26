#!/bin/sh
#: Name:        RenewSSLCertificate.sh
#: Purpose:     Polls the SSL datastore for renewed TLS certificates, validates them, installs them, and reloads the webserver.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       RenewSSLCertificate.sh
#:              RenewSSLCertificate.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads WEBSITEURL from configuration and checks the "ssl" datastore namespace for updated PEM files.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/datastore/operations/ListFromDatastore.sh
#:   - ${HOME}/services/datastore/operations/GetFromDatastore.sh
#:   - ${HOME}/webserver/ReloadWebserver.sh
#:   - External binaries: cat, echo, grep, cut, mkdir, mv, rm, chown, chmod, cmp, openssl
#:
#: Exit Codes:
#:   0          SSL certificates verified (and rotated/reloaded if renewed)
#:   1          Missing /home/homedir.dat, missing WEBSITEURL, invalid PEM files, or datastore/reload failure
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
list_from="${HOME}/services/datastore/operations/ListFromDatastore.sh"
get_from="${HOME}/services/datastore/operations/GetFromDatastore.sh"
reload_webserver="${HOME}/webserver/ReloadWebserver.sh"

set +e
WEBSITE_URL="$("${config_extractor}" 'WEBSITEURL')"
set -e

if [ -z "${WEBSITE_URL}" ]
then
        /bin/echo "Error: Failed to fetch required context variable (WEBSITEURL)." >&2
        exit 1
fi

ssl_live_dir="${HOME}/ssl/live/${WEBSITE_URL}"
ssl_new_dir="${ssl_live_dir}/new"

set +e
has_fullchain="$("${list_from}" "ssl" "fullchain.pem" 2>/dev/null)"
has_privkey="$("${list_from}" "ssl" "privkey.pem" 2>/dev/null)"
set -e

if [ -n "${has_fullchain}" ] && [ -n "${has_privkey}" ]
then
        if [ ! -d "${ssl_new_dir}" ]
        then
                /bin/mkdir -p "${ssl_new_dir}"
        fi
        /bin/chmod 700 "${ssl_new_dir}"

        "${get_from}" "ssl" "fullchain.pem" "${ssl_new_dir}"
        "${get_from}" "ssl" "privkey.pem" "${ssl_new_dir}"
fi

new_fullchain="${ssl_new_dir}/fullchain.pem"
new_privkey="${ssl_new_dir}/privkey.pem"
cur_fullchain="${ssl_live_dir}/fullchain.pem"
cur_privkey="${ssl_live_dir}/privkey.pem"

if [ -s "${new_fullchain}" ] && [ -s "${new_privkey}" ]
then
        # Validate PEM integrity before touching live certificates
        if [ -x /usr/bin/openssl ]
        then
                if ! /usr/bin/openssl x509 -in "${new_fullchain}" -noout >/dev/null 2>&1 || \
                   ! /usr/bin/openssl pkey -in "${new_privkey}" -check -noout >/dev/null 2>&1
                then
                        /bin/echo "Error: Downloaded SSL certificate or private key failed OpenSSL validation; aborting rotation." >&2
                        /bin/rm -f "${new_fullchain}" "${new_privkey}"
                        exit 1
                fi
        fi

        needs_update="0"
        if [ ! -f "${cur_fullchain}" ] || [ ! -f "${cur_privkey}" ]
        then
                needs_update="1"
        elif ! /usr/bin/cmp -s "${new_fullchain}" "${cur_fullchain}" || ! /usr/bin/cmp -s "${new_privkey}" "${cur_privkey}"
        then
                needs_update="1"
        fi

        if [ "${needs_update}" = "1" ]
        then
                if [ -f "${cur_fullchain}" ]
                then
                        /bin/mv "${cur_fullchain}" "${cur_fullchain}.$$"
                fi
                if [ -f "${cur_privkey}" ]
                then
                        /bin/mv "${cur_privkey}" "${cur_privkey}.$$"
                fi

                /bin/mv "${new_fullchain}" "${cur_fullchain}"
                /bin/mv "${new_privkey}" "${cur_privkey}"
                /bin/chown www-data:www-data "${cur_fullchain}" "${cur_privkey}"
                /bin/chmod 640 "${cur_fullchain}" "${cur_privkey}"

                "${reload_webserver}"
        else
                /bin/rm -f "${new_fullchain}" "${new_privkey}"
        fi
fi

exit 0






