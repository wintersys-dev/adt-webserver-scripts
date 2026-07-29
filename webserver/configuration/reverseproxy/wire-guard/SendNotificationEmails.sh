#!/bin/sh
###########################################################################################################
# Description: If the infrastructure has been taken offline and redeployed then this will send an email
# to the users to inform them that they need to regenerate their wireguard configs and recallibrate their
# wireguard client
# Author : Peter Winter
# Date: 17/05/2026
######################################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x

/bin/sleep `/usr/bin/shuf -i 1-60 -n 1`

if ( [ -f ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL ] || [ "`${HOME}/services/datastore/operations/ListFromDatastore.sh "wire-guard-emails" "SENT_NOTIFICATION_EMAIL"`" != "" ] )
then
        /bin/touch ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
        exit
else
        /bin/touch ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL
        ${HOME}/services/datastore/operations/PutToDatastore.sh "wire-guard-emails" ${HOME}/runtime/wire-guard/SENT_NOTIFICATION_EMAIL "" "distributed" "no"
fi

if ( [ ! -d ${HOME}/runtime/wire-guard/emails/notifications ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/emails/notifications
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard-emails" "${HOME}/runtime/wire-guard/emails/notifications"

NO_REVESE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"

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

#Delete all emails from previous build - we have requested that those emails regenerate their wireguard config and make triple sure that
#SENT_NOTIFICATIONS_EMAIL is deleted
${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emails"  "delete-all" "distributed"
/bin/sleep 60
${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emails"  "SENT_NOTIFICATION_EMAIL" "distributed"
/bin/sleep 60
${HOME}/services/datastore/operations/DeleteFromDatastore.sh "wire-guard-emails"  "SENT_NOTIFICATION_EMAIL" "distributed"

