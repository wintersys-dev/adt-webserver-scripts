if ( [ ! -d ${HOME}/runtime/wire-guard/emails/incoming ] )
then
  /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/incoming
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emails" "${HOME}/runtime/wire-guard/emails/incoming"


/bin/cat ${HOME}/runtime/wire-guard/emails/authentication-emails* > ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat

/usr/bin/sort -u ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat | /bin/sed '/^$/d' >  ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat.$$
/bin/mv ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat.$$ ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat

if ( [ ! -d ${HOME}/runtime/wire-guard/emails/processing ] )
then
  /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/processing
fi

if ( [ -f ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat ] )
then
    /bin/grep -vf ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat > ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat 
else
    /bin/cp ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat
fi

/bin/mv ${HOME}/runtime/wire-guard/emails/incoming/all_authentication-emails.dat ${HOME}/runtime/wire-guard/emails/processing/processed_authentication_emails.dat


