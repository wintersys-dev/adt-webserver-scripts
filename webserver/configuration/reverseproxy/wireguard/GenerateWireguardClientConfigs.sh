

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat ] )
then
  for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
  do

  #Generate the client configs for this machine

  #Create CANDIDATE file to associate with the new client configs

  #Sync the client configs to the datastore and process them on the authenticator

  done

  /bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat >> ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat

fi
