#!/bin/sh

set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Repository username and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_username> <repository_name>" >&2
        exit 1
fi

repository_username="${1}"
repository_name="${2}"

software_file="${HOME}/runtime/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}" >&2
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

#git_provider="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYPROVIDER')"
#if [ -z "${git_provider}" ]
#then
#        /bin/echo "Error: GIT_PROVIDER not found in ${software_file}" >&2
#        exit 1
#fi

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(${HOME}/services/git/bitbucket/${orchestration_tool}/create_repository.sh "${repository_username}" "${repository_name}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r '.links.clone[] | select(.name == "https").href')"

        if [ -z "${output}" ]
        then
                /bin/echo "Error: Repository created, but no HTTPS clone URL found for ${repository_username}/${repository_name}." >&2
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        /bin/echo "Network request failed. Check your API token, email, or repository name." >&2
        exit 1
fi

exit 0
