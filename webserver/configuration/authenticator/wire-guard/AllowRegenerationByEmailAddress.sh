
if ( [ -f ${HOME}/runtime/wire-guard/PROCESSED_EMAILS ] )
then
  /bin/sed -i "/${email_address}/d" ${HOME}/runtime/wire-guard/PROCESSED_EMAILS
fi

processed_marker_files="`/usr/bin/find ${HOME}/runtime/wire-guard | /bin/grep "^${email_address}$" | /bin/grep "EMAIL_PROCESSED"`"

for processed_marker_file in ${processed_marker_files}
do
        /bin/rm ${processed_marker_file}
done
