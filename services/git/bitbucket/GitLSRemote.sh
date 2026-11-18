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
        /bin/echo "Error: Repository owner name, and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_ownername> <repository_name>" >&2
        exit 1
fi

repository_ownername="${1}"
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

worker_script="${HOME}/services/git/bitbucket/${orchestration_tool}/list_repository.sh"

if [ ! -x "${worker_script}" ]
then
        /bin/echo "Error: Provider repository check script not found or not executable at ${worker_script}" >&2
        exit 1
fi

# Temporary disable set -e to evaluate worker execution failures manually
set +e
output="$(${worker_script} "${repository_ownername}" "${repository_name}")"
worker_status="$?"
set -e

if [ "${worker_status}" -eq 0 ] && [ -n "${output}" ]
then
        case "${output}" in
                full|empty|none)
                        /bin/echo "${output}"
                        exit 0
                        ;;
                *)
                        /bin/echo "none"
                        /bin/echo "Error: Unexpected repository state returned: ${output}" >&2
                        exit 1
                        ;;
        esac
else
        /bin/echo "none"
        /bin/echo "Repository check failed for ${repository_ownername}/${repository_name}. Check your API token or configuration." >&2
        exit 1
fi

exit 0

