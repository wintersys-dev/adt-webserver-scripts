#!/bin/sh

set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Repository username and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_username> <repository_name>" >&2
        exit 1
fi

repository_username="${1}"
repository_name="${2}"

set +e
REPOSITORY_TOKEN="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYTOKEN')"
ATLASSIAN_EMAIL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYEMAIL')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN or APPLICATIONREPOSITORYEMAIL)." >&2
        exit 1
fi

# Build the full API endpoint and JSON payload beforehand
api_base="https://api.bitbucket.org/2.0"
endpoint_url="${api_base}/repositories/${repository_username}/${repository_name}"
payload='{"scm": "git", "is_private": true, "fork_policy": "no_public_forks"}'

set +e
# Pipe netrc credentials via /dev/stdin to prevent disk writes or exposure in process trees
RESPONSE=$(/bin/echo "machine api.bitbucket.org login ${ATLASSIAN_EMAIL} password ${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s -X POST --netrc-file /dev/stdin \
        -H "Content-Type: application/json" \
        "${endpoint_url}" \
        -d "${payload}" \
        -w "\nHTTP_STATUS:%{http_code}")
set -e

# Extract the HTTP status code using strict POSIX filtering
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Repository may already exist or payload syntax is invalid." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 400
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your REPOSITORY_TOKEN or ATLASSIAN_EMAIL is invalid or has expired." >&2
                exit 401
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Token lacks permissions to create repositories in this workspace." >&2
                exit 403
                ;;
        404)
                /bin/echo "Error 404: Not Found. The target workspace or user (${repository_username}) does not exist." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 404
                ;;
        429)
                /bin/echo "Error 429: Rate Limit Exceeded. Back off request frequency." >&2
                exit 429
                ;;
        5*)
                /bin/echo "Error ${HTTP_CODE}: Bitbucket Gateway or Remote Server Exception." >&2
                exit 500
                ;;
        *)
                /bin/echo "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code." >&2
                /bin/echo "API Detail: ${RESPONSE_BODY}" >&2
                exit 1
                ;;
esac

exit 0

