#!/bin/sh
#####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Suite:  The Agile Deployment Toolkit
# 
# Description: This script automates uploading individual files or asset directories 
#              to managed cloud datastores. It dynamically constructs naming 
#              topologies for target S3 buckets based on specific system profiles. It passes the 
#              payload to an underlying script execution engine with an optional 
#              post-upload deletion flag, executing either against a standalone primary 
#              endpoint ("local") or propagating sequentially across multi-node 
#              distributed regional clusters ("distributed").
#
# Arguments:
#              $1 - <bucket_type>            : Target category classification. 
#              $2 - <file_to_put>            : Absolute or relative local pathway of the file to upload.
#              $3 - <place_to_put>           : Target destination folder path within the bucket. Passing 
#                                              "root" resets this to an empty base value.
#              $4 - <mode>                   : Topology routine selection. Valid values:
#                                              "local"       -> Single target datastore evaluation.
#                                              "distributed" -> Multi-token configuration fanout loop.
#              $5 - <delete>                 : Operational switch flag (e.g., true/false or 1/0) indicating 
#                                              whether to purge the local source file after a success.
#              $6 - [additional_specifier]   : Optional contextual tracking suffix string used for 
#                                              asset paths, target sub-directories, or unique node tags.
#
# Environmental Dependencies:
#              - /home/buildhome.dat containing valid application root pathway tracking string.
#              - Toolkit helpers: GetVariableValue.sh script infrastructure for variable evaluations.
#              - Environment registers: S3_ACCESS_KEY, WEBSITE_URL, DNS_CHOICE, SERVER_USER, 
#                                       SSL_GENERATION_SERVICE configuration states.
#####################################################################################
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
######################################################################################
######################################################################################
#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ]  || [ "${5}" = "" ] )
then
        /bin/echo "Error: 5 arguments are required and 1 optional argument"
        /bin/echo "Usage: $0 <bucket_type> <file_to_put> <place_to_put> <mode> <delete> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_put="${2}"
place_to_put="${3}"
mode="${4}"
delete="${5}"
additional_specifier="${6}"

if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
then
        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHSERVERURL'`"
        DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'AUTHDNSCHOICE'`"

else
        WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        DNS_CHOICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE'`"
fi

SSL_GENERATION_SERVICE="`${HOME}/utilities/config/ExtractConfigValue.sh 'SSLGENERATIONSERVICE'`"
SERVER_USER="`${HOME}/utilities/config/ExtractConfigValue.sh 'SERVERUSER'`"
TOKEN="`/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]'`"

if ( [ "${place_to_put}" = "root" ] )
then
        place_to_put=""
fi

if ( [ "${bucket_type}" = "ssl" ] )
then
        if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
        then
                service_token="lets"
        elif ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
        then
                service_token="zero" 
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif ( [ "${bucket_type}" = "multi-region" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-multi-region"
elif ( [ "${bucket_type}" = "webroot-sync" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-webroot-sync-tunnel`/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g'`"
elif ( [ "${bucket_type}" = "config-sync" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-config-sync-tunnel`/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g'`"
elif ( [ "${bucket_type}" = "config" ] )
then
        active_bucket="`/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g'`-${TOKEN}"
elif ( [ "${bucket_type}" = "asset" ] )
then
        active_bucket="`/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g'`"
elif ( [ "${bucket_type}" = "backup" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-${additional_specifier}"
elif ( [ "${bucket_type}" = "auth" ] )
then
        active_bucket="authip-adt-allowed-${additional_specifier}"
elif ( [ "${bucket_type}" = "dbaas" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-dbaas"
elif ( [ "${bucket_type}" = "snap" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-snap"
elif ( [ "${bucket_type}" = "firewall-auth-laptop-ips" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-firewall-auth-laptop-ips"
elif ( [ "${bucket_type}" = "firewall-emailed-links" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-firewall-emailed-links"
elif ( [ "${bucket_type}" = "whitelist-auth-laptop-ips" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-whitelist-auth-laptop-ips"
elif ( [ "${bucket_type}" = "whitelist-emailed-links" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-whitelist-emailed-links"
elif ( [ "${bucket_type}" = "basic-auth-credentials" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-basic-auth-credentials" 
elif ( [ "${bucket_type}" = "wire-guard" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-wireguard"
elif ( [ "${bucket_type}" = "wire-guard-emails" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-wireguard-emails"
elif ( [ "${bucket_type}" = "wire-guard-emailed-links" ] )
then
        if ( [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] )
        then
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
        else
                WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-wireguard-emailed-links"
fi

S3_ACCESS_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3ACCESSKEY'`"

no_tokens="`/bin/echo "${S3_ACCESS_KEY}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l`"
no_tokens="`/usr/bin/expr ${no_tokens} + 1`"

count="1"


if ( [ "${mode}" = "local" ] )
then
        ${HOME}/services/datastore/operations/PerformPutToDatastore.sh ${file_to_put} ${active_bucket}/${place_to_put} ${delete} ${count}
elif ( [ "${mode}" = "distributed" ] )
then
        while ( [ "${count}" -le "${no_tokens}" ] )
        do
                ${HOME}/services/datastore/operations/PerformPutToDatastore.sh ${file_to_put} ${active_bucket}/${place_to_put} "no" ${count}
                count="`/usr/bin/expr ${count} + 1`"
        done
fi
