if ( [ ! -d ${HOME}/runtime/authenticator/incoming ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator/incoming
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
        /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat
fi

/usr/bin/uniq ${HOME}/runtime/authenticator/incoming/authentication-emails.dat >> ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$
/bin/mv ${HOME}/runtime/authenticator/incoming/authentication-emails.dat.$$ ${HOME}/runtime/authenticator/incoming/authentication-emails.dat

if ( [ ! -d ${HOME}/runtime/authenticator/granted ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator/granted 
fi

for email_address in `/bin/cat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat`
do
        if ( [ ! -d ${HOME}/runtime/authenticator/granted/${email_address} ] )
        then
                /bin/mkdir -p ${HOME}/runtime/authenticator/granted/${email_address}
                /bin/touch ${HOME}/runtime/authenticator/granted/${email_address}/CANDIDATE
        fi
done

if ( [ ! -f ${HOME}/runtime/authenticator/reverse_proxy_ips ] )
then
        server_ips="`${HOME}/services/datastore/config/wrapper/ListFromDatastore.sh "config-reverseproxy"`"

        if ( [ "${server_ips}" != "" ] )
        then
                /bin/echo "${server_ips}" > ${HOME}/runtime/authenticator/reverse_proxy_ips
        fi
else
        server_ips="`/bin/cat ${HOME}/runtime/authenticator/reverse_proxy_ips`"
fi


