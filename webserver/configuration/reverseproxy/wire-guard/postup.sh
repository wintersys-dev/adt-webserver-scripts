interface="eth0"                   # NIC connected to the internet
wg_interface="wg0"                    # WG NIC 
subnet="10.0.0.0/24"            # WG IPv4 sub/net aka CIDR
wg_port="XXXXWG_PORTXXXX"                  # WG udp port
 
/usr/sbin/iptables -t nat -I POSTROUTING 1 -s ${subnet} -o ${interface} -j MASQUERADE
/usr/sbin/iptables -I INPUT 1 -i ${wg_interface} -j ACCEPT
/usr/sbin/iptables -I FORWARD 1 -i ${interface} -o ${wg_interface} -j ACCEPT
/usr/sbin/iptables -I FORWARD 1 -i ${wg_interface} -o ${interface} -j ACCEPT
/usr/sbin/iptables -I INPUT 1 -i ${interface} -p udp --dport ${wg_port} -j ACCEPT
