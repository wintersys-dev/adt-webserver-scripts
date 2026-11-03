
updated="${1}"
intialised="${2}"

if ( [ "${updated}" = "1" ] || [ "${initialised}" = "1" ] )
then
  /usr/sbin/ufw -f enable
  /usr/sbin/ufw reload
fi

if ( [ "`/usr/bin/ufw status | /bin/grep 'inactive'`" = "" ] )
then
  /bin/touch ${HOME}/runtime/FIREWALL-ACTIVE
fi
