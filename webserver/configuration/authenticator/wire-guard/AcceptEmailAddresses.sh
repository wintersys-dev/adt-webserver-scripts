#Sync the S3 datastore to the granted directory


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

# if there is no /etc/wireguard/wg0.conf create the Interface section  of the new wg0.conf

# Generate server config entry for this new peer include a commented email address with new entry and remove any previous entry for that 
# email address from the server if there is no entry in the server config that mataches email address and ip address of the current
# peer config in the granted directory then add the peer config to wg0 sync the granted directory to s3



