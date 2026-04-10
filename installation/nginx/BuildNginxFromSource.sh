#!/bin/sh
######################################################################################################
# Description: This will install and compile nginx from source code. This has the advantage that its
# the latest version of nginx will be used when sometimes repositories can use more dated versions.
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
MOD_SECURITY="`${HOME}/utilities/config/ExtractConfigValue.sh 'MODSECURITY'`"
NO_REVERSE_PROXY="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"

cwd=`/usr/bin/pwd`
cd /usr/local/src/

nginx_git_branch="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:git-branch" "stripped"`"
nginx_sourcecode_url="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:sourcecode_url" "stripped"`"

if ( [ "${nginx_git_branch}" != "" ] )
then
        if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:fork:f5'`" = "1" ] )
        then
                ${HOME}/services/git/GitClone.sh "github" "" "nginx" "nginx" "" "${nginx_git_branch}"
        elif ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:fork:free'`" = "1" ] )
        then
                ${HOME}/services/git/GitClone.sh "github" "" "freenginx" "nginx" "" "${nginx_git_branch}"
        fi
elif ( [ "${nginx_sourcecode_url}" != "" ] )
then
        if ( [ "`${HOME}/utilities/config/CheckBuildStyle.sh 'NGINX:fork:free'`" = "1" ] )
        then
                nginx_archive_name="`/bin/echo ${nginx_sourcecode_url} | /usr/bin/awk -F'/' '{print $NF}'`"
                /usr/bin/wget ${nginx_sourcecode_url}
                /bin/mkdir /usr/local/src/working
                /bin/tar zxvf ${nginx_archive_name} -C /usr/local/src/working
                /bin/rm *nginx*
                /bin/mv /usr/local/src/working/* /usr/local/src
                /bin/rm -r /usr/local/src/working
        else
                nginx_archive_name="`/bin/echo ${nginx_sourcecode_url} | /usr/bin/awk -F'/' '{print $NF}'`"
                /usr/bin/wget ${nginx_sourcecode_url}
                /usr/bin/wget ${nginx_sourcecode_url}.asc
                public_key="`/usr/bin/gpg ${nginx_archive_name}.asc 2>&1 | /bin/grep 'using RSA key' | /usr/bin/awk '{print $NF}'`"
                /bin/chown -R `/usr/bin/whoami` ${HOME}/.gnupg/
                /bin/chmod 600 ${HOME}/.gnupg/*
                /bin/chmod 700 ${HOME}/.gnupg
                /usr/bin/wget https://nginx.org/keys/nginx_signing.key
              #  /usr/bin/gpg --keyserver hkps://keys.openpgp.org --recv-keys ${public_key}
                signer_email="`/usr/bin/gpg --keyserver hkps://keys.openpgp.org --recv-keys ${public_key} 2>&1 | /bin/grep "gpg: key" | /bin/sed -e 's/.*<//g' -e 's/>.*//g'`"
               # /usr/bin/wget https://nginx.org/keys/nginx_signing.key
                /usr/bin/gpg --import nginx_signing.key

                /bin/echo -e "4\ny\n" | /usr/bin/gpg --command-fd 0 --expert --edit-key "${signer_email}" trust

                if ( [ "`/usr/bin/gpg --verify ./${nginx_archive_name}.asc ${nginx_archive_name} 2>&1 | /bin/grep "Good signature" | /bin/grep "r.arutyunyan@f5.com"`" = "" ] )
                then
                        exit
                else
                        /bin/mkdir /usr/local/src/working
                        /bin/tar zxvf ${nginx_archive_name} -C /usr/local/src/working
                        /bin/rm nginx*
                        /bin/mv /usr/local/src/working/* /usr/local/src
                        /bin/rm -r /usr/local/src/working
                fi
        fi

        /bin/mv *nginx-* nginx
fi

cd nginx

##############################################################################################################################################
#Alternative installation source (comment the two lines above and uncomment the lines here to use the alternative source to github (nginx.org))
##############################################################################################################################################
#nginx_latest_version="`/usr/bin/curl 'http://nginx.org/download/' |   /bin/egrep -o 'nginx-[0-9]+\.[0-9]+\.[0-9]+' | /bin/sed 's/nginx-//g' |  /usr/bin/sort --version-sort | /usr/bin/uniq | /usr/bin/tail -1`"
#/usr/bin/wget https://nginx.org/download/nginx-${nginx_latest_version}.tar.gz 
#/usr/bin/wget https://nginx.org/download/nginx-${nginx_latest_version}.tar.gz.asc
#/usr/bin/wget https://nginx.org/keys/pluknet.key
#/usr/bin/gpg --import /usr/local/src/pluknet.key

#if ( [ "`/usr/bin/gpg --verify /usr/local/src/nginx-${nginx_latest_version}.tar.gz.asc /usr/local/src/nginx-${nginx_latest_version}.tar.gz 2>&1 | /bin/grep 'Good signature from'`" = "" ] )
#then
#        exit
#fi

#/bin/tar zxvf nginx-${nginx_latest_version}.tar.gz
#/bin/rm nginx-${nginx_latest_version}.tar.gz
#cd nginx-${nginx_latest_version}
#############################################################################################################################################

if ( [ ! -f /etc/nginx/modules.conf ] )
then
        /bin/touch /etc/nginx/modules.conf
else
        /bin/cp /dev/null /etc/nginx/modules.conf
fi

mod_security_module="" 

if ( ( [ "${MOD_SECURITY}" = "1" ] && [ "${NO_REVERSE_PROXY}" = "0" ] && [ "`/usr/bin/hostname | /bin/grep '^ws-'`" != "" ] ) || ( [ "${MOD_SECURITY}" = "1" ] && ( [ "${NO_REVERSE_PROXY}" = "1" ] && [ "`/usr/bin/hostname | /bin/grep '\-rp-'`" != "" ] ) || ( [ "${MOD_SECURITY}" = "1" ] && [ "`/usr/bin/hostname | /bin/grep '\-auth-'`" != "" ] ) ) )
then
        mod_security_module="--add-module=/opt/ModSecurity-nginx"
fi

#Get the list of any custom modules that we want to compile with, if there are none, perform a default build
static_nginx_modules="`${HOME}/utilities/config/ExtractBuildStyleValues.sh "NGINX:static-modules-list" "stripped" | /bin/sed -e 's/:/ /g' -e 's/source//g' -e 's/static-modules-list//g' -e 's/^ //'`" 

if ( [ "${static_nginx_modules}" != "" ] )
then
        with_static_modules=""
        for module in ${static_nginx_modules}
        do
                with_static_modules=${with_static_modules}" --with-${module}_module"
        done
        options=" --prefix=/var/www/html --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --modules-path=/etc/nginx/modules  --pid-path=/etc/nginx/nginx.pid --lock-path=/etc/nginx/nginx.lock --user=www-data --group=www-data --http-log-path=/var/log/nginx/access.log ${with_static_modules}"
else
        options=" --prefix=/var/www/html --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --modules-path=/etc/nginx/modules  --pid-path=/etc/nginx/nginx.pid --lock-path=/etc/nginx/nginx.lock --user=www-data --group=www-data --with-threads --with-file-aio --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_mp4_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_secure_link_module --with-http_slice_module --with-http_stub_status_module --http-log-path=/var/log/nginx/access.log --with-stream --with-stream_ssl_module --with-stream_realip_module --with-compat --with-pcre-jit"
fi

if ( [ -f /usr/local/src/nginx/auto/configure ] )
then
        ./auto/configure ${options} ${mod_security_module}
else
        ./configure ${options} ${mod_security_module}
fi

/usr/bin/make -j4
/usr/bin/make install

#Make nginx avaiable as a service and enable and start it
if ( [ -f ${HOME}/installation/nginx/nginx.service ] )
then 
        /bin/cp ${HOME}/installation/nginx/nginx.service /lib/systemd/system/nginx.service
        /bin/chmod 644 /lib/systemd/system/nginx.service
fi

ls -l /var/www/html > /tmp/ls

${HOME}/utilities/processing/RunServiceCommand.sh nginx enable
${HOME}/utilities/processing/RunServiceCommand.sh nginx start

cd ..
#Cleanup
/bin/rm -r nginx-${nginx_latest_version}

cd ${cwd}

/bin/touch /etc/nginx/BUILT_FROM_SOURCE
/bin/touch ${HOME}/runtime/installedsoftware/InstallNGINX.sh
