#!/bin/sh
##################################################################################
# Script Name : GitClone.sh
# Description : Executes a shallow Git clone operation (depth = 1) for a specific 
#               GitHub repository using an authenticated HTTPS URL and custom
#               branch/destination configurations.
#
# Usage       : ./GitCloneExecution.sh "<branch_command>" \
#                                      <repository_provider> \
#                                      <repository_token> \
#                                      <repository_username> \
#                                      <repository_ownername> \
#                                      <repository_name> \
#                                      <destination_directory>
#
# Arguments   : $1 - branch_command         (e.g., "-b main" or empty string)
#               $2 - repository_provider     (Expected to be "github")
#               $3 - repository_token        (Formatted token string, e.g., ":PAT")
#               $4 - repository_username     (GitHub account username)
#               $5 - repository_ownername    (Repository owner or organization name)
#               $6 - repository_name         (Target repository name)
#               $7 - destination_directory   (Local path for the cloned repo)
#
# Dependencies: Requires system access to /usr/bin/git
##################################################################################
#set -x 
set -e

branch_command="${1}"
repository_provider="${2}"
repository_token="${3}"
repository_username="${4}"
repository_ownername="${5}"
repository_name="${6}"
destination_directory="${7}"


# 1. Create a secure, temporary netrc file
NETRC_FILE=$(mktemp)
chmod 600 "$NETRC_FILE"

# 2. Write the credentials to it
echo "machine github.com login ${repository_username} password ${repository_token}" > "$NETRC_FILE"

# 3. Tell Git to use this specific configuration file
export HOME_OVERRIDE=$(mktemp -d)
ln -s "$NETRC_FILE" "$HOME_OVERRIDE/.netrc"

HOME="$HOME_OVERRIDE" /usr/bin/git clone --depth 1 ${branch_command} https://github.com/${repository_ownername}/${repository_name}.git ${destination_directory}

# 4. Clean up the temporary files completely
rm -rf "$HOME_OVERRIDE" "$NETRC_FILE"

#/usr/bin/git clone --depth 1 ${branch_command} https://${repository_username}${repository_token}@github.com/${repository_ownername}/${repository_name}.git  ${destination_directory}
