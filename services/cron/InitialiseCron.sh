#!/bin/sh
#: Name:        InitialiseCron.sh
#: Purpose:     Generates and installs the root crontab schedule for authenticator, reverse proxy, and webserver nodes.
#: Author:      Peter Winter
#: Date:        25/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseCron.sh
#:              InitialiseCron.sh [-h|--help]
#:
#: Parameters:
#:   None       Detects node role from hostname (-auth-, -rp-, ws-) and deployment config via ExtractConfigValue.sh.
#:
#: Environment:
#:   HOME       Resolved automatically from /home/homedir.dat
#:
#: Dependencies:
#:   - /home/homedir.dat
#:   - ${HOME}/utilities/config/ExtractConfigValue.sh
#:   - ${HOME}/utilities/config/CheckConfigValue.sh
#:   - ${HOME}/utilities/config/ExtractBuildStyleValues.sh
#:   - ${HOME}/utilities/config/CheckBuildStyle.sh
#:   - ${HOME}/utilities/processing/RunServiceCommand.sh
#:   - External binaries: cat, echo, grep, cut, awk, hostname, mktemp, rm, crontab, shuf, nice, sleep
#:
#: Exit Codes:
#:   0          Root (and optional www-data) crontabs generated, installed, and cron service restarted cleanly
#:   1          Missing /home/homedir.dat, missing config helpers, or crontab installation failure
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

# Resolve the toolkit root directory from /home/homedir.dat
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Error: Home configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${HOME}" ] || [ ! -d "${HOME}" ]
then
        /bin/echo "Error: Resolved HOME directory '${HOME}' is invalid." >&2
        exit 1
fi

# Verify required configuration helpers exist
config_extractor="${HOME}/utilities/config/ExtractConfigValue.sh"
config_checker="${HOME}/utilities/config/CheckConfigValue.sh"
style_extractor="${HOME}/utilities/config/ExtractBuildStyleValues.sh"
style_checker="${HOME}/utilities/config/CheckBuildStyle.sh"

if [ ! -x "${config_extractor}" ] || [ ! -x "${config_checker}" ] || [ ! -x "${style_extractor}" ] || [ ! -x "${style_checker}" ]
then
        /bin/echo "Error: One or more configuration helper scripts are missing or not executable under ${HOME}/utilities/config/" >&2
        exit 1
fi

# Build the new root crontab in a temporary staging file before installing via crontab(1)
tmp_cron="$(/bin/mktemp)"
cleanup()
{
        /bin/rm -f "${tmp_cron}"
}
trap cleanup EXIT INT TERM HUP QUIT

# Resolve timezone and node hostname role once
node_hostname="$(/usr/bin/hostname)"
SERVER_TIMEZONE_CONTINENT="$("${config_extractor}" 'SERVERTIMEZONECONTINENT')"
SERVER_TIMEZONE_CITY="$("${config_extractor}" 'SERVERTIMEZONECITY')"

if ( [ ! -d ${HOME}/runtime/logs/crontab ] )
then
        /bin/mkdir -p ${HOME}/runtime/logs/crontab 
fi

logging=" >>${HOME}/runtime/logs/crontab/log.out 2>>${HOME}/runtime/logs/crontab/err.out "

# Write global cron environment headers
{
        /bin/echo "MAILTO=''"
        /bin/echo "HOME=${HOME}"
        if [ -n "${SERVER_TIMEZONE_CONTINENT}" ] && [ -n "${SERVER_TIMEZONE_CITY}" ]
        then
                /bin/echo "TZ=:${SERVER_TIMEZONE_CONTINENT}/${SERVER_TIMEZONE_CITY}"
        fi
} > "${tmp_cron}"

# Helper to schedule sub-minute staggered jobs cleanly (step in seconds: 5 or 10)
schedule_subminute_job()
{
        step="${1}"
        cmd="${2}"
        offset=0
        while [ "${offset}" -lt 60 ]
        do
                if [ "${offset}" -eq 0 ]
                then
                        /bin/echo "*/1 * * * * ${cmd}" >> "${tmp_cron}"
                else
                        /bin/echo "*/1 * * * * /bin/sleep ${offset} && ${cmd}" >> "${tmp_cron}"
                fi
                offset=$((offset + step))
        done
}

# Role-specific schedules
case "${node_hostname}" in
        *-auth-*)
                WEBSERVER_CHOICE="$("${config_extractor}" 'WEBSERVERCHOICE')"
                AUTHENTICATOR_TYPE="$("${config_extractor}" 'AUTHENTICATORTYPE')"

                /bin/echo "*/1 * * * * ${HOME}/webserver/CheckWebserverIsUp.sh ${WEBSERVER_CHOICE}" >> "${tmp_cron}"

                case "${AUTHENTICATOR_TYPE}" in
                        firewall|whitelist)
                                schedule_subminute_job 10 "${HOME}/webserver/configuration/authenticator/${AUTHENTICATOR_TYPE}/AcceptIPAddresses.sh ${logging}"
                                schedule_subminute_job 10 "${HOME}/webserver/configuration/authenticator/${AUTHENTICATOR_TYPE}/GenerateAuthenticationEmails.sh ${logging}"
                                /bin/echo "*/1 * * * * /usr/bin/find /var/www/html/ip-address* -mmin +30 -type f -exec rm -fv {} \\;" >> "${tmp_cron}"
                                ;;
                        basic-auth)
                                schedule_subminute_job 10 "${HOME}/webserver/configuration/authenticator/${AUTHENTICATOR_TYPE}/GenerateBasicAuthConfig.sh ${logging}"
                                ;;
                        wire-guard)
                                schedule_subminute_job 5 "${HOME}/webserver/configuration/authenticator/${AUTHENTICATOR_TYPE}/AcceptEmailAddresses.sh ${logging}"
                                /bin/echo "*/1 * * * * ${HOME}/webserver/configuration/authenticator/${AUTHENTICATOR_TYPE}/GenerateAuthenticatorEmails.sh ${logging}" >> "${tmp_cron}"
                                ;;
                esac

                /bin/echo "45 4 * * * /bin/rm -f ${HOME}/runtime/FIREWALL-ACTIVE" >> "${tmp_cron}"
                ;;

        ws-*|*-rp-*)
                WEBSERVER_CHOICE="$("${config_extractor}" 'WEBSERVERCHOICE')"
                APPLICATION="$("${config_extractor}" 'APPLICATION')"

                # Webserver-only tasks
                case "${node_hostname}" in
                        ws-*)
                                if [ "${APPLICATION}" = "moodle" ] && [ -r "${HOME}/runtime/application.dat" ]
                                then
                                        webroot_directory="$(/bin/grep "^WEBROOT_DIRECTORY:" "${HOME}/runtime/application.dat" | /usr/bin/awk -F':' '{print $NF}')"
                                        if [ -n "${webroot_directory}" ]
                                        then
                                                /bin/echo "*/1 * * * * /usr/bin/sudo -u www-data /usr/bin/php ${webroot_directory}/admin/cli/cron.php ${logging}" >> "${tmp_cron}"
                                        fi
                                fi
                                /bin/echo "*/1 * * * * ${HOME}/utilities/security/CheckWebrootImmutabilityStatus.sh ${logging}" >> "${tmp_cron}"
                                ;;
                esac

                # Reverse-proxy-only tasks
                case "${node_hostname}" in
                        *-rp-*)
                                /bin/echo "*/1 * * * * /bin/sleep 40 && ${HOME}/webserver/configuration/reverseproxy/RemoveOldIPFromReverseProxyIPList.sh ${logging}" >> "${tmp_cron}"
                                /bin/echo "*/1 * * * * /bin/sleep 20 && ${HOME}/webserver/configuration/reverseproxy/RemoveOldIPFromReverseProxyIPList.sh ${logging}" >> "${tmp_cron}"
                                /bin/echo "*/1 * * * * /bin/sleep 30 && ${HOME}/webserver/configuration/reverseproxy/EnsureReverseProxyWebserverIPs.sh ${logging}" >> "${tmp_cron}"
                                /bin/echo "*/1 * * * * ${HOME}/webserver/configuration/reverseproxy/EnsureReverseProxyWebserverIPs.sh ${logging}" >> "${tmp_cron}"

                                if [ "$("${config_checker}" "NOAUTHENTICATORS:0")" != "1" ] && [ "$("${config_checker}" "NOREVERSEPROXIES:0")" != "1" ]
                                then
                                        AUTHENTICATOR_TYPE="$("${config_extractor}" 'AUTHENTICATORTYPE')"
                                        case "${AUTHENTICATOR_TYPE}" in
                                                firewall|whitelist)
                                                        schedule_subminute_job 10 "${HOME}/services/security/${AUTHENTICATOR_TYPE}/AllowAuthenticatorIPAddress.sh ${logging}"
                                                        ;;
                                                basic-auth)
                                                        schedule_subminute_job 10 "${HOME}/services/security/basic-auth/ObtainBasicAuthCredentials.sh ${logging}"
                                                        ;;
                                                wire-guard)
                                                        schedule_subminute_job 5 "${HOME}/webserver/configuration/reverseproxy/wire-guard/ObtainEmails.sh ${logging}"
                                                        schedule_subminute_job 5 "${HOME}/webserver/configuration/reverseproxy/wire-guard/GenerateServerPeer.sh ${logging}"
                                                        schedule_subminute_job 5 "${HOME}/webserver/configuration/reverseproxy/wire-guard/GenerateClientInterfaceAndPeer.sh ${logging}"
                                                        ;;
                                        esac
                                fi
                                ;;
                esac

                # Shared webserver & reverse proxy tasks (every minute)
                {
                        /bin/echo "*/1 * * * * ${HOME}/webserver/CheckWebserverIsUp.sh ${WEBSERVER_CHOICE} ${logging}"
                        /bin/echo "*/1 * * * * ${HOME}/utilities/status/MonitorForOverload.sh ${logging}"
                        /bin/echo "*/1 * * * * ${HOME}/utilities/housekeeping/RemoveExpiredLocks.sh ${logging}"
                        /bin/echo "*/1 * * * * ${HOME}/services/cron/ExecuteApplicationSpecificCronjob.sh ${logging}"
                } >> "${tmp_cron}"

                if [ "$("${config_checker}" "PERSISTASSETSTODATASTORE:1")" = "1" ] || [ "$("${config_checker}" "PERSISTASSETSTODATASTORE:2")" = "1" ]
                then
                        /bin/echo "*/1 * * * * ${HOME}/services/datastore/assets/SetupAssetsStore.sh ${logging}" >> "${tmp_cron}"
                fi

                if [ "$("${config_checker}" "SYNCWEBROOTS:1")" = "1" ]
                then
                        for sync_offset in 2 15 30 45
                        do
                                /bin/echo "*/1 * * * * /bin/sleep ${sync_offset} && ${HOME}/services/datastore/filesystems-sync/heavyweight/FileSystemsSyncingController.sh '${sync_offset}' '/var/www/html' 'webroot-sync' ${logging}" >> "${tmp_cron}"
                        done
                fi

                # Scheduled webroot backup jobs
                {
                        /bin/echo "30 1 * * * ${HOME}/utilities/security/EnforcePermissions.sh ${logging}"
                        /bin/echo "2 * * * * ${HOME}/services/cron/BackupFromCron.sh 'hourly' ${logging}"
                        /bin/echo "30 2 * * * ${HOME}/services/cron/BackupFromCron.sh 'daily' ${logging}"
                        /bin/echo "30 3 * * 7 ${HOME}/services/cron/BackupFromCron.sh 'weekly' ${logging}"
                        /bin/echo "30 4 1 * * ${HOME}/services/cron/BackupFromCron.sh 'monthly' ${logging}"
                        /bin/echo "30 5 1 Jan,Mar,May,Jul,Sep,Nov * ${HOME}/services/cron/BackupFromCron.sh 'bimonthly' ${logging}"
                } >> "${tmp_cron}"
                ;;
esac

# Common system maintenance, security, and monitoring jobs across all node roles
{
        /bin/echo "*/1 * * * * ${HOME}/utilities/security/AuditSSHConnections.sh ${logging}"
        /bin/echo "*/1 * * * * ${HOME}/utilities/processing/UpdateIPs.sh ${logging}"
        /bin/echo "*/1 * * * * /bin/sleep 30 && ${HOME}/utilities/processing/UpdateIPs.sh ${logging}"
        /bin/echo "*/1 * * * * ${HOME}/services/cron/SetupFirewallFromCron.sh ${logging}"
        /bin/echo "*/1 * * * * ${HOME}/utilities/status/MarkedForShutdown.sh ${logging}"
        /bin/echo "*/1 * * * * ${HOME}/utilities/status/CheckNetworkManagerStatus.sh ${logging}"
        /bin/echo "*/1 * * * * ${HOME}/services/cron/PerformEmergencyRestorationFromCron.sh ${logging}"
        /bin/echo "*/5 * * * * /bin/sleep 23 && ${HOME}/services/security/firewall/MonitorFirewall.sh ${logging}"
        /bin/echo "*/10 * * * * ${HOME}/utilities/status/MonitorCron.sh ${logging}"
        /bin/echo "35 3 * * * ${HOME}/services/security/ssl/RenewSSLCertificate.sh ${logging}"
        /bin/echo "30 3 * * * ${HOME}/utilities/housekeeping/RemoveExpiredLogs.sh ${logging}"
        /bin/echo "22 4 * * * ${HOME}/utilities/software/UpdateSoftware.sh ${logging}"
        /bin/echo "44 4 * * * ${HOME}/installation/UpdateAndUpgrade.sh ${logging}"
        /bin/echo "@hourly ${HOME}/utilities/status/LoadMonitoring.sh ${logging}"
        /bin/echo "@daily ${HOME}/utilities/housekeeping/ArchiveErrorLogs.sh ${logging}"
} >> "${tmp_cron}"

# Reboot initialization tasks
{
        /bin/echo "@reboot ${HOME}/utilities/status/CheckNetworkManagerStatus.sh ${logging}"
        /bin/echo "@reboot ${HOME}/webserver/RestartWebserver.sh ${logging}"
        /bin/echo "@reboot ${HOME}/utilities/housekeeping/CleanupAtReboot.sh ${logging}"
        /bin/echo "@reboot ${HOME}/utilities/processing/GetIP.sh ${logging}"
        /bin/echo "@reboot ${HOME}/utilities/housekeeping/RemoveExpiredLocks.sh reboot ${logging}"
        /bin/echo "@reboot ${HOME}/utilities/status/LoadMonitoring.sh 'reboot' ${logging}"
} >> "${tmp_cron}"

datastore_style="$("${style_extractor}" "DATASTORECONFIGSTYLE" | /usr/bin/awk -F':' '{print $NF}')"
case "${datastore_style}" in
        lightweight)
                /bin/echo "@reboot ${HOME}/services/datastore/config/ActivateConfigDatastoreLightweight.sh ${logging}" >> "${tmp_cron}"
                ;;
        heavyweight)
                /bin/echo "@reboot ${HOME}/services/datastore/config/ActivateConfigDatastoreHeavyweight.sh ${logging}" >> "${tmp_cron}"
                ;;
esac

# Optional scheduled virus scan based on build style
if [ "$("${style_checker}" 'VIRUSSCANNER:')" = "1" ]
then
        periodicity="$("${style_extractor}" 'VIRUSSCANNER' | /usr/bin/awk -F':' '{print $NF}')"
        case "${periodicity}" in
                daily|weekly|monthly)
                        /bin/echo "@${periodicity} /bin/sleep \\$(/usr/bin/shuf -i1-1000 -n1) && /usr/bin/nice -n 15 ${HOME}/utilities/security/VirusScan.sh ${logging}" >> "${tmp_cron}"
                        ;;
        esac
fi

# Install the staged root crontab safely via crontab(1)
if ! /usr/bin/crontab -u root "${tmp_cron}"
then
        /bin/echo "Error: Failed to install root crontab from staging file." >&2
        exit 1
fi

# Reload existing www-data crontab if present
if [ -f /var/spool/cron/crontabs/www-data ]
then
        /usr/bin/crontab -u www-data /var/spool/cron/crontabs/www-data
fi

# Restart the cron daemon to apply schedule changes cleanly
service_runner="${HOME}/utilities/processing/RunServiceCommand.sh"
if [ -x "${service_runner}" ]
then
        "${service_runner}" "cron" restart
else
        /bin/echo "Error: Service runner missing or not executable at ${service_runner}" >&2
        exit 1
fi

exit 0


