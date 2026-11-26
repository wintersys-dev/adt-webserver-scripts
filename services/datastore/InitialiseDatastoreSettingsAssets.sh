#!/bin/sh
#: Name:        InitialiseDatastoreSettings.sh
#: Purpose:     Configures the primary s3cmd datastore profile, root shell alias, and validates connectivity.
#: Author:      Peter Winter
#: Date:        26/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseDatastoreSettings.sh [access_key] [secret_key] [location] [host_base]
#:              InitialiseDatastoreSettings.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] S3 access key ID (defaults to ExtractConfigValue.sh 'S3ACCESSKEY')
#:   $2         [Optional] S3 secret access key (defaults to ExtractConfigValue.sh 'S3SECRETKEY')
#:   $3         [Optional] S3 region/location string (defaults to ExtractConfigValue.sh 'S3LOCATION')
#:   $4         [Optional] S3 endpoint hostname (defaults to ExtractConfigValue.sh 'S3HOSTBASE')
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat and exported
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/services/datastore/init-files/s3-cfg.tmpl
#:   - /usr/bin/s3cmd
#:   - External binaries: cat, echo, grep, cut, mkdir, cp, rm, sed, chmod, chown, awk
#:
#: Exit Codes:
#:   0          s3cmd profile configured and bucket smoke-test succeeded cleanly
#:   1          Missing /home/homedir.dat, missing S3 credentials/template, or smoke-test failure
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

log_dir="${HOME}/logs/initialbuild"
if [ ! -d "${log_dir}" ]
then
        /bin/mkdir -p "${log_dir}"
fi
MONITOR_LOG="${log_dir}/BUILD_PROCESS_MONITORING.log"

log_init_error()
{
        /bin/echo "${0} ${1}" >&2
        /bin/echo "${0} ${1}" >> "${MONITOR_LOG}" 2>/dev/null || true
}

config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"

set +e
SERVER_USER="$("${config_extractor}" 'SERVERUSER')"

if [ -z "${1}" ]
then
        S3_ACCESS_KEY="$("${config_extractor}" 'S3ACCESSKEY')"
else
        S3_ACCESS_KEY="${1}"
fi

if [ -z "${2}" ]
then
        S3_SECRET_KEY="$("${config_extractor}" 'S3SECRETKEY')"
else
        S3_SECRET_KEY="${2}"
fi

if [ -z "${3}" ]
then
        S3_LOCATION="$("${config_extractor}" 'S3LOCATION')"
else
        S3_LOCATION="${3}"
fi

if [ -z "${4}" ]
then
        S3_HOST_BASE="$("${config_extractor}" 'S3HOSTBASE')"
else
        S3_HOST_BASE="${4}"
fi
set -e

if [ -z "${S3_ACCESS_KEY}" ]
then
        log_init_error "Couldn't find the S3_ACCESS_KEY setting"
        exit 1
fi

if [ -z "${S3_SECRET_KEY}" ]
then
        log_init_error "Couldn't find the S3_SECRET_KEY setting"
        exit 1
fi

if [ -z "${S3_HOST_BASE}" ]
then
        log_init_error "Couldn't find the S3_HOST_BASE setting"
        exit 1
fi

if [ -z "${S3_LOCATION}" ]
then
        log_init_error "Couldn't find the S3_LOCATION setting"
fi

template_file="${HOME}/services/datastore/init-files/s3-cfg.tmpl"
if [ ! -r "${template_file}" ]
then
        log_init_error "s3cmd configuration template missing at ${template_file}"
        exit 1
fi

# Safely escape sed replacement special characters (&, \, and delimiter |)
escape_sed_rep()
{
        printf '%s' "${1}" | /bin/sed -e 's/[\\&|]/\\&/g'
}

escaped_access="$(escape_sed_rep "${S3_ACCESS_KEY}")"
escaped_secret="$(escape_sed_rep "${S3_SECRET_KEY}")"
escaped_location="$(escape_sed_rep "${S3_LOCATION}")"
escaped_host="$(escape_sed_rep "${S3_HOST_BASE}")"

primary_host="$(printf '%s' "${S3_HOST_BASE}" | /usr/bin/awk -F'|' '{print $1}')"

/bin/rm -f "${HOME}/.s3cfg"
/bin/cp "${template_file}" "${HOME}/.s3cfg"

/bin/sed -i "s|XXXXACCESSKEYXXXX|${escaped_access}|g" "${HOME}/.s3cfg"
/bin/sed -i "s|XXXXSECRETKEYXXXX|${escaped_secret}|g" "${HOME}/.s3cfg"
/bin/sed -i "s|XXXXLOCATIONXXXX|${escaped_location}|g" "${HOME}/.s3cfg"
/bin/sed -i "s|XXXXHOSTBASEXXXX|${escaped_host}|g" "${HOME}/.s3cfg"

if [ -f /root/.bashrc ] && ! /bin/grep -q '^alias s3cmd=' /root/.bashrc
then
        /bin/echo "alias s3cmd='/usr/bin/s3cmd --config=/root/.s3cfg --host=https://${primary_host} '" >> /root/.bashrc
fi

/bin/cp "${HOME}/.s3cfg" /root/.s3cfg
/bin/chmod 600 /root/.s3cfg "${HOME}/.s3cfg"
[ -n "${SERVER_USER}" ] && /bin/chown "${SERVER_USER}:${SERVER_USER}" "${HOME}/.s3cfg"

# Verify credential profile with a temporary bucket create/delete smoke test
datastore_tool="/usr/bin/s3cmd --config=/root/.s3cfg --host=https://${primary_host}"

set +e
${datastore_tool} mb "s3://1$$agile" >/dev/null 2>&1
create_exit="$?"
${datastore_tool} rb "s3://1$$agile" >/dev/null 2>&1
remove_exit="$?"
set -e

if [ "${create_exit}" -ne 0 ] || [ "${remove_exit}" -ne 0 ]
then
        log_init_error "Your datastore didn't configure correctly on this machine and that will cause the deployment to break"
        exit 1
fi

exit 0



if ( [ "$?" != "0" ] )
then
        /bin/echo "${0} Your datastore didn't configure correctly on this machine and that will cause the deployment to break" >> ${HOME}/logs/initialbuild/BUILD_PROCESS_MONITORING.log  
fi
