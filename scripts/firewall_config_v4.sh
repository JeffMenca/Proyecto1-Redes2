#!/bin/bash

# Variables
ACTION=$1  # "block" o "allow"
DOMAIN=$2  # Dominio a bloquear o permitir (opcional)
MAC=$3     # Direccion MAC a bloquear o permitir (opcional)
SOURCE_IP="" # IP de origen opcional
OUTPUT_FILE="monitored_ips.txt"  # Archivo con las IPs capturadas

# Funcion para resolver las IPs del dominio (IPv4 e IPv6)
resolve_domain_ips() {
    IPS=$(nslookup "$DOMAIN" 2>/dev/null | awk '/^Address: / {print $2}' | grep -v '#')
    echo "$IPS"
}

# Funcion para verificar si una regla ya existe en iptables
rule_exists() {
    sudo iptables -C "$@" 2>/dev/null > /dev/null
}

# Funcion para verificar si una regla ya existe en ip6tables
rule_exists_ip6() {
    sudo ip6tables -C "$@" 2>/dev/null > /dev/null
}

# Funcion para configurar iptables e ip6tables para bloquear o permitir una direccion IP
configure_ip() {
    IPS=$(resolve_domain_ips)

    if [ -z "$IPS" ]; then
        echo "No se pudo resolver la IP para el dominio $DOMAIN."
        exit 1
    fi

    for IP in $IPS; do
        if [[ $IP == *:* ]]; then
            # Direccion IPv6
            if [ "$ACTION" == "block" ]; then
                if ! rule_exists_ip6 OUTPUT -d "$IP" -j DROP; then
                    sudo ip6tables -A OUTPUT -d "$IP" -j DROP
                fi
                if ! rule_exists_ip6 INPUT -s "$IP" -j DROP; then
                    sudo ip6tables -A INPUT -s "$IP" -j DROP
                fi
                echo "Dominio $DOMAIN (IPv6: $IP) bloqueado."
            elif [ "$ACTION" == "allow" ]; then
                if rule_exists_ip6 OUTPUT -d "$IP" -j DROP; then
                    sudo ip6tables -D OUTPUT -d "$IP" -j DROP
                fi
                if rule_exists_ip6 INPUT -s "$IP" -j DROP; then
                    sudo ip6tables -D INPUT -s "$IP" -j DROP
                fi
                echo "Dominio $DOMAIN (IPv6: $IP) permitido."
            else
                echo "Accion no reconocida: usa 'block' o 'allow'."
                exit 1
            fi
        else
            # Direccion IPv4
            if [ "$ACTION" == "block" ]; then
                if ! rule_exists OUTPUT -d "$IP" -j DROP; then
                    sudo iptables -A OUTPUT -d "$IP" -j DROP
                fi
                if ! rule_exists INPUT -s "$IP" -j DROP; then
                    sudo iptables -A INPUT -s "$IP" -j DROP
                fi
                if [ -n "$SOURCE_IP" ] && ! rule_exists FORWARD -s "$SOURCE_IP" -d "$IP" -j DROP; then
                    sudo iptables -A FORWARD -s "$SOURCE_IP" -d "$IP" -j DROP
                    echo "Dominio $DOMAIN (IPv4: $IP) bloqueado para la IP de origen $SOURCE_IP en FORWARD."
                fi
                echo "Dominio $DOMAIN (IPv4: $IP) bloqueado."
                block_ips_from_file "$IP"
            elif [ "$ACTION" == "allow" ]; then
                if rule_exists OUTPUT -d "$IP" -j DROP; then
                    sudo iptables -D OUTPUT -d "$IP" -j DROP
                fi
                if rule_exists INPUT -s "$IP" -j DROP; then
                    sudo iptables -D INPUT -s "$IP" -j DROP
                fi
                if [ -n "$SOURCE_IP" ] && rule_exists FORWARD -s "$SOURCE_IP" -d "$IP" -j DROP; then
                    sudo iptables -D FORWARD -s "$SOURCE_IP" -d "$IP" -j DROP
                    echo "Dominio $DOMAIN (IPv4: $IP) permitido para la IP de origen $SOURCE_IP en FORWARD."
                fi
                echo "Dominio $DOMAIN (IPv4: $IP) permitido."
                allow_ips_from_file "$IP"
            else
                echo "Accion no reconocida: usa 'block' o 'allow'."
                exit 1
            fi
        fi
    done
}

# Funcion para configurar iptables para bloquear o permitir una direccion MAC en INPUT y FORWARD
configure_mac() {
    if [ "$ACTION" == "block" ]; then
        if ! rule_exists INPUT -m mac --mac-source "$MAC" -j DROP; then
            sudo iptables -A INPUT -m mac --mac-source "$MAC" -j DROP
        fi
        if ! rule_exists FORWARD -m mac --mac-source "$MAC" -j DROP; then
            sudo iptables -A FORWARD -m mac --mac-source "$MAC" -j DROP
        fi
        echo "MAC $MAC bloqueada en el firewall."
    elif [ "$ACTION" == "allow" ]; then
        if rule_exists INPUT -m mac --mac-source "$MAC" -j DROP; then
            sudo iptables -D INPUT -m mac --mac-source "$MAC" -j DROP
        fi
        if rule_exists FORWARD -m mac --mac-source "$MAC" -j DROP; then
            sudo iptables -D FORWARD -m mac --mac-source "$MAC" -j DROP
        fi
        echo "MAC $MAC permitida en el firewall."
    else
        echo "Accion no reconocida: usa 'block' o 'allow'."
        exit 1
    fi
}

# Funcion para bloquear todas las IPs en monitored_ips.txt en relacion al dominio
block_ips_from_file() {
    DOMAIN_IP=$1
    if [ -f "$OUTPUT_FILE" ]; then
        while IFS= read -r IP; do
            if [ -n "$IP" ] && ! rule_exists FORWARD -s "$IP" -d "$DOMAIN_IP" -j DROP; then
                sudo iptables -A FORWARD -s "$IP" -d "$DOMAIN_IP" -j DROP
                echo "IP $IP bloqueada en FORWARD hacia $DOMAIN_IP."
            fi
        done < "$OUTPUT_FILE"
    else
        echo "Archivo $OUTPUT_FILE no encontrado."
    fi
}

# Funcion para permitir todas las IPs en monitored_ips.txt en relacion al dominio
allow_ips_from_file() {
    DOMAIN_IP=$1
    if [ -f "$OUTPUT_FILE" ]; then
        while IFS= read -r IP; do
            if [ -n "$IP" ] && rule_exists FORWARD -s "$IP" -d "$DOMAIN_IP" -j DROP; then
                sudo iptables -D FORWARD -s "$IP" -d "$DOMAIN_IP" -j DROP
                echo "IP $IP permitida en FORWARD hacia $DOMAIN_IP."
            fi
        done < "$OUTPUT_FILE"
    else
        echo "Archivo $OUTPUT_FILE no encontrado."
    fi
}

# Ejecutar configuraciones segun los parametros proporcionados
if [ -n "$DOMAIN" ]; then
    configure_ip
fi

if [ -n "$MAC" ]; then
    configure_mac
fi

# Guardar las reglas de iptables y ip6tables
sudo iptables-save > /etc/iptables/rules.v4
sudo ip6tables-save > /etc/iptables/rules.v6

echo "Configuracion del firewall actualizada y guardada correctamente."

