#!/bin/sh

HOME="`/bin/cat /home/homedir.dat`"

repository_provider="${1}"
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

/usr/bin/git init
/usr/bin/git branch -M main
provider_url="`${HOME}/services/git/${repository_provider}/GetProviderURL.sh`"
/usr/bin/git remote add origin https://${provider_url}/${repository_owner}/${repository_name}
/usr/bin/git add .gitattributes
/usr/bin/git add --all -f
/usr/bin/git commit -m "Baseline Baby"
/usr/bin/git push -u origin main
/bin/rm ${HOME}/.netrc
