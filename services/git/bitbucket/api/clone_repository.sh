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
ATLASSIAN_EMAIL="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYEMAIL')"
set -e

if [ -z "${REPOSITORY_TOKEN}" ] || [ -z "${ATLASSIAN_EMAIL}" ]
then
        /bin/echo "Error: Failed to fetch required context variables (APPLICATIONREPOSITORYTOKEN or APPLICATIONREPOSITORYEMAIL)." >&2
        exit 1
fi

# Create a temporary file for the downloaded tarball and ensure cleanup on exit
tmp_archive="$(/bin/mktemp /tmp/repo_archive.XXXXXX.tar.gz)"

cleanup() {
        /bin/rm -f "${tmp_archive}"
}
trap cleanup EXIT INT TERM


api_base="https://bitbucket.org"
repo_endpoint="${repository_ownername}/${repository_name}/get/${branch}.tar.gz"

set +e
HTTP_CODE=$(/usr/bin/printf 'user = "%s:%s"\n' "${ATLASSIAN_EMAIL}" "${REPOSITORY_TOKEN}" | \
        /usr/bin/curl -s -L -K - \
        -o "${tmp_archive}" \
        -w "%{http_code}" \
        "${api_base}/${repo_endpoint}")
set -e


# Evaluate the HTTP response code using strict POSIX structural matching
case "${HTTP_CODE}" in
        200)
                /bin/mkdir -p "${destination_directory}"
                set +e
                # Bitbucket archives wrap files in a top-level "<owner>-<repo>-<commit>/" folder; --strip-components=1 flattens it
                /bin/tar -xzf "${tmp_archive}" -C "${destination_directory}" --strip-components=1 2>&1 >&2
                tar_status="$?"
                set -e

                if [ "${tar_status}" -ne 0 ]
                then
                        /bin/echo "Error: Failed to extract repository archive into ${destination_directory}." >&2
                        exit 1
                fi

                /bin/echo "${destination_directory}"
                exit 0
                ;;
        400)
                /bin/echo "Error 400: Bad Request. Check branch or repository parameter syntax." >&2
                exit 400
                ;;
        401)
                /bin/echo "Error 401: Unauthorized. Your REPOSITORY_TOKEN is invalid or has expired." >&2
                exit 401
                ;;
        403)
                /bin/echo "Error 403: Forbidden. Token lacks read permissions for ${repository_ownername}/${repository_name}." >&2
                exit 403
                ;;
        404)
                /bin/echo "Error 404: Not Found. Repository ${repository_ownername}/${repository_name} or branch '${branch}' does not exist." >&2
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
                exit 1
                ;;
esac

exit 0
