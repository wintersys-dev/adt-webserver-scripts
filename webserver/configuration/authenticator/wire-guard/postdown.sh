 IN_FACE="eth0"                   # NIC connected to the internet
 WG_FACE="wg0"                    # WG NIC 
 SUB_NET="10.0.0.0/24"            # WG IPv4 sub/net aka CIDR
 WG_PORT="1036"                  # WG udp port
  
  /usr/sbin/iptables -t nat -D POSTROUTING -s $SUB_NET -o $IN_FACE -j MASQUERADE
  /usr/sbin/iptables -D INPUT -i $WG_FACE -j ACCEPT
  /usr/sbin/iptables -D FORWARD -i $IN_FACE -o $WG_FACE -j ACCEPT
  /usr/sbin/iptables -D FORWARD -i $WG_FACE -o $IN_FACE -j ACCEPT
  /usr/sbin/iptables -D INPUT -i $IN_FACE -p udp --dport $WG_PORT -j ACCEPT
