#!/bin/sh

# Exit immediately if any command exits with a non-zero status
#set -x
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
if [ -z "${1}" ] 
then
        /bin/echo "Error: 3 arguments are required" >&2
        /bin/echo "Usage: $0 <repository_provider> <repository_username> <repository_name>" >&2
        exit 1
fi

set +e
repository_provider="${1:-$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYPROVIDER')}")
repository_username="${1:-$(${HOME}/utilities/config/ExtractConfigValue.sh 'APPLICATIONREPOSITORYUSERNAME')}")
repository_name="${3}"
set -e

# Verify that both required values are set from either arguments or config
if [ -z "${repository_provider}" ] || [ -z "${repository_username}" ] || [ -z "${repository_name}" ]
then
        /bin/echo "Error: Repository provider or repository username or repository name could not be determined from arguments or config." >&2
        /bin/echo "Usage: $0 [repository_provider] [repository_username] [repository_name]" >&2
        exit 1
fi


# Verify provider sub-driver script exists and is executable before delegating
provider_script="${HOME}/services/git/${repository_provider}/CreateRepository.sh"

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

# Delegate repository creation to the provider-specific sub-driver
set +e
"${provider_script}" "${repository_username}" "${repository_name}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        /bin/echo "Error: ${provider_script} exited with error code ${exit_code}." >&2
        exit 1
fi

exit 0

