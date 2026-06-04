

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat ] )
then
  for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
  do

  done

  /bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat >> ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat

fi
