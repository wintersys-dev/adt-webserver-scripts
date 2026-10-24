#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ] )
then
        status "Error: 5 arguments are required with 2 optional arguments"
        status "Usage: $0 <repository_provider> <repository_username> <repository_ownername> <repository_name> <repository_token> <repository_branch> <destination_directory>"
        exit 1
fi


repository_provider="${1}"
repository_username="${2}"
repository_ownername="${3}"
repository_name="${4}"
repository_token="${5}"
repository_branch="${6}"
destination_directory="${7}"

authentication_token=""

if ( [ "${repository_token}" != "" ] )
then
        authentication_token=":${repository_token}"
fi

branch_command=""

if ( [ "${repository_branch}" != "" ] )
then
        branch_command=" -b ${repository_branch} "
fi

${HOME}/services/git/${repository_provider}/GitClone.sh "${branch_command}" "${repository_provider}" "${authentication_token}" "${repository_username}" "${repository_ownername}" "${repository_name}" "${destination_directory}"


