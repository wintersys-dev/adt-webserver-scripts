WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
#application_asset_dirs="`${HOME}/utilities/config/ExtractConfigValues.sh 'DIRECTORIESTOMOUNT' 'stripped' | /bin/sed 's/:/ /g'`"

application_asset_dirs=""
application_asset_buckets=""
application_asset_dirs="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"


if ( [ "${application_asset_dirs}" != "" ] )
then
        for directory in ${application_asset_dirs}
        do
                asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g'`"
                destinations="`/bin/grep "^\[s3_" /root/.config/rclone/rclone.multi.conf | /bin/sed '/^\[s3_1]/d' | /bin/sed -e 's/\[//' -e 's/\]//'`"

                for destination in ${destinations}
                do
                        /usr/bin/rclone --config /root/.config/rclone/rclone.multi.conf mkdir ${destination}:${asset_bucket}
                        /usr/bin/rclone --config /root/.config/rclone/rclone.multi.conf sync s3_1:${asset_bucket} ${destination}:${asset_bucket}
                done
        done
fi
