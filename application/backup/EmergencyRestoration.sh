#!/bin/sh
#set -x

HOME="`/bin/cat /home/homedir.dat`"
archive_id="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "ACTIVATE_RESTORATION.ARCHIVE" | /bin/sed 's/ACTIVATE_RESTORATION\.//g'`"

if ( [ ! -d ${HOME}/runtime/restoration_archives ] )
then
        /bin/mkdir -p ${HOME}/runtime/restoration_archives
fi

/bin/mv /var/www/html ${HOME}/runtime/restoration_archives

${HOME}/application/InstallApplication.sh ${archive_id}
${HOME}/application/configuration/InitialiseApplicationConfiguration.sh

