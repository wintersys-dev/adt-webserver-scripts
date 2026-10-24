
repository_username="${1}"
repository_ownername="${2}"
repository_name="${3}"
repository_token="${4}"


/usr/bin/git ls-remote https://${repository_username}${repository_token}@bitbucket.org/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
