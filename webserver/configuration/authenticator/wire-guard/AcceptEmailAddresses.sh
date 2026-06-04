
if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
  if ( [ "`/bin/grep '@' /var/www/wire-guard/authentication-emails.dat`" != "" ] )
  then
    rnd="`/usr/bin/shuf -i 1-100000000000 -n 1`"
    
    if ( [ ! -d ${HOME}/runtime/wire-guard/emails ] )
    then
      /bin/mkdir -p ${HOME}/runtime/wire-guard/emails
    fi
    
    /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/wire-guard/emails/authentication-emails.dat.${rnd}
    ${HOME}/services/datastore/operations/MountDatastore.sh "wire-guard-emails" "distributed"
    ${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/emails/authentication-emails.dat.${rnd} "" "distributed" "no"
  fi
fi
