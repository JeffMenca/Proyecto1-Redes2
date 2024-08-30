#!/bin/bash

# Script para reemplazar el contenido de /etc/nftables.conf

sudo bash -c 'cat << EOF > /etc/nftables.conf
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy accept;
    }
    chain forward {
        type filter hook forward priority filter; policy accept;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

# Balanceo de Carga en Interfaces enp7s0 y enp8s0
table ip loadbalance {
    chain prerouting {
        type filter hook prerouting priority 0; policy accept;

        # Marcar tráfico para balanceo de carga
        ip saddr 192.168.45.0/24 ip daddr != 192.168.45.0/24 meta mark set numgen random mod 2
    }

    chain output {
        type route hook output priority 0; policy accept;

        # Balanceo de carga usando marcas
        meta mark 0 oif "enp7s0"
        meta mark 1 oif "enp8s0"
    }
}

EOF'

echo "Contenido de /etc/nftables.conf actualizado con éxito."

sudo nft -f /etc/nftables.conf

sudo iptables -t nat -F POSTROUTING
#ISP 1
sudo iptables -t nat -A POSTROUTING -o enp7s0 -j MASQUERADE
#ISP 2
sudo iptables -t nat -A POSTROUTING -o enp8s0 -j MASQUERADE

#Reinicio del servicio de networking
sudo systemctl restart networking

# Limpieza de tablas de reenvio
sudo iptables -F FORWARD

# Reglas para permitir el trafico de reenvio de datos en las interfaces
sudo iptables -A FORWARD -i enp9s0 -o enp7s0 -j ACCEPT
sudo iptables -A FORWARD -i enp7s0 -o enp9s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i enp9s0 -o enp8s0 -j ACCEPT
sudo iptables -A FORWARD -i enp8s0 -o enp9s0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Eliminar default via de interfaz hacia ISP1 (enp7s0)
sudo ip route del default via 192.168.25.1 dev enp8s0

# Agregar default via para ambas interfaces (enp7s0 y enp8s0) hacia ISP1 y ISP2
sudo ip route add default nexthop via 192.168.20.1 dev enp7s0 weight 2 nexthop via 192.168.25.1 dev enp8s0 weight 2
# sudo ip route add default scope global nexthop via 192.168.20.1 dev enp7s0 weight 1 nexthop via 192.168.25.1 dev enp8s0 weight 1

# Verificacion de las tablas y enrutamiento de red
ip route

sudo iptables -t nat -L -v -n

sudo iptables -L FORWARD -v -n