netrc_dir="$("${BUILD_HOME}/helpers/services/CreateTransientNetrc.sh")"
trap '/bin/rm -rf "${netrc_dir}"' EXIT

# 1. For Git CLI commands (clone, pull, push, ls-remote):
HOME="${netrc_dir}" GIT_TERMINAL_PROMPT=0 /usr/bin/git push -u origin "${branch}" -q

# 2. Or for curl commands:
/usr/bin/curl --netrc-file "${netrc_dir}/.netrc" -s "${endpoint}"
