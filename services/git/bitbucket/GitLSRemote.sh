${HOME}/services/git/${repository_provider}/GitClone.sh "${repository_username}" "${repository_ownername}" "${repository_name}" ${authentication_token}" 


repository_username="${1}"
repository_ownername="${2}"
repository_name="${3}"
repository_token="${4}"

authentication_token=""

if ( [ "${repository_token}" != "" ] )
then
        authentication_token=":${repository_token}"
fi

/usr/bin/git ls-remote https://${repository_username}${authentication_token}@bitbucket.org/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
