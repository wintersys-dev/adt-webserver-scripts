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


