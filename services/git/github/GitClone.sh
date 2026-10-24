#!/bin/sh
##################################################################################
# Script Name : GitClone.sh
# Description : Executes a shallow Git clone operation (depth = 1) for a specific 
#               GitHub repository using an authenticated HTTPS URL and custom
#               branch/destination configurations.
#
# Usage       : ./GitCloneExecution.sh "<branch_command>" \
#                                      <repository_provider> \
#                                      <repository_username> \
#                                      <repository_ownername> \
#                                      <repository_name> \
#                                      <destination_directory>
#
# Arguments   : $1 - branch_command         (e.g., "-b main" or empty string)
#               $2 - repository_provider     (Expected to be "github")
#               $3 - repository_username     (GitHub account username)
#               $4 - repository_ownername    (Repository owner or organization name)
#               $5 - repository_name         (Target repository name)
#               $6 - destination_directory   (Local path for the cloned repo)
#
# Dependencies: Requires system access to /usr/bin/git
##################################################################################
#set -x 
set -e

HOME="`/bin/cat /home/homedir.dat`"


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
