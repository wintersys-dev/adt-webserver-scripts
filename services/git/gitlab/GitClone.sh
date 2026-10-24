#!/bin/sh

branch_command="${1}"
repository_provider="${2}"
repository_token="${3}"
repository_username="${4}"
repository_ownername="${5}"
repository_name="${6}"
destination_directory="${7}"

# 1. Create a secure, restricted-permission temporary file
NETRC_FILE=$(mktemp)
chmod 600 "$NETRC_FILE"

# 2. Write the GitLab machine credentials to it
echo "machine gitlab.com login ${repository_username} password ${repository_token}" > "$NETRC_FILE"

# 3. Mask the HOME directory to force Git to read our temporary file
HOME_OVERRIDE=$(mktemp -d)
ln -s "$NETRC_FILE" "$HOME_OVERRIDE/.netrc"

HOME="$HOME_OVERRIDE" /usr/bin/git clone --depth 1 ${branch_command} https://gitlab.com{repository_ownername}/${repository_name}.git ${destination_directory}

# 4. Securely erase the temporary files
rm -rf "$HOME_OVERRIDE" "$NETRC_FILE"
