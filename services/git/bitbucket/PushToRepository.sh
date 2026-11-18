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
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: Missing required arguments." >&2
        /bin/echo "Usage: $0 <source_directory> <branch> <repository_username> <repository_ownername> <repository_name> [repository_provider]" >&2
        exit 1
fi

source_directory="${1}"
branch="${2}"
repository_username="${3}"
repository_ownername="${4}"
repository_name="${5}"
repository_provider="${6}"

if [ ! -d "${source_directory}" ]
then
        /bin/echo "failed"
        /bin/echo "Error: Source directory not found at ${source_directory}." >&2
        exit 1
fi

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

repository_provider="$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYPROVIDER')"
if [ -z "${repository_provider}" ]
then
        /bin/echo "Error: GIT provider  not found in ${software_file}" >&2
        exit 1
fi

worker_script="${HOME}/services/git/${repository_provider}/${orchestration_tool}/push_to_repository.sh"

if [ ! -x "${worker_script}" ]
then
        /bin/echo "Error: Provider push script not found or not executable at ${worker_script}" >&2
        exit 1
fi

# Temporary disable set -e to evaluate git transaction failures manually
set +e
output="$(${worker_script} "${source_directory}" "${branch}" "${repository_username}" "${repository_ownername}" "${repository_name}")"
push_status="$?"
set -e

if [ "${push_status}" -eq 0 ] && [ -n "${output}" ]
then
        /bin/echo "${output}"
else
        /bin/echo "failed"
        /bin/echo "Git push failed for ${repository_ownername}/${repository_name}. Check your API token, branch, or repository permissions." >&2
        exit 1
fi

exit 0
