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

if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:source'`" = "1" ] )
then
  

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
						
						/usr/bin/goofys ${options} ${asset_bucket} ${asset_directory}  &

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

						/usr/bin/geesefs ${options} ${asset_bucket} ${asset_directory} &
						
                elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:source'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:script'`" = "1" ] )
               
