#!/bin/sh

#set -x
set -e

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        /bin/echo "Error: 2 arguments are required and 1 optional argument"
        /bin/echo "Usage: $0 <repository_owner> <repository_name> [repository_username]"
        exit 1
fi

repository_owner="${2}"
repository_name="${3}"
repository_username="${4}"


cat << EOF > ${HOME}/.netrc
machine github.com
login ${repository_username}
password ${REPOSITORY_TOKEN}
EOF

#I only use the .netrc file for git commands and I construct it and remove it every time I want to use it
#if I need a .netrc file for curl (for example) I construct a custom file name and use the custom file so there is no clash
chmod 600 ${HOME}/.netrc

handle_exit() {
        exit_status=$?

        if ( [ "$exit_status" -ne "0" ] )
        then
                echo "Error: Script ($0) aborted unexpectedly with status $exit_status" >&2
        fi
        rm -f "${HOME}/.netrc"
}

trap handle_exit EXIT

/usr/bin/git init
/usr/bin/git branch -M main
provider_url="`${HOME}/services/git/github/GitProviderURL.sh`"
/usr/bin/git remote add origin https://github.com/${repository_owner}/${repository_name}
/usr/bin/git add .gitattributes
/usr/bin/git add --all -f
/usr/bin/git commit -m "Baseline Baby"
/usr/bin/git push -u origin main

