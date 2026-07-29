


email_address="${1}"

/bin/sed -i "/${email_address}/d" ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
