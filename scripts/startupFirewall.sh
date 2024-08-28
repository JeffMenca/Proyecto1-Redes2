#!/bin/bash

#Se setea la default via (en caso que no se haya hecho)
sudo ip route replace default via 11.11.11.2 dev enp7s0

#Se eliminan las reglas del firewall (reinicio)
sudo iptables -F        # Elimina todas las reglas en la tabla filter
sudo iptables -X        # Elimina todas las cadenas personalizadas
sudo iptables -t nat -F # Elimina todas las reglas en la tabla nat
sudo iptables -t nat -X # Elimina todas las cadenas personalizadas en la tabla nat
sudo iptables -t mangle -F # Elimina todas las reglas en la tabla mangle
sudo iptables -t mangle -X # Elimina todas las cadenas personalizadas en la tabla mangle
sudo iptables -t raw -F    # Elimina todas las reglas en la tabla raw
sudo iptables -t raw -X    # Elimina todas las cadenas personalizadas en la tabla raw
sudo iptables -t security -F # Elimina todas las reglas en la tabla security
sudo iptables -t security -X # Elimina todas las cadenas personalizadas en la tabla security

# Archivo temporal para capturar las IPs
TEMP_FILE="ips_temp.txt"
OUTPUT_FILE="monitored_ips.txt"

# Captura solo las IPs de los paquetes ICMP y agrégalas al archivo temporal
sudo tshark -i enp8s0 -Y "icmp" -T fields -e ip.src >> $TEMP_FILE

# Elimina duplicados y actualiza el archivo final
sort $TEMP_FILE | uniq > $OUTPUT_FILE

# Limpiar el archivo temporal si ya no es necesario
rm $TEMP_FILE

