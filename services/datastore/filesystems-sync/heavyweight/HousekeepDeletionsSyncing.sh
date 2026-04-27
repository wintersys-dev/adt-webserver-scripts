#!/bin/sh
#####################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Keep addition archives around for 5 minutes (300 seconds)
# and once these archives are more than 5 minutes old they can be deleted and the 
# historical copy will then become the authoritative archive.
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
####################################################################################
#set -x

target_directory="${1}"
bucket_type="${2}"

deletions="`${HOME}/services/datastore/operations/ListFromDatastore.sh "${bucket_type}" "filesystem-sync/${bucket_type}/deletions/*" "${target_directory}"`"

for deletion in ${deletions}
do
        #Get the logfile from the datastore using GetFrom and then get the timestamp of when the deletions in the logfile were processed
        #Logfile needs to contain the timestamp in the filename of the file in the logfile


        current_time="`/usr/bin/date +%s`"
        processing_time="`/bin/cat ${HOME}/runtime/datastore_workarea/webroot_sync_timestamp.del`"

        if ( [ -f ${HOME}/runtime/datastore_workarea/webroot_sync_timestamp.del ] )
        then
                /bin/rm ${HOME}/runtime/datastore_workarea/webroot_sync_timestamp.del
        fi
        
        if ( [ "`/usr/bin/expr ${current_time} - ${processing_time}`" -gt "60" ] )
        then
                ${HOME}/services/datastore/operations/DeleteFromDatastore.sh "${bucket_type}" "filesystem-sync/${bucket_type}/deletions/${deletion}" "distributed" "${target_directory}"
        fi
        
      #  if ( [ "`${HOME}/services/datastore/operations/AgeOfDatastoreFile.sh "${bucket_type}" "filesystem-sync/${bucket_type}/deletions/${deletion}" "${target_directory}"`" -gt "60" ] )
      #  then
      #          ${HOME}/services/datastore/operations/DeleteFromDatastore.sh "${bucket_type}" "filesystem-sync/${bucket_type}/deletions/${deletion}" "distributed" "${target_directory}"
      #  fi
done
