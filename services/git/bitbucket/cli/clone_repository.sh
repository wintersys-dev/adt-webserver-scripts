#!/bin/sh

set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        /bin/echo "Error: Branch, repository owner, repository name, and destination directory are required." >&2
        /bin/echo "Usage: $0 <branch> <repository_ownername> <repository_name> <destination_directory>" >&2
        exit 1
fi

# Strip optional "--branch " prefix so both "main" and "--branch main" inputs work cleanly
branch="$(/bin/echo "${1}" | /usr/bin/sed 's/^--branch[[:space:]]*//')"
repository_ownername="${2}"
repository_name="${3}"
destination_directory="${4}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] 
then
        /bin/echo "Error: Failed to fetch required context variable APPLICATIONREPOSITORYTOKEN ." >&2
        exit 1
fi

encoded_auth="$(/usr/bin/printf '%s' "x-bitbucket-api-token-auth:${REPOSITORY_TOKEN}" | /usr/bin/base64 -w0)"
unset REPOSITORY_TOKEN

if [ -z "${encoded_auth}" ]
then
        /bin/echo "Error: Failed to encode Bitbucket authentication header." >&2
        exit 1
fi

# Export transient Git HTTP header configuration to avoid exposing tokens in process trees
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.extraheader"
export GIT_CONFIG_VALUE_0="Authorization: Basic ${encoded_auth}"

set +e
/usr/bin/git clone \
        --depth 1 \
        --branch "${branch}" \
        -- "https://bitbucket.org/${repository_ownername}/${repository_name}.git" \
        "${destination_directory}" >&2
git_status="$?"
set -e

# Immediately scrub sensitive environment variables
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 encoded_auth REPOSITORY_TOKEN

if [ "${git_status}" -ne 0 ]
then
        /bin/echo "Error: Git clone failed for ${repository_ownername}/${repository_name} on branch ${branch} (exit code: ${git_status})." >&2
        exit "${git_status}"
fi

/bin/echo "${destination_directory}"
exit 0
