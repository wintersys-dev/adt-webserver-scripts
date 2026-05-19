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

if ( [ ! -f ${HOME}/runtime/INITIAL_CONFIG_SET ] )
then
        exit
fi

#if the s3 cache size grows to be greater than 10G, clean it out
s3_cache_size="`/usr/bin/du -h --max-depth=1 /home | /bin/grep s3mount_cache | /usr/bin/awk '{print $1}' | /bin/grep 'G$' | /bin/sed 's/G//g'`" 

if ( [ "${s3_cache_size}" != "" ] && [ "${s3_cache_size}" -gt "10" ] )
then
        /bin/rm -r /home/s3mount_cache/*
fi

if ( [ ! -d /home/s3mount_cache ] )
then
        /bin/mkdir /home/s3mount_cache
fi

if ( [ ! -f /usr/bin/s3cmd ] && [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
then
        ${HOME}/installation/InstallS3CMD.sh "" "assets"
        ${HOME}/services/datastore/InitialiseDatastoreSettingsAssets.sh
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] )
then
       exit
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:0`" = "1" ] )
then
        exit
fi

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
application_asset_dirs="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"
webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"
export AWS_ACCESS_KEY_ID="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3ACCESSKEY' | /usr/bin/awk -F'|' '{print $1}'`"
export AWS_SECRET_ACCESS_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3SECRETKEY' | /usr/bin/awk -F'|' '{print  $1}'`"
endpoint="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE' | /usr/bin/awk -F'|' '{print  $1}'`"
s3fs_gid="`/usr/bin/id -g www-data`"
s3fs_uid="`/usr/bin/id -u www-data`"

for application_assets_directory in ${application_asset_dirs}
do
        if ( [ "`/bin/grep "^ASSETS_OUTSIDE_WEBROOT:yes" ${HOME}/runtime/application.dat`" != "" ] )
        then
                absolute_application_assets_directory="/var/www/html/${application_assets_directory}"
        else
                absolute_application_assets_directory="${webroot_directory}/${application_assets_directory}"
        fi

        if ( [ ! -d ${absolute_application_assets_directory} ] )
        then
                /bin/mkdir -p ${absolute_application_assets_directory}
        fi

        if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:baseline`" = "1" ] )
        then
                ${HOME}/services/datastore/operations/MountDatastore.sh "asset" "distributed" "${application_assets_directory}"
                ${HOME}/services/datastore/operations/SyncToDatastore.sh "asset" "${absolute_application_assets_directory}" "distributed" "${application_assets_directory}"
                /bin/rm -r ${absolute_application_assets_directory}/*
        else
                ${HOME}/services/datastore/operations/SyncToDatastore.sh "asset" "${absolute_application_assets_directory}" "distributed" "${application_assets_directory}"
        fi

        if ( [ "`/bin/mount | /bin/grep -P "${absolute_application_assets_directory}(?=\s|$)"`" = "" ] )
        then
                asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${application_assets_directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g' -e 's/_/-/g'`"
               
               # if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:baseline`" = "1" ] )
               # then
               #         ${HOME}/services/datastore/operations/MountDatastore.sh "asset" "distributed" "${application_assets_directory}"
               #         ${HOME}/services/datastore/operations/SyncToDatastore.sh "asset" "${absolute_application_assets_directory}" "distributed" "${application_assets_directory}"
               #         /bin/rm -r ${absolute_application_assets_directory}/*
               # fi
                
                if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:source'`" = "1" ] )
                then
                        /bin/cp ${HOME}/services/datastore/assets/config/s3fs.conf ${HOME}/runtime/s3fs.conf
                        /bin/sed -i -e "s/XXXXS3UIDXXXX/${s3fs_uid}/g" -e "s/XXXXS3GIDXXXX/${s3fs_gid}/g" -e "s;XXXXENDPOINTXXXX;${endpoint};g" ${HOME}/runtime/s3fs.conf
                        password_file="`/bin/grep "passwd_file" ${HOME}/runtime/s3fs.conf | /usr/bin/awk -F'=' '{print $NF}'`"
                        /bin/echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" > ${password_file}
                        /bin/chmod 600 ${password_file}

                        options="-o "
                        for option in `/bin/cat ${HOME}/runtime/s3fs.conf`
                        do
                                options="${options}${option},"
                        done
                        options="`/bin/echo ${options} | /bin/sed 's/,$//g'`"

                        /usr/bin/s3fs ${options} ${asset_bucket} ${absolute_application_assets_directory}
                elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:goof:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:goof:source'`" = "1" ] )
                then
                        if ( [ ! -d /root/.aws ] )
                        then
                                /bin/mkdir /root/.aws
                        fi

                        /bin/chmod 755 /root/.aws
                        /bin/echo "[default]" > /root/.aws/credentials
                        /bin/echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> /root/.aws/credentials
                        /bin/echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> /root/.aws/credentials
                        /bin/chmod 600 /root/.aws/credentials

                        /bin/cp ${HOME}/services/datastore/assets/config/goofys.conf ${HOME}/runtime/goofys.conf

                        /bin/sed -i -e "s/XXXXS3UIDXXXX/${s3fs_uid}/g" -e "s/XXXXS3GIDXXXX/${s3fs_gid}/g" -e "s;XXXXENDPOINTXXXX;${endpoint};g" ${HOME}/runtime/goofys.conf

                        options=" "
                        for option in `/bin/cat ${HOME}/runtime/goofys.conf`
                        do
                                options="${options}${option} "
                        done

                        /usr/bin/goofys ${options} ${asset_bucket} ${absolute_application_assets_directory}
                elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:geesefs:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:geesefs:source'`" = "1" ] )
                then
                        if ( [ ! -d /root/.aws ] )
                        then
                                /bin/mkdir /root/.aws
                        fi
                        /bin/chmod 755 /root/.aws
                        /bin/echo "[default]" > /root/.aws/credentials
                        /bin/echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> /root/.aws/credentials
                        /bin/echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> /root/.aws/credentials

                        /bin/cp ${HOME}/services/datastore/assets/config/geesefs.conf ${HOME}/runtime/geesefs.conf
                        /bin/sed -i -e "s/XXXXS3UIDXXXX/${s3fs_uid}/g" -e "s/XXXXS3GIDXXXX/${s3fs_gid}/g" -e "s;XXXXENDPOINTXXXX;${endpoint};g" ${HOME}/runtime/geesefs.conf

                        options=" "
                        for option in `/bin/cat ${HOME}/runtime/geesefs.conf`
                        do
                                options="${options}${option} "
                        done

                        /usr/bin/geesefs ${options} ${asset_bucket} ${absolute_application_assets_directory}
                elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:source'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:script'`" = "1" ] )
                then
                        /bin/cp ${HOME}/services/datastore/assets/config/rclone.conf ${HOME}/runtime/rclone.conf
                        /bin/sed -i -e "s/XXXXS3UIDXXXX/${s3fs_uid}/g" -e "s/XXXXS3GIDXXXX/${s3fs_gid}/g" -e "s;XXXXENDPOINTXXXX;${endpoint};g" ${HOME}/runtime/rclone.conf

                        options=" "
                        for option in `/bin/cat ${HOME}/runtime/rclone.conf`
                        do
                                options="${options}${option} "
                        done
                        /usr/bin/rclone mount ${options} s3:${asset_bucket} ${absolute_application_assets_directory} &
                fi
        fi
        if ( [ "${asset_bucket}" != "" ] && [ -f /usr/bin/s3cmd ] && [ "`/usr/bin/hostname | /bin/grep "\-rp-"`" != "" ] )
        then
                reverse_proxy_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "reverseproxypublicips/*"`"
                /bin/cp ${HOME}/services/datastore/assets/config/policy.json ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                /bin/sed -i "s/XXXXBUCKET_NAMEXXXX/${asset_bucket}" ${HOME}/runtime/datastore_workarea/policy-${asset_bucket}.json
                
                
        fi
done
      
