

if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "IMMUTABLE-WEBROOT"`" != "" ] )
then
  if ( [ -f ${HOME}/runtime/MUTABLE-WEBROOT ] )
  then
    /bin/rm ${HOME}/runtime/MUTABLE-WEBROOT 
  fi
  /bin/touch ${HOME}/runtime/IMMUTABLE-WEBROOT
else
  if ( [ -f ${HOME}/runtime/IMMUTABLE-WEBROOT ] )
  then
    /bin/rm ${HOME}/runtime/IMMUTABLE-WEBROOT
  fi
  /bin/touch ${HOME}/runtime/MUTABLE-WEBROOT
fi
