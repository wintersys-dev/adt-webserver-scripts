#!/bin/sh

#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] )
then
        status "Error: 4 arguments are required with 1 optional argument"
        status "Usage: $0 <repository_ownername> <repository_name> <repository_branch> <destination_directory> [repository_username]"
        exit 1
fi

repository_ownername="${1}"
repository_name="${2}"
branch_command="${3}"
destination_directory="${4}"
repository_username="${5}"


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

/usr/bin/git clone --depth 1 ${branch_command} https://github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}

/bin/rm ${HOME}/.netrc

