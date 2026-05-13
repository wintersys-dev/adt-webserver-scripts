source="$1"
destination_bucket="$2"
count="$3"


if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:s3cmd'`" = "1" ] )
then
        datastore_tool="/usr/bin/s3cmd"
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:s5cmd'`" = "1" ]  )
then
        datastore_tool="/usr/bin/s5cmd"
elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'DATASTORETOOL:rclone'`" = "1" ]  )
then
        datastore_tool="/usr/bin/rclone"
fi

if ( [ "${datastore_tool}" = "/usr/bin/s3cmd" ] )
then
        host_base="`/bin/grep ^host_base --no-delete-removed /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="${datastore_tool} --config=/root/.s3cfg-${count} --host=https://${host_base} sync ${source}/"
elif ( [ "${datastore_tool}" = "/usr/bin/s5cmd" ] )
then
        host_base="`/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="${datastore_tool} --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} sync ${source}/"
elif ( [ "${datastore_tool}" = "/usr/bin/rclone" ] )
then
        host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
        datastore_cmd="${datastore_tool} --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} copy ${source}/"
fi

${datastore_cmd}  s3:${destination_bucket}/
