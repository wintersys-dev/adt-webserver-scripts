WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
application_asset_dirs="`${HOME}/utilities/config/ExtractConfigValues.sh 'DIRECTORIESTOMOUNT' 'stripped' | /bin/sed 's/:/ /g'`"
s3fs_gid="`/usr/bin/id -g www-data`"
s3fs_uid="`/usr/bin/id -u www-data`"
endpoint="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE' | /usr/bin/awk -F'|' '{print  $1}'`"
export AWS_ACCESS_KEY_ID="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3ACCESSKEY' | /usr/bin/awk -F'|' '{print $1}'`"
export AWS_SECRET_ACCESS_KEY="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3SECRETKEY' | /usr/bin/awk -F'|' '{print  $1}'`"


application_asset_buckets=""

if ( [ "${application_asset_dirs}" != "" ] )
then
	application_asset_buckets=""

	for directory in ${application_asset_dirs}
	do
		asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g' -e 's/_/-/g'`"
		application_asset_buckets="${application_asset_buckets} ${asset_bucket}"
	done
fi

if ( [ "${application_asset_buckets}" != "" ] )
then
	loop="1"
	for asset_bucket in ${application_asset_buckets}
	do
        asset_directory="`/bin/echo ${application_asset_dirs} | /usr/bin/cut -d " " -f ${loop}`"

        if ( [ "${not_for_merge_mount_dirs}" != "" ] && [ "`/bin/echo ${not_for_merge_mount_dirs} | /bin/grep "${asset_directory}"`" != "" ] )
        then
                asset_directory="/var/www/html/${asset_directory}"
        else
                asset_directory="/var/www/${asset_directory}"
        fi

        if ( [ ! -d ${asset_directory} ] )
        then
                /bin/mkdir -p ${asset_directory}
        fi
	done
fi
        if ( [ "`/bin/mount  | /bin/grep -P "${asset_directory}(?=\s|$)"`" = "" ] )
        then	
