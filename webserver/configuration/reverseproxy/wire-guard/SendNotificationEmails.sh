/bin/sleep `/usr/bin/shuf -i 1-60 -n 1`

if ( [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "wire-guard-emails" "SENT_NOTIFICATION_EMAIL"`" != "" ] )
then
        exit
fi

if ( [ ! -d ${HOME}/runtime/wire-guard/emails/notifications ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/notifications
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emails" "${HOME}/runtime/wire-guard/emails/notifications"

NO_REVESE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXY'`"
/bin/touch ${HOME}/runtime/wire-guard/SENDING_NOTIFICATION_EMAIL
${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/SENDING_NOTIFICATION_EMAIL "" "distributed" "no"

/bin/cat ${HOME}/runtime/wire-guard/emails/notifications/authentication-emails* > ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat
/usr/bin/sort -u ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat | /bin/sed '/^$/d' >  ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat.$$
/bin/mv ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat.$$ ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat


for email_address in `/bin/cat ${HOME}/runtime/wire-guard/emails/notifications/all_authentication-emails.dat`
do
        message="The wireguard server IP addresses have changed at our end you will need to reconfigure your wireguard app by going to ${WEBSITE_URL} and replacing your previous wireguard client profile with a new one"
        message="${message}. You should receive ${NO_REVERSE_PROXIES} emails please reconfigure your wireguard app with each new QR code, replacing the old ones. This happens when a redeployment of our servers is actioned."
        ${HOME}/services/email/SendEmail.sh "WIREGUARD SERVER ALTERATION" "${message}" "MANDATORY" "${email_address}" "HTML"
done 

/bin/rm -r ${HOME}/runtime/wire-guard/emails/notifications
/bin/sleep 60
${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emails"  "delete-all" "local"
/bin/touch ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL "" "distributed" "no"
${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emails"  "SENDING_NOTIFICATION_EMAIL" "local"
/bin/rm ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
/bin/rm ${HOME}/runtime/wire-guard/SENDING_NOTIFICATION_EMAIL

