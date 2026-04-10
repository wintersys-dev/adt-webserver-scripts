#!/bin/sh
######################################################################################################
# Description: This will install and compile lighttpd from source code. This has the advantage that its
# the latest version of lighttpd will be used when sometimes repositories can use more dated versions.
# You also have control over what features of apache are intalled by varying the options which are 
# used during the compilation. You can configure custom options by modifying the file:
#
#  ${BUILD_HOME}/builddescriptors/buildstylesscp.dat
#
# on the your build machine. 
# Author: Peter Winter
# Date: 17/01/2017
#######################################################################################################
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
#######################################################################################################
#######################################################################################################
#set -x

export HOME=`/bin/cat /home/homedir.dat`
BUILDOS="`${HOME}/utilities/config/ExtractConfigValue.sh 'BUILDOS'`"

cwd="`/usr/bin/pwd`"

cd /usr/local/src/

lighttpd_git_branch="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:git-branch" "stripped"`"

lighttpd_sourcecode_url="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:sourcecode_url" "stripped"`"
lighttpd_sha256_url="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:sha256_url" "stripped"`"
lighttpd_sha512_url="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:sha512_url" "stripped"`"

if ( [ "${lighttpd_git_branch}" != "" ] )
then
    /usr/bin/git config --global advice.detachedHead false
    ${HOME}/services/git/GitClone.sh "github" "" "lighttpd" "lighttpd1.4" "" "${lighttpd_git_branch}"
elif ( [ "${lighttpd_sourcecode_url}" != "" ] )
then
        /usr/bin/wget ${lighttpd_sourcecode_url}
        /usr/bin/wget ${lighttpd_sha256_url}
        /usr/bin/wget ${lighttpd_sha512_url}

        lighttpd_sourcecode_file="`/bin/echo ${lighttpd_sourcecode_url} | /usr/bin/awk -F'/' '{print $NF}'`"
        lighttpd_sha256_file="`/bin/echo ${lighttpd_sha256_url} | /usr/bin/awk -F'/' '{print $NF}'`"
        lighttpd_sha512_file="`/bin/echo ${lighttpd_sha512_url} | /usr/bin/awk -F'/' '{print $NF}'`"
        verified="no"
        if ( [ "`/usr/bin/sha256sum --check /usr/local/src/${lighttpd_sha256_file} | /bin/grep "OK"`" != "" ] )
        then
                verified="yes"
        fi

        if ( [ "`/usr/bin/sha512sum --check /usr/local/src/${lighttpd_sha512_file} | /bin/grep "OK"`" != "" ] )
        then
                verified="yes"
        fi

        if ( [ "${verified}" = "no" ] )
        then
                exit
        fi

        /bin/tar -xvzf /usr/local/src/${lighttpd_sourcecode_file} -C /usr/local/src
        /bin/rm /usr/local/src/*tar* /usr/local/src/*sha*
        /bin/mv  /usr/local/src/lighttpd* /usr/local/src/lighttpd1.4

fi

cd lighttpd1.4

/bin/sed -i 's/trap/#trap/g' ./autogen.sh #was getting a "bad trap error from this script
./autogen.sh

lighttpd_modules="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:modules-list" "stripped" | /bin/sed 's/|.*//g'`"

if ( [ "${lighttpd_modules}" != "" ] )
then
    if ( [ ! -d /etc/lighttpd ] )
    then
        /bin/mkdir /etc/lighttpd
    fi

    /bin/echo "server.modules = (" > /etc/lighttpd/modules.conf

    for module in ${lighttpd_modules}
    do
        /bin/echo '"'${module}'",' >> /etc/lighttpd/modules.conf
    done

    /usr/bin/truncate -s -2 /etc/lighttpd/modules.conf
    /bin/echo "" >> /etc/lighttpd/modules.conf
    /bin/echo ")" >> /etc/lighttpd/modules.conf
fi

#Get any lise of custom mulues that we are installing and compile with the custom modules if there are any or compile a default build if not
static_lighttpd_modules="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "LIGHTTPD:static-modules-list" "stripped"`"    

if ( [ "${static_lighttpd_modules}" != "" ] )
then
    with_modules=""
    for module in ${static_lighttpd_modules}
    do
        with_modules=${with_modules}" --with-${module} "
    done
    ./configure -C --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include --libdir=/usr/lib --disable-ipv6  ${with_modules}
else
    ./configure -C --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include --libdir=/usr/lib --with-zlib --with-libxml --with-openssl --disable-ipv6 
fi

/usr/bin/make
/usr/bin/make install 

if ( [ ! -d  /etc/lighttpd  ] )
then
    /bin/mkdir /etc/lighttpd        
fi

if ( [ ! -d  /var/log/lighttpd  ] )
then
    /bin/mkdir /var/log/lighttpd
fi

/bin/chown www-data:www-data /var/log/lighttpd

#Make lighttpd is avaiable as a service and enable and start it
if ( [ -f ${HOME}/installation/lighttpd/lighttpd.service ] )
then 
        /bin/cp ${HOME}/installation/lighttpd/lighttpd.service /lib/systemd/system/lighttpd.service
        /bin/chmod 644 /lib/systemd/system/lighttpd.service
fi

${HOME}/utilities/processing/RunServiceCommand.sh lighttpd enable
${HOME}/utilities/processing/RunServiceCommand.sh lighttpd start

cd ${cwd}

/bin/touch /etc/lighttpd/BUILT_FROM_SOURCE	
/bin/touch ${HOME}/runtime/installedsoftware/InstallLighttpd.sh				


