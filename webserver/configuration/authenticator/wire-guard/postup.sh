WIREGUARD_INTERFACE=wg0
WIREGUARD_LAN=10.0.0.0/24
MASQUERADE_INTERFACE=eth0

/usr/sbin/iptables -t nat -I POSTROUTING -o $MASQUERADE_INTERFACE -j MASQUERADE -s $WIREGUARD_LAN

# Add a WIREGUARD_wg0 chain to the FORWARD chain
CHAIN_NAME="WIREGUARD_$WIREGUARD_INTERFACE"
/usr/sbin/iptables -N $CHAIN_NAME
/usr/sbin/iptables -A FORWARD -j $CHAIN_NAME

# Accept related or established traffic
/usr/sbin/iptables -A $CHAIN_NAME -o $WIREGUARD_INTERFACE -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept traffic from any Wireguard IP address connected to the Wireguard server
/usr/sbin/iptables -A $CHAIN_NAME -s $WIREGUARD_LAN -i $WIREGUARD_INTERFACE -j ACCEPT

# Drop everything else coming through the Wireguard interface
/usr/sbin/iptables -A $CHAIN_NAME -i $WIREGUARD_INTERFACE -j DROP

# Return to FORWARD chain
/usr/sbin/iptables -A $CHAIN_NAME -j RETURN
