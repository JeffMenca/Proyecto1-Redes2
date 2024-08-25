#!/bin/bash

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

# Verificacion de las tablas y enrutamiento de red
ip route

sudo iptables -t nat -L -v -n

sudo iptables -L FORWARD -v -n