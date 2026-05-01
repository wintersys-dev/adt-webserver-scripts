

${HOME}/services/datastore/operations/SyncFromDatastore.sh "wireguard-config" "wireguard-config/*" "${HOME}/runtime/authenticator"
/bin/cp ${HOME}/runtime/authenticator/qrcode/*  /etc/wireguard/freshqrcodes
/bin/cp ${HOME}/runtime/authenticator/client/* /etc/wireguard
/bin/cp ${HOME}/runtime/authenticator/server/* /etc/wireguard

