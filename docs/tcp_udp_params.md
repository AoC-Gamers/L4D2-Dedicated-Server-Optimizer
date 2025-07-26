# Documentación del Módulo TCP/UDP Parameters

## 📖 Descripción General

El módulo **TCP/UDP Parameters** (`tcp_udp_params.sh`) optimiza los parámetros específicos de los protocolos TCP y UDP en el kernel Linux para maximizar el rendimiento de red en servidores de juegos. Incluye configuraciones avanzadas de ventanas TCP, buffers, algoritmos de control de congestión y optimizaciones específicas para UDP.

## 🎯 Objetivo

Optimizar los protocolos de transporte para:
- Maximizar throughput de conexiones TCP
- Minimizar latencia en comunicaciones UDP
- Optimizar control de congestión para gaming
- Mejorar gestión de buffers de socket específicos por protocolo
- Configurar parámetros para alta concurrencia

## ⚙️ Funcionamiento Técnico

### Optimizaciones TCP

#### 1. TCP Window Scaling y Buffers

```bash
# TCP Buffer Auto-tuning
net.ipv4.tcp_rmem = 4096 87380 134217728     # min default max (receive)
net.ipv4.tcp_wmem = 4096 65536 134217728     # min default max (send)

# TCP Window Scaling (RFC 1323)
net.ipv4.tcp_window_scaling = 1              # Enable window scaling
net.core.rmem_max = 134217728                # Max socket receive buffer  
net.core.wmem_max = 134217728                # Max socket send buffer
```

**Impacto**:
- **Auto-tuning**: Ajuste automático de buffers según condiciones de red
- **High Bandwidth**: Soporte para conexiones de alta velocidad
- **Window Scaling**: Ventanas TCP > 64KB para mejor throughput

#### 2. Control de Congestión

```bash
# Algoritmo de control de congestión
net.ipv4.tcp_congestion_control = bbr        # Bottleneck Bandwidth and RTT

# Parámetros de congestión
net.ipv4.tcp_slow_start_after_idle = 0       # No reduce cwnd after idle
net.ipv4.tcp_no_metrics_save = 1             # Don't cache metrics
```

**Algoritmos Disponibles**:
- **BBR**: Óptimo para gaming, minimiza latencia
- **CUBIC**: Por defecto, bueno para throughput general
- **Reno**: Clásico, compatible pero menos eficiente

#### 3. TCP Fast Open y Optimizaciones

```bash
# TCP Fast Open (RFC 7413)
net.ipv4.tcp_fastopen = 3                    # Enable client & server

# SYN/ACK optimizations
net.ipv4.tcp_syn_retries = 3                 # Reduce SYN retries
net.ipv4.tcp_synack_retries = 3              # Reduce SYN-ACK retries
net.ipv4.tcp_max_syn_backlog = 8192          # Increase SYN backlog
```

### Optimizaciones UDP

#### 1. UDP Buffer Sizing

```bash
# UDP-specific buffers (inherited from rmem/wmem)
net.core.rmem_default = 262144               # 256KB default receive
net.core.wmem_default = 262144               # 256KB default send
net.core.rmem_max = 134217728                # 128MB max receive
net.core.wmem_max = 134217728                # 128MB max send
```

#### 2. UDP Performance Tuning

```bash
# Increase UDP buffer limits
net.core.netdev_max_backlog = 5000           # Network device backlog
net.core.netdev_budget = 600                 # NAPI budget per round

# UDP-specific settings
net.ipv4.udp_mem = 102400 873800 16777216    # UDP memory thresholds
net.ipv4.udp_rmem_min = 8192                 # Min UDP receive buffer
net.ipv4.udp_wmem_min = 8192                 # Min UDP send buffer
```

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `TCP_CONGESTION_CONTROL` | Algoritmo de control de congestión | `bbr`, `cubic`, `reno` | `bbr` |
| `TCP_RMEM_MIN` | Buffer mínimo TCP recepción | 4096-65536 | `4096` |
| `TCP_RMEM_DEFAULT` | Buffer por defecto TCP recepción | 64KB-1MB | `87380` |
| `TCP_RMEM_MAX` | Buffer máximo TCP recepción | 1MB-1GB | `134217728` |
| `TCP_WMEM_MIN` | Buffer mínimo TCP envío | 4096-65536 | `4096` |
| `TCP_WMEM_DEFAULT` | Buffer por defecto TCP envío | 16KB-256KB | `65536` |
| `TCP_WMEM_MAX` | Buffer máximo TCP envío | 1MB-1GB | `134217728` |
| `TCP_FASTOPEN` | TCP Fast Open habilitado | 0-3 | `3` |
| `UDP_MEM_MIN` | Memoria UDP mínima (páginas) | 102400 | `102400` |
| `UDP_MEM_PRESSURE` | Presión de memoria UDP | 873800 | `873800` |
| `UDP_MEM_MAX` | Memoria UDP máxima | 16777216 | `16777216` |

### Ejemplo de Configuración (.env)

```bash
# TCP/UDP Parameters configuration for tcp_udp_params.sh module

# TCP Configuration
TCP_CONGESTION_CONTROL="bbr"                 # Congestion control algorithm (bbr, cubic, reno)
TCP_RMEM_MIN="4096"                          # TCP min receive buffer
TCP_RMEM_DEFAULT="87380"                     # TCP default receive buffer  
TCP_RMEM_MAX="134217728"                     # TCP max receive buffer (128MB)
TCP_WMEM_MIN="4096"                          # TCP min send buffer
TCP_WMEM_DEFAULT="65536"                     # TCP default send buffer
TCP_WMEM_MAX="134217728"                     # TCP max send buffer (128MB)
TCP_FASTOPEN="3"                             # Enable TCP Fast Open (0=disabled, 3=client+server)

# UDP Configuration  
UDP_MEM_MIN="102400"                         # UDP memory min threshold (pages)
UDP_MEM_PRESSURE="873800"                    # UDP memory pressure threshold (pages)
UDP_MEM_MAX="16777216"                       # UDP memory max threshold (pages)
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

#### TCP Optimizations:
- **Conexiones Steam**: Mejora descarga de updates y comunicación con Steam
- **Admin Connections**: Mejor rendimiento de conexiones RCON/SSH
- **Web Services**: APIs y servicios web más rápidos
- **File Transfers**: Transferencia de mapas/addons más eficiente

#### UDP Optimizations:
- **Gaming Traffic**: Optimización directa del tráfico de juego L4D2
- **Reduced Packet Loss**: Buffers más grandes para evitar pérdidas
- **Lower Latency**: Mejor manejo de paquetes en cola
- **Higher Player Count**: Soporte para más jugadores simultáneos

### Comparación de Algoritmos de Control de Congestión

| Algoritmo | Latencia | Throughput | Gaming | Uso Recomendado |
|-----------|----------|------------|--------|-----------------|
| **BBR** | Excelente | Muy Bueno | Óptimo | Servidores gaming |
| **CUBIC** | Bueno | Excelente | Bueno | Transferencias grandes |
| **Reno** | Regular | Bueno | Regular | Compatibilidad |

## 🛠️ Proceso de Instalación

### Paso 1: Detección de Algoritmos Disponibles

```bash
# Verificar algoritmos de control de congestión disponibles
echo "Available TCP congestion control algorithms:"
cat /proc/sys/net/ipv4/tcp_available_congestion_control

# Verificar algoritmo actual
echo "Current algorithm: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"

# Verificar si BBR está disponible
if grep -q "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
  echo "BBR is available"
  CONGESTION_ALGORITHM="bbr"
else
  echo "BBR not available, using cubic"
  CONGESTION_ALGORITHM="cubic"
fi
```

### Paso 2: Cálculo de Memoria para UDP

```bash
# Calcular límites de memoria UDP basado en RAM del sistema
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))

# Configurar UDP memory limits basado en RAM disponible
if [[ $TOTAL_MEM_MB -lt 2048 ]]; then
  # Sistemas con menos de 2GB
  UDP_MEM_MIN="51200"      # 200MB
  UDP_MEM_PRESSURE="436900" # 1.7GB
  UDP_MEM_MAX="8388608"    # 32GB
elif [[ $TOTAL_MEM_MB -lt 8192 ]]; then
  # Sistemas de 2-8GB
  UDP_MEM_MIN="102400"     # 400MB
  UDP_MEM_PRESSURE="873800" # 3.4GB  
  UDP_MEM_MAX="16777216"   # 64GB
else
  # Sistemas con más de 8GB
  UDP_MEM_MIN="204800"     # 800MB
  UDP_MEM_PRESSURE="1747600" # 6.8GB
  UDP_MEM_MAX="33554432"   # 128GB
fi
```

### Paso 3: Backup de Configuración Actual

```bash
# Backup de configuración TCP/UDP actual
echo "=== TCP/UDP Configuration Backup ===" > tcp_udp_params.backup.txt
sysctl -a | grep -E "net\.(ipv4\.tcp|ipv4\.udp|core\.(r|w)mem)" >> tcp_udp_params.backup.txt

# Estado de conexiones TCP/UDP
ss -tuln > tcp_udp_connections.backup.txt
netstat -s > network_statistics.backup.txt
```

### Paso 4: Aplicación de Configuración

```bash
# Configuración sysctl para TCP/UDP optimization
cat > /etc/sysctl.d/99-l4d2-tcp-udp.conf << EOF
# TCP/UDP Optimization for L4D2 Server

# TCP Buffer Configuration
net.ipv4.tcp_rmem = ${TCP_RMEM_MIN:-4096} ${TCP_RMEM_DEFAULT:-87380} ${TCP_RMEM_MAX:-134217728}
net.ipv4.tcp_wmem = ${TCP_WMEM_MIN:-4096} ${TCP_WMEM_DEFAULT:-65536} ${TCP_WMEM_MAX:-134217728}

# TCP Performance Optimizations
net.ipv4.tcp_congestion_control = ${TCP_CONGESTION_CONTROL:-bbr}
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1

# TCP Fast Open
net.ipv4.tcp_fastopen = ${TCP_FASTOPEN:-3}

# TCP Connection Handling
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1

# UDP Memory Configuration
net.ipv4.udp_mem = ${UDP_MEM_MIN:-102400} ${UDP_MEM_PRESSURE:-873800} ${UDP_MEM_MAX:-16777216}
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Core network buffers (affects both TCP and UDP)
net.core.rmem_max = ${TCP_RMEM_MAX:-134217728}
net.core.wmem_max = ${TCP_WMEM_MAX:-134217728}
net.core.rmem_default = 262144
net.core.wmem_default = 262144
EOF

# Aplicar configuración
sysctl -p /etc/sysctl.d/99-l4d2-tcp-udp.conf
```

### Paso 5: Verificación de BBR

```bash
# Verificar que BBR se cargó correctamente si fue seleccionado
if [[ "${TCP_CONGESTION_CONTROL}" == "bbr" ]]; then
  echo "Verifying BBR configuration..."
  
  # Cargar módulo BBR si no está disponible
  if ! grep -q "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo "Loading BBR kernel module..."
    modprobe tcp_bbr
    echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf
  fi
  
  # Verificar que BBR está activo
  current_algo=$(sysctl -n net.ipv4.tcp_congestion_control)
  if [[ "$current_algo" == "bbr" ]]; then
    echo "BBR successfully activated"
  else
    echo "Warning: BBR not active, current algorithm: $current_algo"
  fi
fi
```

## 📋 Archivos Modificados

### Archivos del Sistema

| Archivo | Propósito | Persistencia |
|---------|-----------|--------------|
| `/etc/sysctl.d/99-l4d2-tcp-udp.conf` | Configuración TCP/UDP | Permanente |
| `/etc/modules-load.d/bbr.conf` | Carga automática BBR | Permanente |
| `/proc/sys/net/ipv4/tcp_congestion_control` | Algoritmo de congestión | Runtime |
| `/proc/sys/net/ipv4/tcp_rmem` | Buffers TCP recepción | Runtime |
| `/proc/sys/net/ipv4/tcp_wmem` | Buffers TCP envío | Runtime |

### Ejemplo de Configuración Aplicada

```ini
# /etc/sysctl.d/99-l4d2-tcp-udp.conf
# TCP/UDP Optimization for L4D2 Server

# TCP receive buffer: min default max (bytes)
net.ipv4.tcp_rmem = 4096 87380 134217728

# TCP send buffer: min default max (bytes)  
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP performance features
net.ipv4.tcp_congestion_control = bbr       # BBR congestion control
net.ipv4.tcp_window_scaling = 1             # Enable window scaling
net.ipv4.tcp_timestamps = 1                 # Enable timestamps
net.ipv4.tcp_sack = 1                       # Selective ACK
net.ipv4.tcp_fack = 1                       # Forward ACK

# TCP Fast Open
net.ipv4.tcp_fastopen = 3                   # Enable client + server

# TCP connection optimization
net.ipv4.tcp_syn_retries = 3                # Reduce SYN retries
net.ipv4.tcp_synack_retries = 3             # Reduce SYN-ACK retries  
net.ipv4.tcp_max_syn_backlog = 8192         # Increase SYN backlog
net.ipv4.tcp_slow_start_after_idle = 0      # Don't reduce cwnd after idle
net.ipv4.tcp_no_metrics_save = 1            # Don't cache connection metrics

# UDP memory limits (pages: min pressure max)
net.ipv4.udp_mem = 102400 873800 16777216
net.ipv4.udp_rmem_min = 8192                # 8KB min UDP receive buffer
net.ipv4.udp_wmem_min = 8192                # 8KB min UDP send buffer
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Verificar configuración TCP
echo "=== TCP Configuration ==="
echo "Congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "TCP rmem: $(sysctl -n net.ipv4.tcp_rmem)"
echo "TCP wmem: $(sysctl -n net.ipv4.tcp_wmem)"
echo "TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen)"

# Verificar configuración UDP
echo -e "\n=== UDP Configuration ==="
echo "UDP mem: $(sysctl -n net.ipv4.udp_mem)"
echo "UDP rmem_min: $(sysctl -n net.ipv4.udp_rmem_min)"
echo "UDP wmem_min: $(sysctl -n net.ipv4.udp_wmem_min)"

# Ver conexiones activas por protocolo
echo -e "\n=== Active Connections ==="
ss -s

# Ver estadísticas de red
echo -e "\n=== Network Statistics ==="
cat /proc/net/snmp | grep -E "Tcp:|Udp:"
```

### Test de Control de Congestión

```bash
#!/bin/bash
# Test de control de congestión TCP

echo "=== TCP Congestion Control Test ==="

# Verificar algoritmo actual
current_algo=$(sysctl -n net.ipv4.tcp_congestion_control)
echo "Current algorithm: $current_algo"

# Mostrar algoritmos disponibles
echo "Available algorithms:"
cat /proc/sys/net/ipv4/tcp_available_congestion_control

# Test de throughput con algoritmo actual
if command -v iperf3 >/dev/null 2>&1; then
  echo -e "\nTesting throughput with $current_algo..."
  
  # Iniciar servidor iperf3 en background
  iperf3 -s -p 5555 -D
  sleep 2
  
  # Test de cliente
  result=$(iperf3 -c localhost -p 5555 -t 10 -f M | grep "receiver" | awk '{print $7, $8}')
  echo "Throughput: $result"
  
  # Limpiar proceso servidor
  pkill -f "iperf3 -s"
else
  echo "iperf3 not available for throughput testing"
fi

# Verificar métricas de congestión si BBR está activo
if [[ "$current_algo" == "bbr" ]]; then
  echo -e "\nBBR specific information:"
  # BBR metrics (requiere kernel con soporte extendido)
  ss -i | grep -A 1 "bbr" | head -5
fi
```

## ⚠️ Consideraciones Importantes

### Compatibilidad de BBR

BBR requiere kernel Linux 4.9+ y puede necesitar habilitación manual:

```bash
# Verificar versión del kernel
echo "Kernel version: $(uname -r)"

# Verificar si BBR está compilado en el kernel
if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
  if grep -q "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo "BBR is available"
  else
    echo "BBR not available in this kernel"
    echo "Consider upgrading kernel or using cubic instead"
  fi
fi
```

### Memoria UDP

Los límites de memoria UDP altos pueden consumir RAM significativa:

```bash
# Calcular uso potencial de memoria UDP
UDP_MAX_PAGES=$(sysctl -n net.ipv4.udp_mem | awk '{print $3}')
PAGE_SIZE=$(getconf PAGESIZE)
UDP_MAX_BYTES=$((UDP_MAX_PAGES * PAGE_SIZE))

echo "UDP maximum memory: $((UDP_MAX_BYTES / 1048576))MB"

# Monitorear uso actual
cat /proc/net/sockstat | grep UDP
```

### Interacción con Firewall

```bash
# Verificar que el firewall no interfiere con TCP Fast Open
if systemctl is-active iptables >/dev/null 2>&1; then
  echo "iptables is active - verify TFO compatibility"
  iptables -L -n | grep -i tcp
fi

# Configuración específica para iptables con TFO
# iptables -A INPUT -p tcp --tcp-flags SYN SYN --tcp-option 34 -j ACCEPT
```

## 🐛 Solución de Problemas

### Problema: BBR no se activa

**Diagnóstico**:
```bash
# Verificar módulo BBR
lsmod | grep bbr
dmesg | grep -i bbr

# Verificar configuración actual
sysctl net.ipv4.tcp_congestion_control
cat /proc/sys/net/ipv4/tcp_available_congestion_control
```

**Solución**:
```bash
# Cargar módulo BBR manualmente
sudo modprobe tcp_bbr

# Agregar a carga automática
echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf

# Verificar carga después de reinicio
sudo systemctl reboot

# Verificar después del reinicio
sysctl net.ipv4.tcp_congestion_control
```

### Problema: Alto uso de memoria por buffers TCP/UDP

**Diagnóstico**:
```bash
# Ver uso de memoria por sockets
cat /proc/net/sockstat

# Ver buffers por conexión
ss -m | head -20

# Ver memoria total usada por red
cat /proc/meminfo | grep -i net
```

**Solución**:
```bash
# Reducir buffers máximos si hay problemas de memoria
echo 'net.ipv4.tcp_rmem = 4096 87380 67108864' >> /etc/sysctl.d/99-l4d2-tcp-udp.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 67108864' >> /etc/sysctl.d/99-l4d2-tcp-udp.conf
sysctl -p /etc/sysctl.d/99-l4d2-tcp-udp.conf

# Monitorear impacto
watch -n 5 'free -h && echo "---" && cat /proc/net/sockstat'
```

### Problema: Pérdida de paquetes UDP

**Diagnóstico**:
```bash
# Ver estadísticas UDP
cat /proc/net/snmp | grep Udp:
netstat -su | grep -i udp

# Ver buffer overflows
ss -u -a -n | grep -c UNCONN
cat /proc/net/udp
```

**Solución**:
```bash
# Aumentar buffers UDP
echo 'net.ipv4.udp_rmem_min = 16384' >> /etc/sysctl.d/99-l4d2-tcp-udp.conf
echo 'net.core.netdev_max_backlog = 10000' >> /etc/sysctl.d/99-l4d2-tcp-udp.conf
sysctl -p /etc/sysctl.d/99-l4d2-tcp-udp.conf

# Verificar reducción de pérdidas
watch -n 2 'cat /proc/net/snmp | grep Udp:'
```

## 📈 Benchmarking y Monitoreo

### Benchmark de Rendimiento TCP

```bash
#!/bin/bash
# Benchmark completo de rendimiento TCP

echo "=== TCP Performance Benchmark ==="

# Algoritmos a probar
ALGORITHMS=("cubic" "bbr" "reno")

# Si iperf3 no está disponible, instalarlo
if ! command -v iperf3 >/dev/null 2>&1; then
  echo "Installing iperf3..."
  sudo apt-get update && sudo apt-get install -y iperf3
fi

for algo in "${ALGORITHMS[@]}"; do
  # Verificar si el algoritmo está disponible
  if ! grep -q "$algo" /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo "Algorithm $algo not available, skipping..."
    continue
  fi
  
  echo "Testing algorithm: $algo"
  
  # Cambiar algoritmo temporalmente
  sudo sysctl net.ipv4.tcp_congestion_control=$algo
  
  # Iniciar servidor iperf3
  iperf3 -s -p 5555 >/dev/null 2>&1 &
  SERVER_PID=$!
  sleep 2
  
  # Test de throughput
  echo "  Throughput test..."
  throughput=$(iperf3 -c localhost -p 5555 -t 10 -f M 2>/dev/null | grep "receiver" | awk '{print $7}')
  echo "    Throughput: ${throughput} Mbits/sec"
  
  # Test de latencia (RTT)
  echo "  Latency test..."
  latency=$(ping -c 10 -i 0.1 localhost 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
  echo "    Average RTT: ${latency} ms"
  
  # Limpiar servidor
  kill $SERVER_PID 2>/dev/null
  wait $SERVER_PID 2>/dev/null
  
  echo "---"
  sleep 2
done

# Restaurar configuración original
sudo sysctl -p /etc/sysctl.d/99-l4d2-tcp-udp.conf
echo "Benchmark completed - configuration restored"
```

### Monitor de Conexiones UDP

```bash
#!/bin/bash
# Monitor específico para tráfico UDP (gaming)

echo "Starting UDP gaming traffic monitor..."

# Función para mostrar estadísticas UDP
show_udp_stats() {
  echo "=== $(date) ==="
  
  # Estadísticas generales UDP
  echo "UDP Statistics:"
  netstat -su | grep -A 10 "Udp:" | head -10
  
  # Conexiones UDP activas (L4D2 típicamente usa puerto 27015)
  echo -e "\nActive UDP connections:"
  ss -u -n | grep -E ":27015|:27005" | wc -l | xargs echo "  Gaming ports:"
  
  # Uso de memoria UDP
  echo -e "\nUDP Memory usage:"
  cat /proc/net/sockstat | grep UDP
  
  # Buffer overflows (indicador de pérdida de paquetes)
  echo -e "\nBuffer status:"
  UDP_DROPS_BEFORE=$(cat /proc/net/snmp | grep "Udp:" | tail -1 | awk '{print $4}')
  sleep 1
  UDP_DROPS_AFTER=$(cat /proc/net/snmp | grep "Udp:" | tail -1 | awk '{print $4}')
  
  if [[ $UDP_DROPS_AFTER -gt $UDP_DROPS_BEFORE ]]; then
    echo "  WARNING: UDP packet drops detected!"
  else
    echo "  No packet drops in last second"
  fi
  
  echo "---"
}

# Monitor continuo
while true; do
  show_udp_stats
  sleep 10
done
```

### Dashboard de TCP/UDP

```bash
#!/bin/bash
# Dashboard completo de TCP/UDP

dashboard_tcp_udp() {
  clear
  echo "==============================================="
  echo "      L4D2 TCP/UDP Performance Monitor"
  echo "==============================================="
  echo ""
  
  # Configuración actual
  echo "Current Configuration:"
  echo "  TCP Congestion: $(sysctl -n net.ipv4.tcp_congestion_control)"
  echo "  TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen)"
  echo "  TCP rmem: $(sysctl -n net.ipv4.tcp_rmem)"
  echo "  UDP mem: $(sysctl -n net.ipv4.udp_mem)"
  echo ""
  
  # Conexiones activas
  echo "Active Connections:"
  CONNECTION_STATS=$(ss -s)
  echo "$CONNECTION_STATS" | grep -E "TCP:|UDP:"
  echo ""
  
  # Estadísticas de protocolo
  echo "Protocol Statistics:"
  TCP_STATS=$(cat /proc/net/snmp | grep "Tcp:" | tail -1)
  UDP_STATS=$(cat /proc/net/snmp | grep "Udp:" | tail -1)
  
  # Parse TCP stats (ActiveOpens, PassiveOpens, CurrentEstab, OutSegs, InSegs)
  TCP_ACTIVE=$(echo $TCP_STATS | awk '{print $6}')
  TCP_PASSIVE=$(echo $TCP_STATS | awk '{print $7}')
  TCP_CURRENT=$(echo $TCP_STATS | awk '{print $10}')
  
  echo "  TCP Active Opens: $TCP_ACTIVE"
  echo "  TCP Passive Opens: $TCP_PASSIVE"  
  echo "  TCP Current Established: $TCP_CURRENT"
  
  # Parse UDP stats (InDatagrams, OutDatagrams, InErrors)
  UDP_IN=$(echo $UDP_STATS | awk '{print $2}')
  UDP_OUT=$(echo $UDP_STATS | awk '{print $5}')
  UDP_ERRORS=$(echo $UDP_STATS | awk '{print $4}')
  
  echo "  UDP In Datagrams: $UDP_IN"
  echo "  UDP Out Datagrams: $UDP_OUT"
  echo "  UDP Errors: $UDP_ERRORS"
  echo ""
  
  # Uso de memoria por sockets
  echo "Socket Memory Usage:"
  cat /proc/net/sockstat | grep -E "TCP:|UDP:"
  echo ""
  
  # Gaming-specific ports (L4D2)
  echo "Gaming Traffic (L4D2 ports):"
  L4D2_CONNECTIONS=$(ss -u -n | grep -c ":27015")
  STEAM_CONNECTIONS=$(ss -t -n | grep -c ":27030")
  echo "  UDP :27015 connections: $L4D2_CONNECTIONS"
  echo "  TCP :27030 connections: $STEAM_CONNECTIONS"
}

# Ejecutar dashboard
while true; do
  dashboard_tcp_udp
  sleep 5
done
```

## 📊 Métricas de Performance

### Script de Métricas Automatizado

```bash
#!/bin/bash
# Script para recopilar métricas de performance TCP/UDP

METRICS_DIR="/var/log/l4d2-optimizer/tcp-udp-metrics"
mkdir -p "$METRICS_DIR"

# Función para recopilar métricas
collect_metrics() {
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local metrics_file="$METRICS_DIR/metrics_$timestamp.txt"
  
  echo "=== TCP/UDP Metrics Collection: $(date) ===" > "$metrics_file"
  
  # Configuración actual
  echo -e "\n--- Configuration ---" >> "$metrics_file"
  sysctl -a | grep -E "net\.ipv4\.(tcp|udp)" >> "$metrics_file"
  
  # Estadísticas de conexión
  echo -e "\n--- Connection Statistics ---" >> "$metrics_file"
  ss -s >> "$metrics_file"
  
  # Estadísticas de protocolo
  echo -e "\n--- Protocol Statistics ---" >> "$metrics_file"
  cat /proc/net/snmp >> "$metrics_file"
  
  # Uso de memoria
  echo -e "\n--- Memory Usage ---" >> "$metrics_file"
  cat /proc/net/sockstat >> "$metrics_file"
  
  # Conexiones gaming específicas
  echo -e "\n--- Gaming Connections ---" >> "$metrics_file"
  ss -tuln | grep -E ":27015|:27005|:27030" >> "$metrics_file"
  
  echo "Metrics collected: $metrics_file"
}

# Función para generar reporte de performance
generate_performance_report() {
  echo "=== TCP/UDP Performance Report ==="
  
  # Algoritmo de congestión y su efectividad
  current_algo=$(sysctl -n net.ipv4.tcp_congestion_control)
  echo "Current TCP congestion control: $current_algo"
  
  # Throughput estimado (basado en configuración de buffers)
  tcp_max_buf=$(sysctl -n net.ipv4.tcp_rmem | awk '{print $3}')
  estimated_throughput=$((tcp_max_buf * 8 / 1048576))  # Convert to Mbps estimate
  echo "Estimated max throughput per connection: ~${estimated_throughput} Mbps"
  
  # Análisis de pérdida de paquetes
  udp_in_errors=$(cat /proc/net/snmp | grep "Udp:" | tail -1 | awk '{print $4}')
  udp_in_datagrams=$(cat /proc/net/snmp | grep "Udp:" | tail -1 | awk '{print $2}')
  
  if [[ $udp_in_datagrams -gt 0 ]]; then
    error_rate=$(echo "scale=4; ($udp_in_errors * 100) / $udp_in_datagrams" | bc)
    echo "UDP error rate: ${error_rate}%"
    
    if (( $(echo "$error_rate > 0.1" | bc -l) )); then
      echo "WARNING: High UDP error rate detected"
    fi
  fi
  
  # Recomendaciones basadas en uso
  tcp_established=$(ss -s | grep "TCP:" | awk '{print $4}' | tr -d ',')
  udp_connections=$(ss -s | grep "UDP:" | awk '{print $2}' | tr -d ',')
  
  echo -e "\nActive connections:"
  echo "  TCP established: $tcp_established"
  echo "  UDP connections: $udp_connections"
  
  # Recomendaciones
  echo -e "\nRecommendations:"
  if [[ $tcp_established -gt 1000 ]]; then
    echo "  - High TCP connection count: consider increasing tcp_max_syn_backlog"
  fi
  
  if [[ $udp_connections -gt 500 ]]; then
    echo "  - High UDP connection count: monitor UDP memory usage"
  fi
  
  if [[ "$current_algo" != "bbr" ]]; then
    echo "  - Consider switching to BBR congestion control for gaming"
  fi
}

# Ejecutar recopilación de métricas
collect_metrics

# Generar reporte
generate_performance_report
```

## 🔄 Reversión y Backup

### Script de Backup y Restauración

```bash
#!/bin/bash
# Backup completo de configuración TCP/UDP

BACKUP_DIR="/var/lib/l4d2-optimizer/backups/tcp_udp_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creating TCP/UDP configuration backup in $BACKUP_DIR"

# Backup de configuración sysctl
sysctl -a | grep -E "net\.ipv4\.(tcp|udp)" > "$BACKUP_DIR/sysctl_tcp_udp.txt"
sysctl -a | grep -E "net\.core\.(r|w)mem" > "$BACKUP_DIR/sysctl_buffers.txt"

# Backup de archivos de configuración
cp /etc/sysctl.d/99-l4d2-tcp-udp.conf "$BACKUP_DIR/" 2>/dev/null
cp /etc/modules-load.d/bbr.conf "$BACKUP_DIR/" 2>/dev/null

# Estado actual de red
ss -s > "$BACKUP_DIR/connection_summary.txt"
cat /proc/net/snmp > "$BACKUP_DIR/protocol_statistics.txt"
cat /proc/net/sockstat > "$BACKUP_DIR/socket_usage.txt"

# Crear script de restauración
cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "Restoring TCP/UDP configuration..."

# Eliminar configuraciones personalizadas
sudo rm -f /etc/sysctl.d/99-l4d2-tcp-udp.conf
sudo rm -f /etc/modules-load.d/bbr.conf

# Restaurar valores por defecto del kernel
sudo sysctl net.ipv4.tcp_congestion_control=cubic
sudo sysctl net.ipv4.tcp_rmem="4096 16384 4194304"
sudo sysctl net.ipv4.tcp_wmem="4096 16384 4194304"
sudo sysctl net.ipv4.tcp_fastopen=1
sudo sysctl net.ipv4.udp_mem="102400 873800 16777216"

# Recargar configuración del sistema
sudo sysctl --system

echo "TCP/UDP configuration restored to defaults"
echo "Current configuration:"
sysctl net.ipv4.tcp_congestion_control
sysctl net.ipv4.tcp_rmem
sysctl net.ipv4.tcp_wmem
EOF

chmod +x "$BACKUP_DIR/restore.sh"
echo "Backup completed. To restore, run: $BACKUP_DIR/restore.sh"
```

## 📚 Referencias Técnicas

### Documentación del Kernel

- [TCP Implementation in Linux](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
- [BBR Congestion Control](https://github.com/google/bbr)
- [TCP Fast Open RFC 7413](https://tools.ietf.org/html/rfc7413)
- [UDP Performance Tuning](https://fasterdata.es.net/network-tuning/udp-tuning/)

### Herramientas de Diagnóstico

- **ss**: Estadísticas avanzadas de sockets
- **iperf3**: Benchmarking de throughput de red
- **netstat**: Estadísticas de red tradicionales  
- **tcpdump**: Captura y análisis de paquetes

### Algoritmos de Control de Congestión

- **BBR**: Diseñado por Google, optimiza latencia y throughput
- **CUBIC**: Por defecto en Linux, optimizado para redes de alta velocidad
- **Reno**: Implementación clásica, compatible pero menos eficiente
- **Vegas**: Optimizado para latencia baja

### Mejores Prácticas Gaming

- **BBR para Gaming**: Mejor balance latencia/throughput
- **Fast Open**: Reduce latencia de establecimiento de conexión
- **Buffer Tuning**: Basado en ancho de banda y latencia esperados
- **UDP Optimization**: Crítico para tráfico de juego en tiempo real

---

Este módulo completa las optimizaciones de red a nivel de protocolo, trabajando en conjunto con los módulos de red base y avanzada para proporcionar el máximo rendimiento de red para servidores L4D2.
