command1 = "iptables -t nat -F POSTROUTING"
command2 = "iptables -t nat -A POSTROUTING -o $VALUE1 -j MASQUERADE"
command4 = "sudo systemctl restart networking.service"
command5 = "sudo iptables -F FORWARD"

command6 = "sudo iptables -A FORWARD -i $VALUE1 -o $VALUE2 -j ACCEPT"
command7 = "sudo iptables -A FORWARD -i $VALUE1 -o $VALUE2 -m state --state RELATED,ESTABLISHED -j ACCEPT"

# command8 = "sudo ip route del default via $VALUE1 dev $VALUE2"
command8 = "sudo ip route del default"

command9 = "sudo ip route add default nexthop via $VALUE1 dev $VALUE2 weight $VALUE3 nexthop via $VALUE4 dev $VALUE5 weight $VALUE6"
command10 = "sudo nft -f /etc/nftables.conf"

command11 = "sudo ip route add $VALUE1 via $VALUE2 dev $VALUE3"