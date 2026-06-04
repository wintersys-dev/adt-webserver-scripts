
if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
  if ( [ "`/bin/grep '@' /var/www/wire-guard/authentication-emails.dat`" != "" ] )
  then
  
${HOME}/services/datastore/operations/MountDatastore.sh "wire-guard-emails" "distributed"
${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" /var/www/wire-guard/authentication-emails.dat "" "distributed" "no"
