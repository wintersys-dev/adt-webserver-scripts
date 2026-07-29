set -x

if ( [ ! -d ${HOME}/runtime/wire-guard/configs ] )
then
        /bin/mkdir -p ${HOME}/runtime/wire-guard/configs
fi

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wire-guard" "${HOME}/runtime/wire-guard/configs"

for reverse_proxy_ip in `/bin/ls ${HOME}/runtime/wire-guard/configs`
do
        for email_address in `/bin/ls ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}`
        do
                if ( [ ! -f  ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}/${email_address}/PROCESSED ] )
                then
                        if ( [ "`/bin/echo ${emails_to_process} | /bin/grep ${email_address}`" = "" ] )
                        then
                                emails_to_process="${emails_to_process} ${email_address}"
                        fi
                fi
        done
done

echo ${emails_to_process}

NO_REVERSE_PROXIES="`${HOME}/utilities/config/ExtractConfigValue.sh 'NOREVERSEPROXIES'`"

count="1" 

while ( [ "${count}" -lt "${NO_REVERSE_PROXIES}" ] )
do
        count="`/usr/bin/expr ${count} + 1`"
        for reverse_proxy_ip in `/bin/ls ${HOME}/runtime/wire-guard/configs`
        do
                for email_address in ${emails_to_process}
                do
                        /bin/cat ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}/${email_address}/client_interface.conf* > ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}/${email_address}/client.conf
                        /bin/cat ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}/${email_address}/client_peer.conf* >> ${HOME}/runtime/wire-guard/configs/${reverse_proxy_ip}/${email_address}/client.conf
                done
        done
done
