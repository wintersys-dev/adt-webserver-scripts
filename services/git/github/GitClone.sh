#!/bin/sh

#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ]  )
then
        status "Error: 3 arguments are required with 3 optional arguments"
        status "Usage: $0 <repository_provider> <repository_ownername> <repository_name>  [repository_username] [repository_branch] [destination_directory]"
        exit 1
fi

repository_provider="${1}"
repository_ownername="${2}"
repository_username="${3}"
branch_command="${4}"
repository_name="${5}"
destination_directory="${6}"

#take this out and pass it through export from the highest level
#APPLICATION_REPOSITORY_TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN'`"
#export REPOSITORY_TOKEN="${APPLICATION_REPOSITORY_TOKEN}"

cat << EOF > ${HOME}/.netrc
machine github.com
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

#I only use the .netrc file for git commands and I construct it and remove it every time I want to use it
#if I need a .netrc file for curl (for example) I construct a custom file name and use the custom file so there is no clash
chmod 600 ${HOME}/.netrc

#/usr/bin/git clone --depth 1 ${branch_command} https://github.com{repository_ownername}/

/usr/bin/git clone --depth 1 ${branch_command} https://github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}

/bin/rm ${HOME}/.netrc



#APPLICATION_REPOSITORY_TOKEN="`${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN'`"
#export REPOSITORY_TOKEN="${APPLICATION_REPOSITORY_TOKEN}"

#if ( [ "${REPOSITORY_TOKEN}" != "" ] )
#then
#        REPOSITORY_TOKEN=":${REPOSITORY_TOKEN}"
#fi

#this works but might not be secure
#/usr/bin/git clone -c http.extraheader="AUTHORIZATION: basic $(printf '%s' "x-access-token:${REPOSITORY_TOKEN}" | base64 -w0)" --depth 1 ${branch_command} https://${repository_username}@github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}

#/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${REPOSITORY_TOKEN}@github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}
