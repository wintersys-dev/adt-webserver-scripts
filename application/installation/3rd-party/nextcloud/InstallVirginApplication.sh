#!/bin/sh
#####################################################################################
# Description: This script will download and unpack nextcloud. The source url for which
# version of nextcloud to use is set in  
# ${BUILD_HOME}/application/descriptors/nextcloud.dat
# And this can be set to any valid URL of your choosing which includes alpha, beta and
# release candidate archives of nextcloud.
# Tar achives and zip archives are supported and which is used depends on the setting in
# ${BUILD_HOME}/application/descriptors/nextcloud.dat. 
# The archives have checksum verifications applied so you have to supply the expected
# and valid checksum(s) for your archive in 
# ${BUILD_HOME}/application/descriptors/nextcloud.dat.
# Author: Peter Winter
# Date: 04/01/2017
######################################################################################
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
######################################################################################
######################################################################################
#set -x

if ( [ ! -d ${HOME}/logs/application_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/application_installation
fi

exec 1>>${HOME}/logs/application_installation/nextcloud_out.log
exec 2>>${HOME}/logs/application_installation/nextcloud_err.log

if ( [ ! -d ${HOME}/runtime/downloads_work_area ] )
then
        /bin/mkdir -p ${HOME}/runtime/downloads_work_area
fi

/bin/rm -r ${HOME}/runtime/downloads_work_area/*

cd ${HOME}/runtime/downloads_work_area

checksum="0"
if ( [ "`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/grep 'github.com'`" != "" ] )
then
        SOURCECODE_URL="`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_URL://g' | /bin/sed 's/:/ /g'`"
elif ( [ "`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/grep 'nextcloud.com'`" != "" ] )
then
        checksum="1"
        SOURCECODE_URL="`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_URL://g' | /bin/sed 's/:/ /g'`"
        SOURCECODE_SHA256="`/bin/grep "^SOURCECODE_SHA256" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_SHA256://g' | /bin/sed 's/:/ /g'`"
        SOURCECODE_SHA512="`/bin/grep "^SOURCECODE_SHA512" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_SHA512://g' | /bin/sed 's/:/ /g'`"
fi

archive_type=""
if ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.zip$'`" != "" ] )
then
        archive_type="zip"
elif ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.tar.bz2$'`" != "" ] )
then
        archive_type="tar.bz2"
fi

/usr/bin/wget https://${SOURCECODE_URL} -O nextcloud.${archive_type}
/bin/echo "${0} `/bin/date`: Downloaded nextcloud from ${SOURCECODE_URL}" 

verified_archive_type=""
if ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.zip$'`" != "" ] && ( [ "${checksum}" = "0" ] || ( [ "`/usr/bin/sha256sum nextcloud.zip | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA256}" ] || [ "`/usr/bin/sha512sum nextcloud.zip | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA512}" ] ) ) )
then
        verified_archive_type="${archive_type}"
elif ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.tar.bz2$'`" != "" ] && ( [ "${checksum}" = "0" ] || ( [ "`/usr/bin/sha256sum nextcloud.tar.bz2 | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA256}" ] || [ "`/usr/bin/sha512sum nextcloud.tar.bz2 | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA512}" ] ) ) )
then
        verified_archive_type="${archive_type}"
fi

if ( [ "${verified_archive_type}" != "" ] )
then
        if ( [ "${verified_archive_type}" = "zip" ] )
        then
                /usr/bin/python3 -m zipfile -e nextcloud.${verified_archive_type} /var/www/html
        elif ( [ "${verified_archive_type}" = "tar.bz2" ] )
        then
                BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"
                ${HOME}/installation/InstallBzip2.sh
                /bin/tar xvjf nextcloud.${verified_archive_type} -C /var/www/html
        fi
        /bin/rm nextcloud.${verified_archive_type}
        /bin/chown -R www-data:www-data /var/www/html
fi

cd ${HOME}
/bin/echo "success"
