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

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:virgin`" = "1" ] || [ "`${HOME}/utilities/config/CheckConfigValue.sh BUILDARCHIVECHOICE:baseline`" = "1" ] )
then
        exit
fi

if ( [ "`${HOME}/utilities/config/CheckConfigValue.sh PERSISTASSETSTODATASTORE:0`" = "1" ] )
then
        exit
fi

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
application_asset_dirs="`${HOME}/utilities/config/ExtractConfigValues.sh 'DIRECTORIESTOMOUNT' 'stripped' | /bin/sed 's/:/ /g'`"


if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:s3fs:source'`" = "1" ] )
then
  ${HOME}/services/datastore/assets/s3fs/SetupAssetsStore.sh
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:goof:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:goof:source'`" = "1" ] )
then
	${HOME}/services/datastore/assets/goofys/SetupAssetsStore.sh
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:geesefs:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:geesefs:source'`" = "1" ] )
then	
	${HOME}/services/datastore/assets/geesefs/SetupAssetsStore.sh
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:repo'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:binary'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:source'`" = "1" ] || [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTOREMOUNTTOOL:rclone:script'`" = "1" ] )
then
	${HOME}/services/datastore/assets/rclone/SetupAssetsStore.sh
fi
      
