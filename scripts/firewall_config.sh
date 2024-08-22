#!/bin/bash

# Variables
ACTION=$1  # "block" o "allow"
DOMAIN=$2  # Dominio a bloquear o permitir (opcional)
MAC=$3     # Dirección MAC a bloquear o permitir (opcional)

# Función para resolver las IPs del dominio (IPv4 e IPv6)
resolve_domain_ips() {
    IPS=$(nslookup $DOMAIN | awk '/^Address: / {print $2}' | grep -v '#')
    echo $IPS
}

# Función para configurar iptables e ip6tables para bloquear o permitir una dirección IP
configure_ip() {
    IPS=$(resolve_domain_ips)

    if [ -z "$IPS" ]; then
        echo "No se pudo resolver la IP para el dominio $DOMAIN"
        exit 1
    fi

    for IP in $IPS; do
        if [[ $IP == *:* ]]; then
            # Es una dirección IPv6
            if [ "$ACTION" == "block" ]; then
                sudo ip6tables -A OUTPUT -d $IP -j DROP
                sudo ip6tables -A INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv6: $IP) bloqueado."
            elif [ "$ACTION" == "allow" ]; then
                sudo ip6tables -D OUTPUT -d $IP -j DROP
                sudo ip6tables -D INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv6: $IP) permitido."
            else
                echo "Acción no reconocida: usa 'block' o 'allow'"
                exit 1
            fi
        else
            # Es una dirección IPv4
            if [ "$ACTION" == "block" ]; then
                sudo iptables -A OUTPUT -d $IP -j DROP
                sudo iptables -A INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv4: $IP) bloqueado."
            elif [ "$ACTION" == "allow" ]; then
                sudo iptables -D OUTPUT -d $IP -j DROP
                sudo iptables -D INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv4: $IP) permitido."
            else
                echo "Acción no reconocida: usa 'block' o 'allow'"
                exit 1
            fi
        fi
    done
}

# Función para configurar iptables para bloquear o permitir una MAC address
configure_mac() {
    if [ "$ACTION" == "block" ]; then
        sudo iptables -A INPUT -m mac --mac-source $MAC -j DROP
        echo "MAC $MAC bloqueada."
    elif [ "$ACTION" == "allow" ]; then
        sudo iptables -D INPUT -m mac --mac-source $MAC -j DROP
        echo "MAC $MAC permitida."
    else
        echo "Acción no reconocida: usa 'block' o 'allow'"
        exit 1
    fi
}

# Configurar IP del dominio (si se proporciona)
if [ -n "$DOMAIN" ]; then
    configure_ip
fi

# Configurar MAC (si se proporciona)
if [ -n "$MAC" ]; then
    configure_mac
fi

# Guardar las reglas de iptables y ip6tables
sudo iptables-save > /etc/iptables/rules.v4
sudo ip6tables-save > /etc/iptables/rules.v6
