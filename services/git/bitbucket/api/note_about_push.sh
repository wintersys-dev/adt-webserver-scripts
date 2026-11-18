set +e
"${BUILD_HOME}/services/git/bitbucket/api/push_directory.sh"
push_exit=$?
set -e

if [ "${push_exit}" -eq 2 ]
then
        # Directory exceeded API limits -> fall back to standard git CLI push
        "${BUILD_HOME}/services/git/bitbucket/cli/push_directory.sh"
elif [ "${push_exit}" -ne 0 ]
then
        exit "${push_exit}"
fi
