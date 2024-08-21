#!/bin/bash

# Variables
ACTION=$1  # "block" o "allow"
DOMAIN=$2  # Dominio a bloquear o permitir
MAC=$3     # Dirección MAC

# Función para configurar iptables para bloquear o permitir una MAC address
configure_mac() {
    if [ "$ACTION" == "block" ]; then
        iptables -A INPUT -m mac --mac-source $MAC -j DROP
        echo "MAC $MAC bloqueada."
    elif [ "$ACTION" == "allow" ]; then
        iptables -A INPUT -m mac --mac-source $MAC -j ACCEPT
        iptables -A INPUT -j DROP
        echo "MAC $MAC permitida."
    else
        echo "Acción no reconocida: usa 'block' o 'allow'"
        exit 1
    fi
}

# Función para configurar Squid para bloquear o permitir un dominio
configure_domain() {
    if [ "$ACTION" == "block" ]; then
        echo "$DOMAIN" >> /etc/squid/baddomains
        acl_line="acl bad_domains dstdomain \"/etc/squid/baddomains\""
        access_line="http_access deny bad_domains"
        echo "$acl_line" >> /etc/squid/squid.conf
        echo "$access_line" >> /etc/squid/squid.conf
        echo "Dominio $DOMAIN bloqueado en Squid."
    elif [ "$ACTION" == "allow" ]; then
        echo "$DOMAIN" >> /etc/squid/gooddomains
        acl_line="acl good_domains dstdomain \"/etc/squid/gooddomains\""
        access_line="http_access allow good_domains"
        echo "$acl_line" >> /etc/squid/squid.conf
        echo "$access_line" >> /etc/squid/squid.conf
        echo "Dominio $DOMAIN permitido en Squid."
    else
        echo "Acción no reconocida: usa 'block' o 'allow'"
        exit 1
    fi

    # Reiniciar Squid para aplicar cambios
    systemctl restart squid
}

# Configurar MAC
if [ -n "$MAC" ]; then
    configure_mac
fi

# Configurar dominio
if [ -n "$DOMAIN" ]; then
    configure_domain
fi

# Guardar las reglas de iptables
iptables-save > /etc/iptables/rules.v4
