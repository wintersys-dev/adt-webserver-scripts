if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "IMMUTABLE-WEBROOT"`" != "" ] )
then
  if ( [ ! -f ${HOME}/runtime/IMMUTABLE-WEBROOT.on ] )
  then
    /bin/touch ${HOME}/runtime/IMMUTABLE-WEBROOT.on
  fi
  if ( [ ! -f ${HOME}/runtime/IMMUTABLE-WEBROOT.off ] )
  then
    /bin/rm ${HOME}/runtime/IMMUTABLE-WEBROOT.off
  fi
else
  if ( [ ! -f ${HOME}/runtime/MUTABLE-WEBROOT.on ] )
  then
    /bin/touch ${HOME}/runtime/MUTABLE-WEBROOT.on
  fi
  if ( [ ! -f ${HOME}/runtime/MUTABLE-WEBROOT.off ] )
  then
    /bin/rm ${HOME}/runtime/MUTABLE-WEBROOT.off
  fi
fi
