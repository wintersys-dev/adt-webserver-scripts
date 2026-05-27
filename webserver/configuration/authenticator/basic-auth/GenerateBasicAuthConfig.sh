#!/bin/sh

#set -x

WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURLORIGINAL'`"
USER_EMAIL_DOMAIN="`${HOME}/utilities/config/ExtractConfigValue.sh 'USEREMAILDOMAIN'`"
machine_ip="`${HOME}/utilities/processing/GetIP.sh`"

if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator 
fi

basic_auth_file="${HOME}/runtime/authenticator/basic-auth.dat"
basic_auth_previous_credentials="${HOME}/runtime/authenticator/previous-basic-auth-credentials.dat"

/bin/touch ${basic_auth_previous_credentials}

if ( [ -f /var/www/basic-auth/basic-auth.dat ] )
then
        /bin/mv /var/www/basic-auth/basic-auth.dat ${basic_auth_file}.$$
else
        exit
fi

for data in `/bin/cat ${basic_auth_file}.$$`
do
        username="`/bin/echo ${data} | /usr/bin/awk -F':' '{print $1}'`"
        previous_password="`/bin/echo ${data} | /usr/bin/awk -F':' '{print $2}'`"
        password="p`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-z0-9' | /usr/bin/cut -b 1-8`p"

        if ( [ "`/bin/echo ${username} | /bin/grep "${USER_EMAIL_DOMAIN}$"`" != "" ] && [ "${previous_password}" != "" ] )
        then
                if ( [ ! -f ${basic_auth_file} ] )
                then
                        /usr/bin/htpasswd -b -c ${basic_auth_file} ${username} ${password}
                else
                        /bin/sed -i "/^${username}:/d" ${basic_auth_file}
                        /usr/bin/htpasswd -b ${basic_auth_file} ${username} ${password}
                fi
            #    /bin/sed -i "s/^${username}:/NEW:${previous_password}:${password}:${username}:/g" ${basic_auth_file}
                message="<!DOCTYPE html> <html> <body> <h1>The basic auth password you requested for ${WEBSITE_URL} is: ${password} </body> </html>"
                ${HOME}/services/email/SendEmail.sh "Basic Auth password request" "${message}" MANDATORY ${username} "HTML" "AUTHENTICATION"
                /bin/cp ${basic_auth_file} ${basic_auth_file}.${machine_ip}
                ${HOME}/services/datastore/operations/MountDatastore.sh "basic-auth-credentials" "distributed" 
                ${HOME}/services/datastore/operations/PutToDatastore.sh "basic-auth-credentials" ${basic_auth_file}.${machine_ip} "basic-auth-credentials" "distributed" "no"
                /bin/rm ${basic_auth_file}.${machine_ip}
        fi
done
