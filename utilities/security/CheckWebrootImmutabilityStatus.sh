if ( [ "`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config" "IMMUTABLE-WEBROOT"`" != "" ] )
then
        if ( [ ! -f ${HOME}/runtime/IMMUTABLE-WEBROOT-ON ] )
        then
                /bin/touch ${HOME}/runtime/IMMUTABLE-WEBROOT-ON
                if ( [ -f ${HOME}/runtime/MUTABLE-WEBROOT-ON ] )
                then
                        /bin/rm ${HOME}/runtime/MUTABLE-WEBROOT-ON
                fi
                ${HOME}/utilities/security/EnforcePermissions.sh
        fi
else
        if ( [ ! -f ${HOME}/runtime/MUTABLE-WEBROOT-ON ] )
        then
                /bin/touch ${HOME}/runtime/MUTABLE-WEBROOT-ON
                if ( [ -f ${HOME}/runtime/IMMUTABLE-WEBROOT-ON ] )
                then
                        /bin/rm ${HOME}/runtime/IMMUTABLE-WEBROOT-ON
                fi
                ${HOME}/utilities/security/EnforcePermissions.sh
        fi
fi
