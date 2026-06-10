/bin/sleep `/usr/bin/shuf -i 1-100 -n 1`

if ( [ ! -d ${HOME}/runtime/wire-guard/emails/notifications ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/notifications
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emails" "${HOME}/runtime/wire-guard/emails/notifications"

NO_REVESE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"
if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "wire-guard-emails" "SENT_NOTIFICATION_EMAIL"`" = "" ] )
then
        /bin/touch ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
        ${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL "" "distributed" "no"
        /bin/rm ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL

        for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/processing/to_process_authentication_emails.dat`
        do
                message="The wireguard server IP addresses have changed at our end you will need to reconfigure your wireguard app by going to ${WEBSITE_URL} and replacing your previous wireguard client profile with a new one"
                message="${message}. You should receive ${NO_REVERSE_PROXIES} emails please reconfigure your wireguard app with each new QR code, replacing the old ones. This happens when a redeployment of our servers is actioned."
                ${HOME}/services/email/SendEmail.sh "WIREGUARD SERVER ALTERATION" "${message}" "MANDATORY" "${email_address}" "HTML"
        done 
fi
