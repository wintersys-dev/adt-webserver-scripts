updated="${1}"
intialised="${2}"

if ( [ "${updated}" = "1" ] || [ "${initialised}" = "1" ] )
then
  ${HOME}/utilities/processing/RunServiceCommand.sh restart netfilter-persistent
  ${HOME}/utilities/processing/RunServiceCommand.sh netfilter-persistent save
fi

if ( [ "`/usr/bin/ufw status | /bin/grep 'inactive'`" = "" ] )
then
  /bin/touch ${HOME}/runtime/FIREWALL-ACTIVE
fi
