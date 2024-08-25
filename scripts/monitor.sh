#!/bin/bash

#Se setea la default via (en caso que no se haya hecho)
sudo ip route replace default via 11.11.11.2 dev enp7s0
# Archivo temporal para capturar las IPs
TEMP_FILE="ips_temp.txt"
OUTPUT_FILE="monitored_ips.txt"

# Captura solo las IPs de los paquetes ICMP y agrégalas al archivo temporal
sudo tshark -i enp8s0 -Y "icmp" -T fields -e ip.src >> $TEMP_FILE

# Elimina duplicados y actualiza el archivo final
sort $TEMP_FILE | uniq > $OUTPUT_FILE

# Limpiar el archivo temporal si ya no es necesario
rm $TEMP_FILE

