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
        asset_directory="/var/www/s3-${asset_directory}"

        if ( [ ! -d ${asset_directory} ] )
        then
                /bin/mkdir -p ${asset_directory}
        fi
	done
fi

if ( [ "`/bin/mount  | /bin/grep -P "${asset_directory}(?=\s|$)"`" = "" ] )
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

	/usr/bin/s3fs ${options} ${asset_bucket} ${asset_directory}

	if ( [ "`/bin/mount  | /bin/grep -P "${asset_directory}(?=\s|$)"`" != "" ] )
	then
		if ( [ ! -f /var/www/s3-${asset_directory}/FIRST_MOUNT_INITIALISED ]
		then
			/bin/touch /var/www/s3-${asset_directory}/FIRST_MOUNT_INITIALISED
			/bin/cp -r `/bin/echo /var/www/html/
fi
