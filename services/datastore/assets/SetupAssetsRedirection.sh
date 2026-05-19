#!/bin/sh
####################################################################################
# Description: This script mounts a bucket from a cloud based datastore and uses it
# as a shared directory.
# This should only be used if you are deploying from a temporal backup. Baselined
# and virgin deployments shouldn't use this and should have their assets on the 
# local filesystem.
# Author: Peter Winter
# Date :  9/4/2016
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
####################################################################################
#set -x

if ( [ ! -f /usr/bin/s3cmd ] && [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
then
        ${HOME}/installation/InstallS3CMD.sh "" "assets"
        ${HOME}/services/datastore/InitialiseDatastoreSettingsAssets.sh
fi

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
S3_HOST_BASE="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE'`"
application_asset_dirs="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"

for application_assets_directory in ${application_asset_dirs}
do
        asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${application_assets_directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g' -e 's/_/-/g'`"

        #s3cmd is the only tool I use (I think) that can set bucket policies so we cludge it to make it so
        if ( [ "${asset_bucket}" != "" ] && [ -f /usr/bin/s3cmd ] && [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
        then
                reverse_proxy_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "reverseproxypublicips/*"`"
                /bin/cp ${HOME}/services/datastore/assets/policy/policy-template.json ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                /bin/sed -i "s/XXXXBUCKET_NAMEXXXX/${asset_bucket}/g" ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                for ip in ${reverse_proxy_ips}
                do
                        /bin/sed -i '/XXXXRP_PUBLIC_IPXXXX/a "'${ip}'/32",' ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                done
                /bin/sed -zi 's/\(.*\),/\1/' ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                /bin/sed -i 's/XXXXRP_PUBLIC_IPXXXX//g' ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                /usr/bin/s3cmd setpolicy ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json s3://${asset_bucket}
                full_bucket_url="${asset_bucket}.${S3_HOST_BASE}"
                #Do this in webserver part?
                #Add this to the apache, nginx and lighttpd config files like I do for the reverse proxy ip addresses
        fi
done
