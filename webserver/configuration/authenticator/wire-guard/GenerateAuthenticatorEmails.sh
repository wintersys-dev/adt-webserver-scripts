#!/bin/sh

set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

WEBSITE_URL_ORIGINAL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"


/usr/bin/find /var/www/html -mmin +30 -name "*qrcode*" -type f -exec rm -fv {} \;
/usr/bin/find /var/www/html -mmin +30 -name "*client*" -type f -exec rm -fv {} \;

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"

email_addresses="`/usr/bin/find ${HOME}/runtime/wire-guard/configs -name "NEEDS_PROCESSING" -print | /usr/bin/awk -F'/' '{print $8}' | /usr/bin/xargs -n1 | /usr/bin/sort -u | /usr/bin/xargs`"

echo ${email_addresses}
