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
        echo "MAC $MAC permitida."
    else
        echo "Acción no reconocida: usa 'block' o 'allow'"
        exit 1
    fi
}

# Función para configurar Squid para bloquear o permitir un dominio
configure_domain() {
    if [ "$ACTION" == "block" ]; then
        if ! grep -q "$DOMAIN" /etc/squid/baddomains; then
            echo "$DOMAIN" >> /etc/squid/baddomains
            echo "Dominio $DOMAIN añadido a la lista de bloqueados."
        fi
        if ! grep -q 'acl bad_domains dstdomain "/etc/squid/baddomains"' /etc/squid/squid.conf; then
            echo 'acl bad_domains dstdomain "/etc/squid/baddomains"' >> /etc/squid/squid.conf
            echo 'http_access deny bad_domains' >> /etc/squid/squid.conf
        fi
    elif [ "$ACTION" == "allow" ]; then
        if ! grep -q "$DOMAIN" /etc/squid/gooddomains; then
            echo "$DOMAIN" >> /etc/squid/gooddomains
            echo "Dominio $DOMAIN añadido a la lista de permitidos."
        fi
        if ! grep -q 'acl good_domains dstdomain "/etc/squid/gooddomains"' /etc/squid/squid.conf; then
            echo 'acl good_domains dstdomain "/etc/squid/gooddomains"' >> /etc/squid/squid.conf
            echo 'http_access allow good_domains' >> /etc/squid/squid.conf
        fi
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
