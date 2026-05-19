#!/bin/sh

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
S3_HOST_BASE="`${HOME}/utilities/config/ExtractConfigValue.sh 'S3HOSTBASE'`"
application_asset_dirs="`/bin/grep "^WEBROOT_ASSET_DIRECTORIES:" ${HOME}/runtime/application.dat | /bin/sed 's/WEBROOT_ASSET_DIRECTORIES://g' | /bin/sed 's/:/ /g'`"

for application_assets_directory in ${application_asset_dirs}
do
        asset_bucket="`/bin/echo "${WEBSITE_URL}-assets-${application_assets_directory}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g' -e 's/_/-/g'`"
        full_bucket_url="${asset_bucket}.${S3_HOST_BASE}"
done
