if ( [ ! -d ${HOME}/runtime/authenticator ] )
then
        /bin/mkdir -p ${HOME}/runtime/authenticator/incoming
fi

if ( [ -f /var/www/wire-guard/authentication-emails.dat ] )
then
        /bin/mv /var/www/wire-guard/authentication-emails.dat ${HOME}/runtime/authenticator/incoming/authentication-emails.dat
fi


