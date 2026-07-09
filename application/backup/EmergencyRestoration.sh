#!/bin/sh
#set -x

HOME="`/bin/cat /home/homedir.dat`"
archive_id="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "ACTIVATE_RESTORATION.ARCHIVE" | /bin/sed 's/ACTIVATE_RESTORATION\.//g'`"

if ( [ ! -d ${HOME}/runtime/restoration_archives ] )
then
        /bin/mkdir -p ${HOME}/runtime/restoration_archives
fi

/bin/mv /var/www/html ${HOME}/runtime/restoration_archives

DB_N="`${HOME}/utilities/config/ExtractConfigValue.sh 'DBNAME' | /bin/sed 's/_ARCHIVE.*//g'`"
DB_N1="`/bin/echo .${archive_id} | /bin/sed -e 's/\./_/g' -e 's/-/_/g'`"
/bin/grep -rlZ ${DB_N} ${HOME}/runtime | /usr/bin/xargs -0 /bin/sed -i "s/${DB_N}/${DB_N}${DB_N1}/g"
/bin/grep -rlZ ${DB_N} /var/www/html | /usr/bin/xargs -0 /bin/sed -i "s/${DB_N}/${DB_N}${DB_N1}/g"
${HOME}/application/InstallApplication.sh ${archive_id}
${HOME}/application/configuration/InitialiseApplicationConfiguration.sh

