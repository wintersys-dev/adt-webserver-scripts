#!/bin/sh

branch_command="${1}"
repository_provider="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
destination_directory="${6}"


/usr/bin/git clone --depth 1 ${branch_command} -c http.extraHeader="Authorization: Bearer ${auth}" "https://bitbucket.org/${repository_ownername}/${repository_name}.git" "${destination_directory}"

#/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${REPOSITORY_TOKEN}@bitbucket.org/${repository_ownername}/${repository_name}.git  ${destination_directory}


#get the below working and test

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=http.extraheader
export GIT_CONFIG_VALUE_0="Authorization: Basic $(printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | base64 -w0)"

git clone \
  --depth 1 \
  --branch "$branch" \
  -- "https://bitbucket.org/${repository_ownername}/${repository_name}.git" \
  "$destination_directory"

unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
