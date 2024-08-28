from configuration_interfaces_balancer import data_file
import commands as COMMANDS
import os

# Declare function to execute commands


def execute_command(command):
    exit_code = os.system(command)
    if exit_code != 0:
        print(f"Error executing command: {command}")
    else:
        print(f"Command executed successfully: {command}")


# Description: This file contains the configuration of the load balancer
# Ports to be used by the load balancer
interface_isp1 = "enp7s0"
interface_isp2 = "enp8s0"
interface_bc_firewall = "enp9s0"
# IPs of ISP1 and ISP2
ip_isp1 = "192.168.20.1"
ip_isp2 = "192.168.25.1"
# Netmask of the IPs of ISP1 and ISP2
netmask_isp1 = "24"
netmask_isp2 = "24"
# Private network firewall - client
private_network = "192.168.45.0"
netmask_private_network = "24"
# Comand list to configure vias to the load balancer

# To confing the vias to the load balancer we need to remmove the default conf in /etc/nftables.conf with sudo permissions
# Add PORTS, IPs, and NETMASKS to the configuration template
custom_data_file = data_file.replace("$INTERFACE_ISP1", interface_isp1).replace(
    "$INTERFACE_ISP2", interface_isp2).replace("$PRIVATE_NETWORK", f'${private_network}/{netmask_private_network}')

# Write the configuration to the file /etc/nftables.conf
with open("/etc/nftables.conf", "w") as file:
    file.write(custom_data_file)

# Apply the configuration run command10
execute_command(COMMANDS.command10)

# Command to configure iptables to POSTROUTING
# RUN command1
execute_command(COMMANDS.command1)
# RUN command2 for ISP1 and ISP2
execute_command(COMMANDS.command2.replace("$VALUE1", interface_isp1))
execute_command(COMMANDS.command2.replace("$VALUE1", interface_isp2))

# Apply the configuration run command4
execute_command(COMMANDS.command4)

# Clear FORDWARD tables
# Run command5
execute_command(COMMANDS.command5)
# FORWARD interfaces ISP1 and ISP2 to firewall
# Run command6
execute_command(COMMANDS.command6.replace(
    "$VALUE1", interface_bc_firewall).replace("$VALUE2", interface_isp1))
# Run command7
execute_command(COMMANDS.command7.replace(
    "$VALUE1",  interface_isp1).replace("$VALUE2", interface_bc_firewall))
# Run command6
execute_command(COMMANDS.command6.replace(
    "$VALUE1", interface_bc_firewall).replace("$VALUE2", interface_isp2))
# Run command7
execute_command(COMMANDS.command7.replace(
    "$VALUE1",  interface_isp2).replace("$VALUE2", interface_bc_firewall))

# Delete default via to set both vias to the load balancer
# Run command8
execute_command(COMMANDS.command8.replace(
    "$VALUE1", ip_isp2).replace("$VALUE2", interface_isp2))
# Run command9
execute_command(COMMANDS.command9.replace(
    "$VALUE1", ip_isp1).replace("$VALUE2", interface_isp1).replace(
    "$VALUE3", "2").replace("$VALUE4", ip_isp2).replace("$VALUE5", interface_isp2).replace("$VALUE6", "2"))