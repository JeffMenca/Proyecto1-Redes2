import subprocess
import time
import re

# Interfaces a usar para balancear el tráfico
INTERFACE_1 = "enp7s0"  # ISP1
INTERFACE_2 = "enp8s0"  # ISP2

# IPs de los gateways para cada interfaz
GATEWAY_1 = "192.168.20.1"  # Gateway ISP1
GATEWAY_2 = "192.168.25.1"  # Gateway ISP2

# Contador de paquetes y umbral
PAQUETES_ENVIADOS = 0
UMBRAL_PAQUETES = 100  # Número de paquetes antes de cambiar la interfaz

# Inicialmente, utilizamos la interfaz 1
PRIORIDAD_PRIMARIA = INTERFACE_1
PRIORIDAD_SECUNDARIA = INTERFACE_2

# Función para ejecutar comandos de shell y devolver la salida
def ejecutar_comando(comando):
    try:
        resultado = subprocess.run(comando, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return resultado.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error al ejecutar el comando: {comando}\n{e.stderr}")
        return None

# Función para eliminar la ruta predeterminada actual
def eliminar_ruta_default():
    print("Eliminando rutas predeterminadas existentes...")
    ejecutar_comando("sudo ip route del default")

# Función para configurar la ruta predeterminada con balanceo de carga
def configurar_ruta():
    global PRIORIDAD_PRIMARIA, PRIORIDAD_SECUNDARIA
    print(f"Configurando ruta predeterminada con prioridad: {PRIORIDAD_PRIMARIA} y {PRIORIDAD_SECUNDARIA}")
    eliminar_ruta_default()

    # Asignar las IPs correctas a las interfaces correctas
    if PRIORIDAD_PRIMARIA == INTERFACE_1:
        ruta_comando = f"sudo ip route add default nexthop via {GATEWAY_1} dev {INTERFACE_1} weight 2 nexthop via {GATEWAY_2} dev {INTERFACE_2} weight 2"
    else:
        ruta_comando = f"sudo ip route add default nexthop via {GATEWAY_2} dev {INTERFACE_2} weight 2 nexthop via {GATEWAY_1} dev {INTERFACE_1} weight 2"
    
    print(f"Ejecutando comando: {ruta_comando}")
    ejecutar_comando(ruta_comando)
    print("Ruta predeterminada configurada correctamente.")

# Función para alternar prioridades de interfaces
def alternar_prioridades():
    global PRIORIDAD_PRIMARIA, PRIORIDAD_SECUNDARIA
    if PRIORIDAD_PRIMARIA == INTERFACE_1:
        PRIORIDAD_PRIMARIA = INTERFACE_2
        PRIORIDAD_SECUNDARIA = INTERFACE_1
    else:
        PRIORIDAD_PRIMARIA = INTERFACE_1
        PRIORIDAD_SECUNDARIA = INTERFACE_2
    configurar_ruta()

# Inicializar la ruta predeterminada
configurar_ruta()

# Monitorear los paquetes enviados utilizando iptables
while True:
    salida_iptables = ejecutar_comando("sudo iptables -L -v -n")
    if salida_iptables is None:
        continue  # Si hay un error en el comando, reintenta en el siguiente ciclo

    print("Salida completa de iptables:")
    print(salida_iptables)

    # Buscar el número de paquetes enviados por la interfaz activa usando regex
    patron = re.compile(rf"(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+{PRIORIDAD_PRIMARIA}\s+\S+\s+0.0.0.0/0")
    match = patron.search(salida_iptables)

    if match:
        PAQUETES_ACTUALES = int(match.group(1))
        print(f"Paquetes actuales en {PRIORIDAD_PRIMARIA}: {PAQUETES_ACTUALES}")
    else:
        print("No se pudieron obtener paquetes actuales, estableciendo a 0.")
        PAQUETES_ACTUALES = 0

    # Incrementar el contador de paquetes enviados
    PAQUETES_ENVIADOS += PAQUETES_ACTUALES
    print(f"Total de paquetes enviados: {PAQUETES_ENVIADOS}")

    # Revisar si se ha alcanzado el umbral para cambiar de interfaz
    if PAQUETES_ENVIADOS >= UMBRAL_PAQUETES:
        print(f"Umbral de paquetes alcanzado: {PAQUETES_ENVIADOS} paquetes enviados. Cambiando prioridades de interfaces.")
        alternar_prioridades()
        PAQUETES_ENVIADOS = 0  # Resetear contador

    # Espera de 1 segundo antes de verificar nuevamente
    time.sleep(1)
