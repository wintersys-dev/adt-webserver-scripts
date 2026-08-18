if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "IMMUTABLE-WEBROOT"`" != "" ] )
then
        if ( [ ! -f ${HOME}/runtime/IMMUTABLE-WEBROOT-ON ] )
        then
                /bin/touch ${HOME}/runtime/IMMUTABLE-WEBROOT-ON
                ${HOME}/utilities/security/EnforcePermissions.sh
                if ( [ -f ${HOME}/runtime/IMMUTABLE-WEBROOT-OFF ] )
                then
                        /bin/rm ${HOME}/runtime/IMMUTABLE-WEBROOT-OFF
                fi
        fi
else
        if ( [ ! -f ${HOME}/runtime/MUTABLE-WEBROOT-ON ] )
        then
                /bin/touch ${HOME}/runtime/MUTABLE-WEBROOT-ON
                ${HOME}/utilities/security/EnforcePermissions.sh
                if ( [ -f ${HOME}/runtime/MUTABLE-WEBROOT-OFF ] )
                then
                        /bin/rm ${HOME}/runtime/MUTABLE-WEBROOT-OFF
                fi
        fi
fi
