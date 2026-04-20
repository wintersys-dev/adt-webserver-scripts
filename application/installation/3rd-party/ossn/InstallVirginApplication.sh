#!/bin/sh
#####################################################################################
# Description: This script will download and unpack joomla. The source url for which
# version of joomla to use is set in  
# ${BUILD_HOME}/application/descriptors/joomla.dat
# And this can be set to any valid URL of your choosing which includes alpha, beta and
# release candidate archives of joomla.
# Tar achives and zip archives are supported and which is used depends on the setting in
# ${BUILD_HOME}/application/descriptors/joomla.dat. 
# The archives have checksum verifications applied so you have to supply the expected
# and valid checksum(s) for your archive in 
# ${BUILD_HOME}/application/descriptors/joomla.dat.
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
set -x

if ( [ ! -d ${HOME}/logs/application_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/application_installation
fi

exec 1>>${HOME}/logs/application_installation/ossn_out.log
exec 2>>${HOME}/logs/application_installation/ossn_err.log

if ( [ ! -d ${HOME}/runtime/downloads_work_area ] )
then
        /bin/mkdir -p ${HOME}/runtime/downloads_work_area
fi

/bin/rm -r ${HOME}/runtime/downloads_work_area/*

cd ${HOME}/runtime/downloads_work_area

ossn_git_branch="`/bin/grep "^OSSN:git-branch:" ${HOME}/runtime/application.dat | /bin/sed 's/OSSN:git-branch://g'`"

if ( [ "${ossn_git_branch}" != "" ] )
then
        ${HOME}/services/git/GitClone.sh "github" "" "opensource-socialnetwork" "opensource-socialnetwork" "" "${ossn_git_branch}" "/var/www/html/ossn"
        /bin/chown -R www-data:www-data /var/www/html
else
        checksum="0"
        if ( [ "`/bin/grep "^SOURCECODE_URL:ossn" ${HOME}/runtime/application.dat | /bin/grep 'opensource-socialnetwork.org'`" != "" ] )
        then
                SOURCECODE_URL="`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_URL://g' | /bin/sed 's/:/ /g'`"
        elif ( [ "`/bin/grep "^SOURCECODE_URL:github" ${HOME}/runtime/application.dat | /bin/grep 'github.com'`" != "" ] )
        then
                checksum="1"
                SOURCECODE_URL="`/bin/grep "^SOURCECODE_URL" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_URL://g' | /bin/sed 's/:/ /g'`"
                SOURCECODE_SHA256="`/bin/grep "^SOURCECODE_SHA256" ${HOME}/runtime/application.dat | /bin/sed 's/SOURCECODE_SHA256://g' | /bin/sed 's/:/ /g'`"
        fi

        archive_type=""
        if ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.zip$'`" != "" ] )
        then
                archive_type="zip"
        elif ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.tar.gz$'`" != "" ] )
        then
                archive_type="tar.gz"
        fi

        /usr/bin/wget https://${SOURCECODE_URL} -O ossn.${archive_type}
        /bin/echo "${0} `/bin/date`: Downloaded ossn from ${SOURCECODE_URL}" 

        verified_archive_type=""
        if ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.zip$'`" != "" ] && ( [ "${checksum}" = "0"  ] || [ "`/usr/bin/sha256sum ossn.zip | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA256}" ] ) )
        then
                verified_archive_type="${archive_type}"
        elif ( [ "`/bin/echo ${SOURCECODE_URL} | /bin/grep '\.tar.gz$'`" != "" ] && ( [ "${checksum}" = "0"  ] || [ "`/usr/bin/sha256sum ossn.tar.gz | /usr/bin/awk '{print $1}'`" = "${SOURCECODE_SHA256}" ] ) )
        then
                verified_archive_type="${archive_type}"
        fi

        webroot_directory="`/bin/grep "^WEBROOT_DIRECTORY:" ${HOME}/runtime/application.dat | /usr/bin/awk -F':' '{print $NF}'`"

        if ( [ "${webroot_directory}" = "" ] )
        then
                webroot_directory="/var/www/html/ossn"
        fi

        if ( [ ! -d ${webroot_directory} ] )
        then
                /bin/mkdir -p ${webroot_directory}
                /bin/chown www-data:www-data ${webroot_directory}
                /bin/chmod 755 ${webroot_directory}
        fi

        if ( [ "${verified_archive_type}" != "" ] )
        then
                if ( [ "${verified_archive_type}" = "zip" ] )
                then
                        /usr/bin/python3 -m zipfile -e ossn.${verified_archive_type} /var/www/html
                elif ( [ "${verified_archive_type}" = "tar.gz" ] )
                then
                        /bin/tar xvfz ossn.${verified_archive_type} -C /var/www/html
                fi
                /bin/rm ossn.${verified_archive_type}
                /bin/chown -R www-data:www-data ${webroot_directory}/*
        fi
fi

cd ${HOME}
/bin/echo "success"

