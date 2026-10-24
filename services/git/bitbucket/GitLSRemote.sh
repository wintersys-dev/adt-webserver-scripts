
repository_username="${1}"
repository_ownername="${2}"
repository_name="${3}"



/usr/bin/git ls-remote https://${repository_username}${REPOSITORY_TOKEN}@bitbucket.org/${repository_ownername}/${repository_name}.git | /bin/grep 'HEAD'
