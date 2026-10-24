#!/bin/sh

branch_command="${1}"
repository_provider="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
destination_directory="${6}"


auth_base64=$(printf "oauth2:%s" "$REPOSITORY_TOKEN" | base64)

/usr/bin/git clone --depth 1 ${branch_command} -c http.extraHeader="Authorization: Basic ${auth_base64}" "https://gitlab.com/${repository_ownername}/${repository_name}.git" "${destination_directory}"

#/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${REPOSITORY_TOKEN}@gitlab.com/${repository_ownername}/${repository_name}.git  ${destination_directory}


