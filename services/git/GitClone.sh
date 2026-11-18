#!/bin/sh

# Exit immediately if any command exits with a non-zero status
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the server tracking file
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

# Validate minimum required positional arguments
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        /bin/echo "Error: 5 arguments are required with 1 optional argument." >&2
        /bin/echo "Usage: $0 <repository_provider> <repository_ownername> <repository_name> <repository_branch> <destination_directory>" >&2
        exit 1
fi

repository_provider="${1}"
repository_ownername="${2}"
repository_name="${3}"
repository_branch="${4}"
destination_directory="${5}"

# Verify provider sub-driver script exists and is executable before delegating
provider_script="${HOME}/services/git/${repository_provider}/GitClone.sh"

if [ ! -f "${provider_script}" ]
then
        /bin/echo "Error: Git provider script not found at ${provider_script}" >&2
        exit 1
fi

if [ ! -x "${provider_script}" ]
then
        /bin/echo "Error: Git provider script at ${provider_script} is not executable." >&2
        exit 1
fi

# Delegate clone operation to the provider-specific sub-driver
set +e
"${provider_script}" "${repository_provider}" "${repository_ownername}" "${repository_name}" "${repository_branch}" "${destination_directory}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: ${provider_script} exited with error code ${exit_code}." >&2
        exit 1
fi

exit 0
