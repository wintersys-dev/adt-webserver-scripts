#!/bin/sh

set -e

if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: Repository username and repository name arguments are required." >&2
        /bin/echo "Usage: $0 <repository_username> <repository_name>" >&2
        exit 1
fi

api_script="${HOME}/services/git/bitbucket/api/create_repository.sh"

if [ ! -x "${api_script}" ]
then
        /bin/echo "Error: Target API script not found or not executable at ${api_script}" >&2
        exit 1
fi

exec "${api_script}" "$@"
