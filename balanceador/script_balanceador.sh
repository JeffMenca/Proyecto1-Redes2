#!/bin/bash

# Interfaces a usar para balancear el tráfico
INTERFACE_1="enp7s0"  # ISP1
INTERFACE_2="enp8s0"  # ISP2
INTERFACE_FW="enp9s0" # Firewall

# IPs de los gateways para cada interfaz
GATEWAY_1="192.168.20.1"  # Gateway ISP1
GATEWAY_2="192.168.25.1"  # Gateway ISP2

# Contador de paquetes
PAQUETES_ENVIADOS=0
UMBRAL_PAQUETES=100  # Número de paquetes antes de cambiar la interfaz

# Inicialmente, utilizamos la interfaz 1
INTERFAZ_ACTIVA=$INTERFACE_1
GATEWAY_ACTIVO=$GATEWAY_1

# Función para eliminar la ruta predeterminada actual
eliminar_ruta_default() {
    echo "Eliminando rutas predeterminadas existentes..."

    # Verificar si existe una ruta predeterminada
    if ip route | grep -q "default"; then
        sudo ip route del default
        if [ $? -eq 0 ]; then
            echo "Ruta predeterminada eliminada con éxito."
        else
            echo "Error al eliminar la ruta predeterminada."
        fi
    else
        echo "No se encontró ninguna ruta predeterminada para eliminar."
    fi
}

# Función para configurar la ruta predeterminada
configurar_ruta() {
    echo "Configurando ruta predeterminada a través de $INTERFAZ_ACTIVA ($GATEWAY_ACTIVO)"
    eliminar_ruta_default
    sudo ip route add default via $GATEWAY_ACTIVO dev $INTERFAZ_ACTIVA
    if [ $? -eq 0 ]; then
        echo "Ruta predeterminada configurada correctamente."
    else
        echo "Error al configurar la ruta predeterminada."
    fi
}

# Función para alternar interfaces
alternar_interfaces() {
    if [ "$INTERFAZ_ACTIVA" == "$INTERFACE_1" ]; then
        INTERFAZ_ACTIVA=$INTERFACE_2
        GATEWAY_ACTIVO=$GATEWAY_2
    else
        INTERFAZ_ACTIVA=$INTERFACE_1
        GATEWAY_ACTIVO=$GATEWAY_1
    fi
    configurar_ruta
}

# Inicializar la ruta predeterminada
configurar_ruta

# Monitorear los paquetes enviados utilizando iptables
while true; do
    # Obtener el número de paquetes enviados por la interfaz activa
    PAQUETES_ACTUALES=$(sudo iptables -L -v -n | awk -v intf="$INTERFAZ_ACTIVA" '$8 == intf && /0.0.0.0\/0/ {print $1}')
    echo $PAQUETES_ACTUALES

    # Validar si PAQUETES_ACTUALES es numérico; si no, establecerlo a 0
    if ! [[ "$PAQUETES_ACTUALES" =~ ^[0-9]+$ ]]; then
        echo "No se pudieron obtener paquetes actuales, estableciendo a 0."
        PAQUETES_ACTUALES=0
    else
        echo "Paquetes actuales en $INTERFAZ_ACTIVA: $PAQUETES_ACTUALES"
    fi

    # Convertir PAQUETES_ENVIADOS y PAQUETES_ACTUALES a enteros antes de la suma
    PAQUETES_ENVIADOS=$((PAQUETES_ENVIADOS + PAQUETES_ACTUALES))
    echo "Total de paquetes enviados: $PAQUETES_ENVIADOS"

    # Revisar si se ha alcanzado el umbral para cambiar de interfaz
    if [ "$PAQUETES_ENVIADOS" -ge "$UMBRAL_PAQUETES" ]; then
        echo "Umbral de paquetes alcanzado: $PAQUETES_ENVIADOS paquetes enviados."
        alternar_interfaces
        PAQUETES_ENVIADOS=0  # Resetear contador
    fi
    
    # Espera de 1 segundo antes de verificar nuevamente
    sleep 1
done
