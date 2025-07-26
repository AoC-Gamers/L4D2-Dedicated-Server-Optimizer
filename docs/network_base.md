# Documentación del Módulo Network Base

## 📖 Descripción General

El módulo **Network Base** (`network_base.sh`) establece las configuraciones fundamentales de red del kernel Linux para optimizar el rendimiento de redes en servidores de juegos. Configura buffers del kernel, backlogs y parámetros básicos de TCP/UDP.

## 🎯 Objetivo

Optimizar los fundamentos de la red del sistema para:
- Aumentar buffers de recepción y envío de datos
- Mejorar manejo de paquetes entrantes bajo alta carga
- Reducir pérdida de paquetes por saturación de buffers
- Optimizar rendimiento base para protocolos TCP y UDP

## ⚙️ Funcionamiento Técnico

### Parámetros de Kernel Optimizados

#### 1. Buffers de Socket (rmem/wmem)

```bash
# Buffers máximos por socket
net.core.rmem_max = 134217728      # 128MB buffer lectura máximo
net.core.wmem_max = 134217728      # 128MB buffer escritura máximo

# Buffers por defecto
net.core.rmem_default = 262144     # 256KB buffer lectura por defecto  
net.core.wmem_default = 262144     # 256KB buffer escritura por defecto
```

**Impacto**:
- **rmem_max**: Máximo buffer de recepción por socket
- **wmem_max**: Máximo buffer de transmisión por socket  
- **Reduce**: Pérdida de paquetes por buffers insuficientes
- **Mejora**: Throughput en conexiones de alta velocidad

#### 2. Network Device Backlog

```bash
# Cola de paquetes en interfaz de red
net.core.netdev_max_backlog = 5000    # 5000 paquetes en cola
```

**Propósito**:
- Cola de paquetes esperando procesamiento
- **Alto tráfico**: Evita pérdida durante picos de tráfico
- **Gaming**: Importante para servidores con muchos jugadores
- **DDoS**: Mejora resistencia a ataques de red

#### 3. Parámetros de Netfilter

```bash
# Tabla de conexiones netfilter
net.netfilter.nf_conntrack_max = 524288       # 512K conexiones
net.nf_conntrack_max = 524288                 # Compatibilidad
```

**Función**:
- Tracking de conexiones activas
- **NAT/Firewall**: Esencial para iptables
- **Gaming**: Múltiples conexiones simultáneas
- **Límite**: Evita agotamiento de memoria por tracking

## 🔧 Variables de Configuración

| Variable | Descripción | Rango | Por Defecto |
|----------|-------------|-------|-------------|
| `NETWORK_RMEM_MAX` | Buffer máximo de recepción | 64KB-1GB | `134217728` (128MB) |
| `NETWORK_WMEM_MAX` | Buffer máximo de transmisión | 64KB-1GB | `134217728` (128MB) |
| `NETWORK_RMEM_DEFAULT` | Buffer recepción por defecto | 32KB-16MB | `262144` (256KB) |
| `NETWORK_WMEM_DEFAULT` | Buffer transmisión por defecto | 32KB-16MB | `262144` (256KB) |
| `NETWORK_NETDEV_BACKLOG` | Cola de dispositivo de red | 1000-50000 | `5000` |

### Ejemplo de Configuración (.env)

```bash
# Network Base configuration for network_base.sh module
NETWORK_RMEM_MAX="134217728"          # 128MB - Max receive buffer per socket
NETWORK_WMEM_MAX="134217728"          # 128MB - Max send buffer per socket  
NETWORK_RMEM_DEFAULT="262144"         # 256KB - Default receive buffer
NETWORK_WMEM_DEFAULT="262144"         # 256KB - Default send buffer
NETWORK_NETDEV_BACKLOG="5000"        # Network device backlog queue size
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Menor Packet Loss**: Buffers más grandes reducen pérdida de paquetes
- **Mayor Throughput**: Permite manejar más datos simultáneamente  
- **Mejor Latencia**: Reduce esperas por buffers llenos
- **Más Jugadores**: Soporta más conexiones simultáneas
- **Estabilidad**: Mejor manejo de picos de tráfico

### Comparación de Configuraciones

| Configuración | rmem_max | wmem_max | Backlog | Uso Recomendado |
|---------------|----------|----------|---------|-----------------|
| **Mínima** | 16MB | 16MB | 1000 | 1-8 jugadores |
| **Estándar** | 64MB | 64MB | 3000 | 8-16 jugadores |
| **Optimizada** | 128MB | 128MB | 5000 | 16-32 jugadores |
| **Máxima** | 256MB | 256MB | 10000 | 32+ jugadores |

## 🛠️ Proceso de Instalación

### Paso 1: Cálculo de Memoria Disponible

```bash
# Detectar memoria total del sistema
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM / 1024))

# Ajustar buffers según memoria disponible
if [[ $TOTAL_MEM_MB -lt 2048 ]]; then
  # Sistema con menos de 2GB
  RMEM_MAX="67108864"   # 64MB
  WMEM_MAX="67108864"   # 64MB
elif [[ $TOTAL_MEM_MB -lt 4096 ]]; then
  # Sistema con 2-4GB
  RMEM_MAX="134217728"  # 128MB
  WMEM_MAX="134217728"  # 128MB
else
  # Sistema con más de 4GB
  RMEM_MAX="268435456"  # 256MB
  WMEM_MAX="268435456"  # 256MB
fi
```

### Paso 2: Backup de Configuración Actual

```bash
# Backup de parámetros de red actuales
sysctl -a | grep -E "net.core.(r|w)mem|netdev_max_backlog|nf_conntrack" > network_base.backup.txt

# Estado actual de conectividad
ss -tuln > network_connections.backup.txt
netstat -i > network_interfaces.backup.txt
```

### Paso 3: Aplicación de Configuración

```bash
# Configuración sysctl
cat >> /etc/sysctl.d/99-l4d2-network-base.conf << EOF
# Network Base Optimization for L4D2 Server
# Buffer sizes
net.core.rmem_max = ${NETWORK_RMEM_MAX:-134217728}
net.core.wmem_max = ${NETWORK_WMEM_MAX:-134217728}
net.core.rmem_default = ${NETWORK_RMEM_DEFAULT:-262144}
net.core.wmem_default = ${NETWORK_WMEM_DEFAULT:-262144}

# Network device settings
net.core.netdev_max_backlog = ${NETWORK_NETDEV_BACKLOG:-5000}

# Connection tracking
net.netfilter.nf_conntrack_max = 524288
net.nf_conntrack_max = 524288
EOF

# Aplicar configuración
sysctl -p /etc/sysctl.d/99-l4d2-network-base.conf
```

### Paso 4: Validación de Aplicación

```bash
# Verificar que los parámetros se aplicaron correctamente
echo "=== Network Base Configuration Applied ==="
echo "rmem_max: $(sysctl -n net.core.rmem_max)"
echo "wmem_max: $(sysctl -n net.core.wmem_max)"
echo "rmem_default: $(sysctl -n net.core.rmem_default)"
echo "wmem_default: $(sysctl -n net.core.wmem_default)"
echo "netdev_max_backlog: $(sysctl -n net.core.netdev_max_backlog)"
```

## 📋 Archivos Modificados

### Archivos del Sistema

| Archivo | Propósito | Persistencia |
|---------|-----------|--------------|
| `/etc/sysctl.d/99-l4d2-network-base.conf` | Configuración de red base | Permanente |
| `/proc/sys/net/core/rmem_max` | Buffer máximo de recepción | Runtime |
| `/proc/sys/net/core/wmem_max` | Buffer máximo de transmisión | Runtime |
| `/proc/sys/net/core/netdev_max_backlog` | Cola de dispositivo de red | Runtime |

### Ejemplo de Configuración Aplicada

```ini
# /etc/sysctl.d/99-l4d2-network-base.conf
# Network Base Optimization for L4D2 Server

# Socket buffer limits
net.core.rmem_max = 134217728          # 128MB max receive buffer  
net.core.wmem_max = 134217728          # 128MB max send buffer
net.core.rmem_default = 262144         # 256KB default receive buffer
net.core.wmem_default = 262144         # 256KB default send buffer

# Network device queue
net.core.netdev_max_backlog = 5000     # 5000 packets in device queue

# Connection tracking limits
net.netfilter.nf_conntrack_max = 524288
net.nf_conntrack_max = 524288
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Ver configuración de buffers actual
echo "=== Buffer Configuration ==="
sysctl net.core.rmem_max net.core.wmem_max
sysctl net.core.rmem_default net.core.wmem_default
sysctl net.core.netdev_max_backlog

# Ver uso de buffers por socket
ss -m

# Ver estadísticas de red
cat /proc/net/snmp | grep -E "Tcp:|Udp:"

# Ver pérdida de paquetes
ip -s link show

# Ver cola de paquetes por interfaz
cat /proc/net/softnet_stat
```

### Monitoreo de Buffers

```bash
#!/bin/bash
# Script de monitoreo de buffers de red
echo "=== Network Buffer Monitoring ==="

# Función para convertir bytes a formato legible
human_readable() {
  local bytes=$1
  if [[ $bytes -gt 1073741824 ]]; then
    echo "$(($bytes / 1073741824))GB"
  elif [[ $bytes -gt 1048576 ]]; then
    echo "$(($bytes / 1048576))MB"  
  elif [[ $bytes -gt 1024 ]]; then
    echo "$(($bytes / 1024))KB"
  else
    echo "${bytes}B"
  fi
}

# Configuración actual
echo "Buffer Configuration:"
rmem_max=$(sysctl -n net.core.rmem_max)
wmem_max=$(sysctl -n net.core.wmem_max)
echo "  rmem_max: $(human_readable $rmem_max)"
echo "  wmem_max: $(human_readable $wmem_max)"

# Uso de buffers por conexiones activas
echo -e "\nActive socket buffers:"
ss -m | grep -A1 "ESTAB" | head -20
```

## ⚠️ Consideraciones Importantes

### Uso de Memoria

Los buffers grandes consumen más memoria RAM:

```bash
# Cálculo aproximado de uso de memoria
# Por cada socket: rmem_max + wmem_max (máximo)
# Con 100 conexiones simultáneas y buffers de 128MB:
# Uso máximo: 100 * (128MB + 128MB) = 25.6GB

# Recomendación para sistemas con poca RAM:
# < 2GB RAM: rmem/wmem_max = 64MB
# < 4GB RAM: rmem/wmem_max = 128MB  
# > 4GB RAM: rmem/wmem_max = 256MB
```

### Compatibilidad con Aplicaciones

```bash
# Algunas aplicaciones pueden tener límites internos
# Verificar si L4D2 server usa los buffers completos:
lsof -n -i | grep srcds_run
ss -p | grep srcds
```

## 🐛 Solución de Problemas

### Problema: Configuración no se aplica

**Diagnóstico**:
```bash
# Verificar si sysctl cargó el archivo
sysctl -a | grep -E "rmem_max|wmem_max"

# Ver archivos de configuración cargados
sysctl --system
```

**Solución**:
```bash
# Forzar recarga de configuración
sudo sysctl -p /etc/sysctl.d/99-l4d2-network-base.conf

# Verificar permisos del archivo
ls -la /etc/sysctl.d/99-l4d2-network-base.conf

# Verificar sintaxis del archivo
sysctl -f /etc/sysctl.d/99-l4d2-network-base.conf
```

### Problema: Alto uso de memoria

**Diagnóstico**:
```bash
# Ver uso de memoria por buffers de red
cat /proc/meminfo | grep -i net

# Ver sockets que usan más memoria
ss -m | sort -k2 -nr | head -10

# Ver total de memoria en buffers
cat /proc/net/sockstat
```

**Solución**:
```bash
# Reducir buffers si hay problemas de memoria
echo 'net.core.rmem_max = 67108864' >> /etc/sysctl.d/99-l4d2-network-base.conf
echo 'net.core.wmem_max = 67108864' >> /etc/sysctl.d/99-l4d2-network-base.conf
sysctl -p /etc/sysctl.d/99-l4d2-network-base.conf
```

### Problema: Pérdida de paquetes persistente

**Diagnóstico**:
```bash
# Ver estadísticas de pérdida
ethtool -S eth0 | grep -i drop
cat /proc/net/softnet_stat

# Ver cola de dispositivo de red
ip -s link show eth0
```

**Solución**:
```bash
# Aumentar backlog si hay pérdidas
echo 'net.core.netdev_max_backlog = 10000' >> /etc/sysctl.d/99-l4d2-network-base.conf
sysctl -p /etc/sysctl.d/99-l4d2-network-base.conf

# También verificar ring buffers del hardware
ethtool -g eth0
# Si es posible, aumentar:
ethtool -G eth0 rx 4096 tx 4096
```

## 📈 Monitoreo y Métricas

### Script de Monitoreo Continuo

```bash
#!/bin/bash
# Monitor de red base continuo
echo "Starting network base monitoring..."

while true; do
  echo "=== $(date) ==="
  
  # Estadísticas de paquetes
  echo "Packet statistics:"
  cat /proc/net/softnet_stat | awk '{
    total += $1; dropped += $2
  } END {
    print "  Total processed: " total
    print "  Total dropped: " dropped
    if (total > 0) print "  Drop rate: " (dropped/total)*100 "%"
  }'
  
  # Buffer usage
  echo "Buffer usage:"
  ss -m | grep -o 'mem:[0-9]*' | awk -F: '{sum += $2} END {print "  Total buffer memory: " sum " bytes"}'
  
  # Connection count
  echo "Active connections:"
  ss -s | grep TCP
  
  echo "---"
  sleep 60
done
```

### Alertas de Performance

```bash
#!/bin/bash
# Script de alertas para problemas de red base

# Umbral de pérdida de paquetes (%)
DROP_THRESHOLD=1.0

# Verificar pérdida de paquetes
total_processed=$(awk '{sum += $1} END {print sum}' /proc/net/softnet_stat)
total_dropped=$(awk '{sum += $2} END {print sum}' /proc/net/softnet_stat)

if [[ $total_processed -gt 0 ]]; then
  drop_rate=$(echo "scale=2; ($total_dropped/$total_processed)*100" | bc)
  
  if (( $(echo "$drop_rate > $DROP_THRESHOLD" | bc -l) )); then
    echo "WARNING: High packet drop rate: ${drop_rate}%" | logger -t network-base-monitor
    # Enviar alerta adicional si es necesario
  fi
fi

# Verificar uso de memoria en buffers
buffer_mem=$(ss -m | grep -o 'mem:[0-9]*' | awk -F: '{sum += $2} END {print sum}')
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
buffer_percentage=$(echo "scale=2; ($buffer_mem*1024/$total_mem)*100" | bc)

if (( $(echo "$buffer_percentage > 50" | bc -l) )); then
  echo "WARNING: High buffer memory usage: ${buffer_percentage}%" | logger -t network-base-monitor
fi
```

## 🔄 Reversión de Cambios

### Restaurar Configuración Original

```bash
# Eliminar configuración personalizada
sudo rm -f /etc/sysctl.d/99-l4d2-network-base.conf

# Restaurar valores por defecto del kernel
sudo sysctl net.core.rmem_max=212992
sudo sysctl net.core.wmem_max=212992  
sudo sysctl net.core.rmem_default=212992
sudo sysctl net.core.wmem_default=212992
sudo sysctl net.core.netdev_max_backlog=1000

# Recargar configuración del sistema
sudo sysctl --system
```

### Backup y Restauración

```bash
# Crear backup completo de configuración de red
#!/bin/bash
BACKUP_DIR="/var/lib/l4d2-optimizer/backups/network_base_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup de configuración actual
sysctl -a | grep -E "net.core" > "$BACKUP_DIR/sysctl_net_core.txt"
cp /etc/sysctl.d/99-l4d2-network-base.conf "$BACKUP_DIR/" 2>/dev/null

# Script de restauración
cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "Restoring network base configuration..."
sudo rm -f /etc/sysctl.d/99-l4d2-network-base.conf
sudo sysctl --system
echo "Network base configuration restored"
EOF
chmod +x "$BACKUP_DIR/restore.sh"
```

## 🧪 Testing y Benchmarking

### Test de Throughput de Red

```bash
#!/bin/bash
# Test de throughput con iperf3
echo "=== Network Throughput Test ==="

# Instalar iperf3 si no está disponible
command -v iperf3 >/dev/null || {
  echo "Installing iperf3..."
  sudo apt-get update && sudo apt-get install -y iperf3
}

# Test como servidor
echo "Starting iperf3 server (will run for 30 seconds)..."
timeout 30 iperf3 -s &
SERVER_PID=$!

sleep 2

# Test como cliente (localhost)
echo "Running throughput test..."
iperf3 -c localhost -t 10 -P 4

# Limpiar proceso servidor
kill $SERVER_PID 2>/dev/null
```

### Benchmark de Buffer Performance

```bash
#!/bin/bash
# Benchmark de rendimiento con diferentes tamaños de buffer

echo "=== Buffer Performance Benchmark ==="

BUFFER_SIZES=("16777216" "67108864" "134217728" "268435456")  # 16MB, 64MB, 128MB, 256MB

for buffer_size in "${BUFFER_SIZES[@]}"; do
  echo "Testing buffer size: $(($buffer_size / 1048576))MB"
  
  # Aplicar configuración temporal
  sudo sysctl net.core.rmem_max=$buffer_size
  sudo sysctl net.core.wmem_max=$buffer_size
  
  # Test de rendimiento (usando dd para simular transferencia)
  echo "  Testing write performance..."
  time_write=$(dd if=/dev/zero of=/tmp/buffer_test bs=1M count=100 2>&1 | grep copied | awk '{print $(NF-1)}')
  
  echo "  Testing read performance..."  
  time_read=$(dd if=/tmp/buffer_test of=/dev/null bs=1M 2>&1 | grep copied | awk '{print $(NF-1)}')
  
  echo "  Write: ${time_write} seconds"
  echo "  Read: ${time_read} seconds"
  echo "---"
  
  rm -f /tmp/buffer_test
done

# Restaurar configuración original
sudo sysctl -p /etc/sysctl.d/99-l4d2-network-base.conf
```

## 📚 Referencias Técnicas

### Documentación del Kernel

- [Linux Kernel Network Parameters](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
- [Socket Buffer Tuning](https://fasterdata.es.net/network-tuning/linux/)
- [Network Interface Queues](https://www.kernel.org/doc/html/latest/networking/scaling.html)

### Herramientas de Diagnóstico

- **ss**: Utilidad moderna para inspeccionar sockets
- **sysctl**: Control de parámetros del kernel
- **ethtool**: Control de interfaces de red
- **iperf3**: Herramienta de benchmark de red

### Mejores Prácticas

- **Buffer Sizing**: Basado en RAM disponible y carga esperada
- **Monitoring**: Vigilar uso de memoria y pérdida de paquetes
- **Testing**: Benchmarking antes y después de cambios
- **Documentation**: Mantener registro de configuraciones aplicadas

---

Este módulo establece las bases fundamentales para un rendimiento de red óptimo, siendo crucial para el funcionamiento efectivo de otros módulos de optimización de red más avanzados.
