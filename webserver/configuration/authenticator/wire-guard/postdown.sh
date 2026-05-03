interface="eth0"                  
wg_interface="wg0"                     
subnet="10.0.0.0/24"            
wg_port="1036"                  
  
/usr/sbin/iptables -t nat -D POSTROUTING -s ${subnet} -o ${interface} -j MASQUERADE
/usr/sbin/iptables -D INPUT -i ${wg_interface} -j ACCEPT
/usr/sbin/iptables -D FORWARD -i ${interface} -o ${wg_interface} -j ACCEPT
/usr/sbin/iptables -D FORWARD -i ${wg_interface} -o ${interface} -j ACCEPT
/usr/sbin/iptables -D INPUT -i ${interface} -p udp --dport ${wg_port} -j ACCEPT
