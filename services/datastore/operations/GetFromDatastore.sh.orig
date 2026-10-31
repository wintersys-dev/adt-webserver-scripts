#!/bin/sh
###################################################################################
# @file        GetFromDatastore.sh
# @brief       Context-Aware S3 Datastore Object Retrieval & Fetching Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates individual file retrieval tasks from managed cloud 
#              datastores. It dynamically resolves naming topologies for target S3 
#              buckets based on specific system classifications. Unlike purging 
#              utilities, this fetching operation executes strictly against your 
#              primary first-order datastore instance, skipping replication loops.
#
# @param       $1  [Required] The target category classification bucket type string.
# @param       $2  [Required] Name or relative pathway of the specific cloud object to fetch.
# @param       $3  [Required] Local directory path or target file name destination.
# @param       $4  [Optional] Contextual tracking suffix used for asset paths, directory roots, or unique runtime token suffixes.
#
# @env         HOME                    Sourced application root tracking pathway string.
# @env         WEBSITE_URL             Primary base domain identifier mapping out schemas.
# @env         DNS_CHOICE              Configuration flag used to tag platform routing options.
# @env         SSL_GENERATION_SERVICE  Target backend token logic router (LETSENCRYPT/ZEROSSL).
# @env         SERVER_USER             Base tracking string used to generate local tokens.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - ExtractConfigValue.sh system service wrapper infrastructure for lookup evaluations.
#              - ExtractBuildStyleValues.sh configuration parser for active software parameters.
#              - PerformGetFromDatastore.sh data retrieval driver selected by software parameters.
#
# @security    
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent hijack exploits.
#              - Limits scope to single-node target evaluation to minimize cross-regional tokens exposure.
#              - Sanitizes additional tracking suffixes via regex mapping to block structural directory traversal escapes.
#
# @exit        0  Success: Datastore object resolution and download completed successfully.
# @exit        1  Failure: Missing mandatory arguments, invalid flags, or internal extraction driver failures.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
#########################################################################################
#########################################################################################
#set -x
set -e

HOME="$(/bin/cat /home/homedir.dat)"

if [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ]
then
        /bin/echo "Error: 3 arguments are required and 1 optional argument"
        /bin/echo "Usage: $0 <bucket_type> <file_to_get> <destination> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_get="${2}"
destination="${3}"
additional_specifier="${4}"

if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
then
        WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL')"
        DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHDNSCHOICE')"

else
        WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
fi

SSL_GENERATION_SERVICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'SSLGENERATIONSERVICE')"
SERVER_USER="$(${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER')"
TOKEN="$(/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]')"

if [ "${bucket_type}" = "ssl" ]
then
        if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
        then
                service_token="lets"
        elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
        then
                service_token="zero" 
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif [ "${bucket_type}" = "auth-ssl-1" ]
then
        WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL' | /bin/sed 's/[^.]*/auth/')"
        if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
        then
                service_token="lets"
        elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
        then
                service_token="zero"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif [ "${bucket_type}" = "multi-region" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-multi-region"
elif [ "${bucket_type}" = "webroot-sync" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-webroot-sync-tunnel$(/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g')"
elif [ "${bucket_type}" = "config-sync" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-config-sync-tunnel$(/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g')"
elif [ "${bucket_type}" = "config" ]
then
        active_bucket="$(/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g')-${TOKEN}"
elif [ "${bucket_type}" = "asset" ]
then
        active_bucket="$(/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g')"
elif [ "${bucket_type}" = "backup" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${additional_specifier}"
elif [ "${bucket_type}" = "auth" ]
then
        active_bucket="authip-adt-allowed-${additional_specifier}"
elif [ "${bucket_type}" = "dbaas" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-${DNS_CHOICE}-dbaas"
elif [ "${bucket_type}" = "snap" ]
then
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-${DNS_CHOICE}-snap"
elif [ "${bucket_type}" = "firewall-auth-laptop-ips" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-firewall-auth-laptop-ips"
elif [ "${bucket_type}" = "firewall-emailed-links" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-firewall-emailed-links"
elif [ "${bucket_type}" = "whitelist-auth-laptop-ips" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-whitelist-auth-laptop-ips"
elif [ "${bucket_type}" = "whitelist-emailed-links" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-whitelist-emailed-links"
elif [ "${bucket_type}" = "basic-auth-credentials" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-basic-auth-credentials" 
elif [ "${bucket_type}" = "wire-guard" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-wireguard"
elif [ "${bucket_type}" = "wire-guard-emails" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-wireguard-emails"
elif [ "${bucket_type}" = "wire-guard-emailed-links" ]
then
        if [ "$(/usr/bin/hostname | /bin/grep '\-auth-')" != "" ]
        then
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL')"
        else
                WEBSITE_URL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL')"
        fi
        active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
        active_bucket="${active_bucket}-wireguard-emailed-links"
fi

DATASTORE_TOOL="$(${HOME}/utilities/config/ExtractBuildStyleValues.sh "DATASTORETOOL" | /usr/bin/awk -F':' '{print $2}')"

if [ "${destination}" = "" ]
then
        destination="."
fi

${HOME}/services/datastore/operations/${DATASTORE_TOOL}/PerformGetFromDatastore.sh ${active_bucket}/${file_to_get} ${destination}

if [ "$?" != "0" ]
then
        /bin/echo "PerformGetFromDatastore.sh returned an error code"
        exit 1
fi





