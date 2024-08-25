#!/bin/bash

# Variables
ACTION=$1  # "block" o "allow"
DOMAIN=$2  # Dominio a bloquear o permitir (opcional)
MAC=$3     # Dirección MAC a bloquear o permitir (opcional)
SOURCE_IP="192.168.45.237"  # IP específica que siempre será bloqueada o permitida
OUTPUT_FILE="ips_capturadas.txt"  # Archivo con las IPs capturadas

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
        # IPv4
        if [[ $IP != *:* ]]; then
            if [ "$ACTION" == "block" ]; then
                sudo iptables -A OUTPUT -d $IP -j DROP
                sudo iptables -A INPUT -s $IP -j DROP
                sudo iptables -A FORWARD -d $IP -s $SOURCE_IP -j DROP
                echo "Dominio $DOMAIN (IPv4: $IP) bloqueado."
                echo "Dominio $DOMAIN (IPv4: $IP) bloqueado para la IP $SOURCE_IP en FORWARD."
                
                # Bloqueo para todas las IPs en el archivo
                block_ips_from_file "$IP"
            elif [ "$ACTION" == "allow" ]; then
                sudo iptables -D OUTPUT -d $IP -j DROP
                sudo iptables -D INPUT -s $IP -j DROP
                sudo iptables -D FORWARD -d $IP -s $SOURCE_IP -j DROP
                echo "Dominio $DOMAIN (IPv4: $IP) permitido."
                echo "Dominio $DOMAIN (IPv4: $IP) permitido para la IP $SOURCE_IP en FORWARD."
                
                # Permitir para todas las IPs en el archivo
                allow_ips_from_file "$IP"
            else
                echo "Acción no reconocida: usa 'block' o 'allow'"
                exit 1
            fi
        else
            # Es una dirección IPv6, no aplicar reglas adicionales aquí
            if [ "$ACTION" == "block" ]; then
                sudo ip6tables -A OUTPUT -d $IP -j DROP
                sudo ip6tables -A INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv6: $IP) bloqueado."
            elif [ "$ACTION" == "allow" ]; then
                sudo ip6tables -D OUTPUT -d $IP -j DROP
                sudo ip6tables -D INPUT -s $IP -j DROP
                echo "Dominio $DOMAIN (IPv6: $IP) permitido."
            fi
        fi
    done
}

# Función para configurar iptables para bloquear o permitir una MAC address en INPUT y FORWARD
configure_mac() {
    if [ "$ACTION" == "block" ]; then
        sudo iptables -A INPUT -m mac --mac-source $MAC -j DROP
        sudo iptables -A FORWARD -m mac --mac-source $MAC -j DROP
        echo "MAC $MAC bloqueada en INPUT y FORWARD."
    elif [ "$ACTION" == "allow" ]; then
        sudo iptables -D INPUT -m mac --mac-source $MAC -j DROP
        sudo iptables -D FORWARD -m mac --mac-source $MAC -j DROP
        echo "MAC $MAC permitida en INPUT y FORWARD."
    else
        echo "Acción no reconocida: usa 'block' o 'allow'"
        exit 1
    fi
}

# Función para bloquear todas las IPs en ips_capturadas.txt en relación al dominio
block_ips_from_file() {
    DOMAIN_IP=$1
    if [ -f "$OUTPUT_FILE" ]; then
        while IFS= read -r IP; do
            sudo iptables -A FORWARD -d "$DOMAIN_IP" -s "$IP" -j DROP
            echo "$(date): IP $IP bloqueada para el dominio $DOMAIN_IP."
        done < "$OUTPUT_FILE"
    else
        echo "Archivo $OUTPUT_FILE no encontrado."
    fi
}

# Función para permitir todas las IPs en ips_capturadas.txt en relación al dominio
allow_ips_from_file() {
    DOMAIN_IP=$1
    if [ -f "$OUTPUT_FILE" ]; then
        while IFS= read -r IP; do
            sudo iptables -D FORWARD -d "$DOMAIN_IP" -s "$IP" -j DROP
            echo "$(date): IP $IP permitida para el dominio $DOMAIN_IP."
        done < "$OUTPUT_FILE"
    else
        echo "Archivo $OUTPUT_FILE no encontrado."
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

