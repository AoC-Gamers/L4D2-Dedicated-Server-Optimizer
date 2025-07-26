# Documentación del Módulo Swap Optimization

## 📖 Descripción General

El módulo **Swap Optimization** (`swap_opt.sh`) configura el comportamiento de la memoria virtual (swap) del sistema para optimizar el rendimiento en servidores de juegos. Ajusta la tendencia del kernel a usar swap y optimiza parámetros relacionados con la gestión de memoria virtual.

## 🎯 Objetivo

Optimizar el manejo de memoria virtual para:
- Minimizar el uso de swap para mantener datos en RAM
- Reducir latencia causada por acceso a disco (swap)
- Mejorar predictabilidad de rendimiento del servidor
- Optimizar gestión de memoria para aplicaciones en tiempo real

## ⚙️ Funcionamiento Técnico

### Parámetros de Swap Optimizados

#### 1. Swappiness (Tendencia a usar Swap)

```bash
# Valor por defecto del sistema: 60
vm.swappiness = 10

# Significado de valores:
# 0   = Usar swap solo en emergencia (no recomendado)
# 1   = Swap mínimo, preferir liberar cache
# 10  = Muy poco swap, mantener procesos en RAM
# 30  = Poco swap, balance entre RAM y cache  
# 60  = Balance por defecto del kernel
# 100 = Usar swap agresivamente
```

**Impacto en Gaming**:
- **Valor 10**: Mantiene procesos del servidor en RAM
- **Menor Latencia**: Evita delays por lectura desde disco
- **Consistencia**: Rendimiento más predecible
- **Cache Preservation**: Mantiene cache de archivos importante

#### 2. VFS Cache Pressure

```bash
# Presión en cache del sistema de archivos virtual
vm.vfs_cache_pressure = 50

# Valores:
# < 100 = Preservar cache de inodos y dentries más tiempo
# = 100 = Balance por defecto (no cambiar)
# > 100 = Liberar cache más agresivamente
```

**Propósito**:
- **Cache de Metadata**: Preserva información de archivos en memoria
- **Acceso a Archivos**: Mejora velocidad de acceso a mapas/recursos
- **Balance**: Entre cache y memoria libre para aplicaciones

#### 3. Dirty Ratios (Memoria Sucia)

```bash
# Porcentaje de RAM que puede estar "dirty" antes de escribir
vm.dirty_ratio = 15              # Por defecto: 20
vm.dirty_background_ratio = 5    # Por defecto: 10

# Memoria "dirty" = datos modificados pendientes de escritura a disco
```

**Gaming Impact**:
- **Menor Buffer**: Writes más frecuentes pero menores
- **Responsividad**: Sistema no se bloquea esperando writes masivos
- **I/O Consistency**: Distribución más uniforme de operaciones de disco

## 🔧 Variables de Configuración

| Variable | Descripción | Rango | Por Defecto |
|----------|-------------|-------|-------------|
| `MEMORY_SWAPPINESS` | Tendencia a usar swap | 1-100 | `10` |
| `MEMORY_VFS_CACHE_PRESSURE` | Presión en cache VFS | 1-200 | `50` |
| `MEMORY_DIRTY_RATIO` | % RAM dirty antes de sync | 1-40 | `15` |
| `MEMORY_DIRTY_BACKGROUND_RATIO` | % RAM dirty para background writes | 1-20 | `5` |

### Ejemplo de Configuración (.env)

```bash
# Swap optimization configuration for swap_opt.sh module
MEMORY_SWAPPINESS="10"                    # Low swappiness for gaming (1-100, lower = less swap)
MEMORY_VFS_CACHE_PRESSURE="50"           # VFS cache pressure (1-200, lower = more cache)
MEMORY_DIRTY_RATIO="15"                  # Dirty memory ratio (1-40)
MEMORY_DIRTY_BACKGROUND_RATIO="5"       # Background dirty ratio (1-20)
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Latencia Consistente**: Mantiene procesos críticos en RAM
- **Sin Micro-Freezes**: Evita delays por swap durante picos de uso
- **Mejor Framerate**: Servidor mantiene performance estable
- **Responsividad**: Sistema responde más rápido a comandos
- **Previsibilidad**: Comportamiento más consistente bajo carga

### Comparación de Swappiness Values

| Swappiness | RAM Usage | Swap Usage | Gaming Performance | Uso Recomendado |
|------------|-----------|------------|-------------------|-----------------|
| **1** | Máximo | Mínimo | Excelente | Alta RAM disponible |
| **10** | Alto | Muy Bajo | Muy Bueno | Servidores gaming |
| **30** | Medio-Alto | Bajo | Bueno | Uso general |
| **60** | Medio | Medio | Regular | Por defecto sistema |
| **100** | Bajo | Alto | Pobre | Sistemas con poca RAM |

## 🛠️ Proceso de Instalación

### Paso 1: Análisis de Memoria del Sistema

```bash
# Verificar memoria total y swap disponible
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_SWAP=$(grep SwapTotal /proc/meminfo | awk '{print $2}')

echo "System Memory Analysis:"
echo "  Total RAM: $((TOTAL_RAM / 1024))MB"
echo "  Total Swap: $((TOTAL_SWAP / 1024))MB"

# Verificar swappiness actual
CURRENT_SWAPPINESS=$(sysctl -n vm.swappiness)
echo "  Current swappiness: $CURRENT_SWAPPINESS"
```

### Paso 2: Backup de Configuración Actual

```bash
# Backup de configuración de memoria actual
echo "=== Memory Configuration Backup ===" > memory_config.backup.txt
sysctl -a | grep -E "vm\.(swappiness|vfs_cache_pressure|dirty)" >> memory_config.backup.txt

# Estado actual de memoria
free -h > memory_usage.backup.txt
cat /proc/meminfo > meminfo.backup.txt
swapon --show > swap_devices.backup.txt
```

### Paso 3: Detección de Dispositivos Swap

```bash
# Detectar dispositivos de swap activos
SWAP_DEVICES=$(swapon --show=NAME --noheadings)

if [[ -n "$SWAP_DEVICES" ]]; then
  echo "Active swap devices found:"
  swapon --show
  
  # Verificar tipo de dispositivo (SSD vs HDD)
  for device in $SWAP_DEVICES; do
    DEVICE_TYPE=$(lsblk -d -o name,rota "$device" 2>/dev/null | tail -1 | awk '{print $2}')
    if [[ "$DEVICE_TYPE" == "0" ]]; then
      echo "  $device: SSD (better for limited swap)"
    else
      echo "  $device: HDD (slower, minimize swap usage)"
    fi
  done
else
  echo "No swap devices found - system using RAM only"
fi
```

### Paso 4: Aplicación de Configuración Optimizada

```bash
# Configuración sysctl para swap optimization
cat > /etc/sysctl.d/99-l4d2-swap-opt.conf << EOF
# Swap Optimization for L4D2 Server
# Minimize swap usage for gaming performance

# Swappiness - tendencia a usar swap (lower = less swap)
vm.swappiness = ${MEMORY_SWAPPINESS:-10}

# VFS cache pressure - preservar cache de filesystem
vm.vfs_cache_pressure = ${MEMORY_VFS_CACHE_PRESSURE:-50}

# Dirty memory ratios - control de escrituras a disco
vm.dirty_ratio = ${MEMORY_DIRTY_RATIO:-15}
vm.dirty_background_ratio = ${MEMORY_DIRTY_BACKGROUND_RATIO:-5}

# Additional memory management optimizations
vm.dirty_expire_centisecs = 3000        # 30 seconds - expire dirty pages
vm.dirty_writeback_centisecs = 500      # 5 seconds - writeback interval
EOF

# Aplicar configuración
sysctl -p /etc/sysctl.d/99-l4d2-swap-opt.conf
```

### Paso 5: Validación de Configuración

```bash
echo "=== Swap Optimization Applied ==="
echo "Swappiness: $(sysctl -n vm.swappiness)"
echo "VFS Cache Pressure: $(sysctl -n vm.vfs_cache_pressure)"
echo "Dirty Ratio: $(sysctl -n vm.dirty_ratio)%"
echo "Dirty Background Ratio: $(sysctl -n vm.dirty_background_ratio)%"

echo -e "\nMemory Usage:"
free -h
```

## 📋 Archivos Modificados

### Archivos del Sistema

| Archivo | Propósito | Persistencia |
|---------|-----------|--------------|
| `/etc/sysctl.d/99-l4d2-swap-opt.conf` | Configuración de optimización swap | Permanente |
| `/proc/sys/vm/swappiness` | Control de uso de swap | Runtime |
| `/proc/sys/vm/vfs_cache_pressure` | Presión de cache VFS | Runtime |
| `/proc/sys/vm/dirty_ratio` | Ratio de memoria dirty | Runtime |

### Ejemplo de Configuración Aplicada

```ini
# /etc/sysctl.d/99-l4d2-swap-opt.conf
# Swap Optimization for L4D2 Server

# Minimize swap usage for consistent gaming performance
vm.swappiness = 10                      # Prefer RAM over swap

# Filesystem cache management  
vm.vfs_cache_pressure = 50              # Moderate cache pressure

# Dirty memory management for smooth I/O
vm.dirty_ratio = 15                     # 15% RAM dirty before sync
vm.dirty_background_ratio = 5           # 5% RAM dirty for background writes

# Write timing optimization
vm.dirty_expire_centisecs = 3000        # 30 seconds dirty page lifetime
vm.dirty_writeback_centisecs = 500      # 5 seconds background write interval
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Ver configuración actual de swap
echo "=== Swap Configuration ==="
sysctl vm.swappiness vm.vfs_cache_pressure
sysctl vm.dirty_ratio vm.dirty_background_ratio

# Ver uso actual de memoria y swap
echo -e "\n=== Memory Usage ==="
free -h

# Ver información detallada de memoria
echo -e "\n=== Detailed Memory Info ==="
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Dirty|Writeback)"

# Ver dispositivos de swap activos
echo -e "\n=== Active Swap Devices ==="
swapon --show

# Ver estadísticas de swap (swaps realizados)
echo -e "\n=== Swap Statistics ==="
cat /proc/vmstat | grep -E "(pswpin|pswpout)"
```

### Monitor de Uso de Swap

```bash
#!/bin/bash
# Monitor continuo de uso de swap y memoria
echo "Starting swap monitoring..."

# Función para formato human-readable
human_readable() {
  local kb=$1
  if [[ $kb -gt 1048576 ]]; then
    echo "$(($kb / 1048576))GB"
  elif [[ $kb -gt 1024 ]]; then
    echo "$(($kb / 1024))MB"
  else
    echo "${kb}KB"
  fi
}

while true; do
  echo "=== $(date) ==="
  
  # Memoria y swap
  MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
  SWAP_USED=$(grep SwapFree /proc/meminfo | awk '{print $2}')
  SWAP_USED=$((SWAP_TOTAL - SWAP_USED))
  
  echo "Memory: $(human_readable $MEM_FREE) free of $(human_readable $MEM_TOTAL)"
  echo "Swap: $(human_readable $SWAP_USED) used of $(human_readable $SWAP_TOTAL)"
  
  # Porcentaje de uso
  if [[ $MEM_TOTAL -gt 0 ]]; then
    MEM_USED_PCT=$(echo "scale=1; (($MEM_TOTAL - $MEM_FREE) * 100) / $MEM_TOTAL" | bc)
    echo "Memory usage: ${MEM_USED_PCT}%"
  fi
  
  if [[ $SWAP_TOTAL -gt 0 ]]; then
    SWAP_USED_PCT=$(echo "scale=1; ($SWAP_USED * 100) / $SWAP_TOTAL" | bc)
    echo "Swap usage: ${SWAP_USED_PCT}%"
  fi
  
  # Memoria dirty
  DIRTY=$(grep "^Dirty:" /proc/meminfo | awk '{print $2}')
  echo "Dirty memory: $(human_readable $DIRTY)"
  
  echo "---"
  sleep 30
done
```

## ⚠️ Consideraciones Importantes

### Sistemas con Poca RAM

Para sistemas con menos de 2GB de RAM:

```bash
# Configuración alternativa para sistemas con poca memoria
vm.swappiness = 30              # Un poco más de swap permitido
vm.vfs_cache_pressure = 100     # Cache pressure normal
vm.dirty_ratio = 10             # Menos dirty memory
vm.dirty_background_ratio = 3   # Background writes más tempranos
```

### Sistemas sin Swap

```bash
# Verificar si el sistema tiene swap
if [[ $(swapon --show | wc -l) -eq 0 ]]; then
  echo "WARNING: No swap detected. System relies entirely on RAM."
  echo "Consider adding swap file for emergency situations:"
  echo "  sudo fallocate -l 2G /swapfile"
  echo "  sudo chmod 600 /swapfile"
  echo "  sudo mkswap /swapfile"
  echo "  sudo swapon /swapfile"
fi
```

### Monitoreo de OOM (Out of Memory)

```bash
# Verificar si ha habido eventos OOM
echo "=== OOM Events Check ==="
dmesg | grep -i "killed process" | tail -5

# Monitor de procesos con alto uso de memoria
echo -e "\n=== Top Memory Consumers ==="
ps aux --sort=-%mem | head -10
```

## 🐛 Solución de Problemas

### Problema: Sistema usa demasiado swap

**Diagnóstico**:
```bash
# Verificar qué procesos están usando swap
echo "=== Processes using swap ==="
for file in /proc/*/status; do
  awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' "$file" 2>/dev/null
done | sort -k2 -nr | head -10

# Ver swappiness actual
sysctl vm.swappiness
```

**Solución**:
```bash
# Reducir swappiness temporalmente
sudo sysctl vm.swappiness=5

# Si persiste, verificar memoria RAM insuficiente
free -h
top -o %MEM

# Considerar agregar más RAM o optimizar aplicaciones
```

### Problema: Sistema lento por I/O blocking

**Diagnóstico**:
```bash
# Ver procesos bloqueados en I/O
ps aux | awk '$8 ~ /D/ { print $0 }'

# Ver estadísticas de I/O
iostat -x 1 5

# Ver dirty memory actual
cat /proc/meminfo | grep -i dirty
```

**Solución**:
```bash
# Reducir ratios de dirty memory
echo 'vm.dirty_ratio = 10' >> /etc/sysctl.d/99-l4d2-swap-opt.conf
echo 'vm.dirty_background_ratio = 3' >> /etc/sysctl.d/99-l4d2-swap-opt.conf
sysctl -p /etc/sysctl.d/99-l4d2-swap-opt.conf

# Verificar dispositivos de almacenamiento
lsblk
iostat -x
```

### Problema: Cache VFS insuficiente

**Diagnóstico**:
```bash
# Ver uso de cache
cat /proc/meminfo | grep -E "(Buffers|Cached)"

# Ver hit rate de cache
echo 3 > /proc/sys/vm/drop_caches  # Limpiar cache para test
# Ejecutar carga de trabajo típica
# Medir rendimiento

# Ver presión de cache actual
sysctl vm.vfs_cache_pressure
```

**Solución**:
```bash
# Reducir presión de cache para preservar más tiempo
echo 'vm.vfs_cache_pressure = 25' >> /etc/sysctl.d/99-l4d2-swap-opt.conf
sysctl -p /etc/sysctl.d/99-l4d2-swap-opt.conf

# Monitorear impacto en uso de memoria
watch -n 5 'free -h && echo "---" && cat /proc/meminfo | grep -E "(Buffers|Cached)"'
```

## 📈 Benchmarking y Testing

### Test de Rendimiento de Memoria

```bash
#!/bin/bash
# Benchmark de rendimiento con diferentes configuraciones de swap

echo "=== Memory Performance Benchmark ==="

# Configuraciones a probar
SWAPPINESS_VALUES=(1 10 30 60)

for swappiness in "${SWAPPINESS_VALUES[@]}"; do
  echo "Testing swappiness = $swappiness"
  
  # Aplicar configuración temporal
  sudo sysctl vm.swappiness=$swappiness
  
  # Limpiar caches para test limpio
  sync
  echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
  
  # Test de rendimiento de memoria (allocate 1GB)
  echo "  Memory allocation test (1GB)..."
  time_alloc=$(time -p python3 -c "
import time
data = []
for i in range(10):
    # Allocate 100MB
    data.append(b'x' * (100 * 1024 * 1024))
    time.sleep(0.1)
print('Memory allocated')
" 2>&1 | grep real | awk '{print $2}')
  
  echo "  Allocation time: ${time_alloc}s"
  
  # Ver uso de swap después del test
  swap_used=$(free | grep Swap | awk '{print $3}')
  echo "  Swap used after test: ${swap_used}KB"
  
  echo "---"
  sleep 2
done

# Restaurar configuración original
sudo sysctl -p /etc/sysctl.d/99-l4d2-swap-opt.conf
```

### Test de Latencia con Carga de Memoria

```bash
#!/bin/bash
# Test de latencia bajo carga de memoria

echo "=== Memory Pressure Latency Test ==="

# Función para medir latencia de comando simple
measure_latency() {
  local iterations=100
  local total_time=0
  
  for ((i=1; i<=iterations; i++)); do
    start_time=$(date +%s%N)
    ls /dev/null > /dev/null 2>&1
    end_time=$(date +%s%N)
    
    latency=$(((end_time - start_time) / 1000000))  # Convert to milliseconds
    total_time=$((total_time + latency))
  done
  
  avg_latency=$((total_time / iterations))
  echo "$avg_latency"
}

# Medida baseline sin carga
echo "Baseline latency (no memory pressure):"
baseline_latency=$(measure_latency)
echo "  Average: ${baseline_latency}ms"

# Crear carga de memoria
echo "Creating memory pressure..."
python3 -c "
import os
import time
# Allocate 80% of available memory
mem_info = {}
with open('/proc/meminfo') as f:
    for line in f:
        key, value = line.split()[:2]
        mem_info[key[:-1]] = int(value)

target_mb = (mem_info['MemAvailable'] * 8 // 10) // 1024
print(f'Allocating {target_mb}MB...')
data = b'x' * (target_mb * 1024 * 1024)
time.sleep(30)
print('Memory pressure complete')
" &

MEMORY_PRESSURE_PID=$!
sleep 5  # Let memory pressure build up

# Medir latencia bajo carga
echo "Latency under memory pressure:"
pressure_latency=$(measure_latency)
echo "  Average: ${pressure_latency}ms"

# Calcular incremento
latency_increase=$(echo "scale=1; (($pressure_latency - $baseline_latency) * 100) / $baseline_latency" | bc)
echo "  Latency increase: ${latency_increase}%"

# Limpiar proceso de carga de memoria
kill $MEMORY_PRESSURE_PID 2>/dev/null
wait $MEMORY_PRESSURE_PID 2>/dev/null

echo "Memory pressure test complete"
```

## 📊 Monitoreo Avanzado

### Dashboard de Memoria en Tiempo Real

```bash
#!/bin/bash
# Dashboard de monitoreo de memoria

# Función para limpiar pantalla y mostrar header
show_header() {
  clear
  echo "==============================================="
  echo "       L4D2 Server Memory Monitor"
  echo "==============================================="
  echo "Press Ctrl+C to exit"
  echo ""
}

# Función para mostrar barra de progreso
progress_bar() {
  local current=$1
  local total=$2
  local width=30
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  
  printf "["
  for ((i=0; i<filled; i++)); do printf "="; done
  for ((i=filled; i<width; i++)); do printf " "; done
  printf "] %3d%%\n" "$percentage"
}

while true; do
  show_header
  
  # Obtener datos de memoria
  MEM_DATA=$(cat /proc/meminfo)
  MEM_TOTAL=$(echo "$MEM_DATA" | grep MemTotal | awk '{print $2}')
  MEM_FREE=$(echo "$MEM_DATA" | grep MemAvailable | awk '{print $2}')
  MEM_USED=$((MEM_TOTAL - MEM_FREE))
  
  SWAP_TOTAL=$(echo "$MEM_DATA" | grep SwapTotal | awk '{print $2}')
  SWAP_FREE=$(echo "$MEM_DATA" | grep SwapFree | awk '{print $2}')
  SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
  
  DIRTY=$(echo "$MEM_DATA" | grep "^Dirty:" | awk '{print $2}')
  
  # Mostrar información de memoria
  echo "Memory Usage:"
  printf "  Total: %8s MB\n" "$((MEM_TOTAL / 1024))"
  printf "  Used:  %8s MB " "$((MEM_USED / 1024))"
  progress_bar "$MEM_USED" "$MEM_TOTAL"
  printf "  Free:  %8s MB\n" "$((MEM_FREE / 1024))"
  echo ""
  
  # Mostrar información de swap
  if [[ $SWAP_TOTAL -gt 0 ]]; then
    echo "Swap Usage:"
    printf "  Total: %8s MB\n" "$((SWAP_TOTAL / 1024))"
    printf "  Used:  %8s MB " "$((SWAP_USED / 1024))"
    progress_bar "$SWAP_USED" "$SWAP_TOTAL"
    printf "  Free:  %8s MB\n" "$((SWAP_FREE / 1024))"
  else
    echo "Swap: Not configured"
  fi
  echo ""
  
  # Mostrar configuración actual
  echo "Current Configuration:"
  printf "  Swappiness: %s\n" "$(sysctl -n vm.swappiness)"
  printf "  VFS Cache Pressure: %s\n" "$(sysctl -n vm.vfs_cache_pressure)"
  printf "  Dirty Ratio: %s%%\n" "$(sysctl -n vm.dirty_ratio)"
  printf "  Dirty Memory: %s MB\n" "$((DIRTY / 1024))"
  echo ""
  
  # Top procesos por memoria
  echo "Top Memory Consumers:"
  ps aux --sort=-%mem --no-headers | head -5 | awk '{printf "  %-12s %6s%% %8s MB\n", $11, $4, int($6/1024)}'
  echo ""
  
  # Estadísticas de swap
  if [[ -f /proc/vmstat ]]; then
    SWAP_IN=$(grep pswpin /proc/vmstat | awk '{print $2}')
    SWAP_OUT=$(grep pswpout /proc/vmstat | awk '{print $2}')
    echo "Swap Activity (since boot):"
    printf "  Pages swapped in:  %s\n" "$SWAP_IN"
    printf "  Pages swapped out: %s\n" "$SWAP_OUT"
  fi
  
  sleep 5
done
```

### Alertas de Memoria

```bash
#!/bin/bash
# Sistema de alertas para problemas de memoria

# Configuración de umbrales
RAM_WARNING_THRESHOLD=80    # % de RAM usado
RAM_CRITICAL_THRESHOLD=90   # % de RAM usado
SWAP_WARNING_THRESHOLD=10   # % de swap usado
SWAP_CRITICAL_THRESHOLD=50  # % de swap usado

# Función para enviar alerta
send_alert() {
  local level=$1
  local message=$2
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | logger -t l4d2-memory-monitor
  # Aquí se puede agregar integración con sistemas de alertas (email, slack, etc.)
}

# Función principal de monitoreo
monitor_memory() {
  # Obtener datos de memoria
  MEM_DATA=$(cat /proc/meminfo)
  MEM_TOTAL=$(echo "$MEM_DATA" | grep MemTotal | awk '{print $2}')
  MEM_AVAILABLE=$(echo "$MEM_DATA" | grep MemAvailable | awk '{print $2}')
  MEM_USED=$((MEM_TOTAL - MEM_AVAILABLE))
  MEM_USED_PCT=$((MEM_USED * 100 / MEM_TOTAL))
  
  SWAP_TOTAL=$(echo "$MEM_DATA" | grep SwapTotal | awk '{print $2}')
  SWAP_FREE=$(echo "$MEM_DATA" | grep SwapFree | awk '{print $2}')
  
  # Verificar umbrales de RAM
  if [[ $MEM_USED_PCT -ge $RAM_CRITICAL_THRESHOLD ]]; then
    send_alert "CRITICAL" "RAM usage is ${MEM_USED_PCT}% (threshold: ${RAM_CRITICAL_THRESHOLD}%)"
  elif [[ $MEM_USED_PCT -ge $RAM_WARNING_THRESHOLD ]]; then
    send_alert "WARNING" "RAM usage is ${MEM_USED_PCT}% (threshold: ${RAM_WARNING_THRESHOLD}%)"
  fi
  
  # Verificar umbrales de swap (si existe)
  if [[ $SWAP_TOTAL -gt 0 ]]; then
    SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
    SWAP_USED_PCT=$((SWAP_USED * 100 / SWAP_TOTAL))
    
    if [[ $SWAP_USED_PCT -ge $SWAP_CRITICAL_THRESHOLD ]]; then
      send_alert "CRITICAL" "Swap usage is ${SWAP_USED_PCT}% (threshold: ${SWAP_CRITICAL_THRESHOLD}%)"
    elif [[ $SWAP_USED_PCT -ge $SWAP_WARNING_THRESHOLD ]]; then
      send_alert "WARNING" "Swap usage is ${SWAP_USED_PCT}% (threshold: ${SWAP_WARNING_THRESHOLD}%)"
    fi
  fi
  
  # Verificar eventos OOM recientes
  OOM_EVENTS=$(dmesg | grep -c "killed process" | tail -1)
  if [[ $OOM_EVENTS -gt 0 ]]; then
    LAST_OOM=$(dmesg | grep "killed process" | tail -1)
    send_alert "CRITICAL" "OOM event detected: $LAST_OOM"
  fi
}

# Ejecutar monitoreo
monitor_memory
```

## 🔄 Reversión y Backup

### Script de Backup Completo

```bash
#!/bin/bash
# Backup completo de configuración de memoria

BACKUP_DIR="/var/lib/l4d2-optimizer/backups/swap_opt_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creating swap optimization backup in $BACKUP_DIR"

# Backup de configuración sysctl
sysctl -a | grep -E "vm\." > "$BACKUP_DIR/sysctl_vm_all.txt"
cp /etc/sysctl.d/99-l4d2-swap-opt.conf "$BACKUP_DIR/" 2>/dev/null

# Backup de estado de memoria actual
free -h > "$BACKUP_DIR/memory_usage.txt"
cat /proc/meminfo > "$BACKUP_DIR/meminfo.txt"
swapon --show > "$BACKUP_DIR/swap_devices.txt"
cat /proc/vmstat > "$BACKUP_DIR/vmstat.txt"

# Crear script de restauración
cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "Restoring swap optimization configuration..."

# Eliminar configuración personalizada
sudo rm -f /etc/sysctl.d/99-l4d2-swap-opt.conf

# Restaurar valores por defecto del kernel
sudo sysctl vm.swappiness=60
sudo sysctl vm.vfs_cache_pressure=100
sudo sysctl vm.dirty_ratio=20
sudo sysctl vm.dirty_background_ratio=10

# Recargar configuración del sistema
sudo sysctl --system

echo "Swap optimization configuration restored"
echo "Current configuration:"
sysctl vm.swappiness vm.vfs_cache_pressure vm.dirty_ratio vm.dirty_background_ratio
EOF

chmod +x "$BACKUP_DIR/restore.sh"
echo "Backup completed. To restore, run: $BACKUP_DIR/restore.sh"
```

## 📚 Referencias Técnicas

### Documentación del Kernel Linux

- [VM Subsystem Documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
- [Memory Management](https://www.kernel.org/doc/gorman/html/understand/)
- [Swap Management](https://www.kernel.org/doc/html/latest/admin-guide/mm/concepts.html)

### Herramientas de Diagnóstico

- **free**: Información básica de memoria y swap
- **vmstat**: Estadísticas detalladas de memoria virtual
- **swapon**: Gestión de dispositivos de swap
- **smem**: Análisis avanzado de uso de memoria por proceso

### Mejores Prácticas para Gaming

- **Swappiness 10**: Óptimo para servidores de juegos
- **Monitoreo**: Vigilar uso de memoria y eventos OOM
- **SSD para Swap**: Si se necesita swap, usar SSD
- **Sizing**: Swap = 1-2x RAM para sistemas < 8GB

### Consideraciones de Hardware

- **RAM Insuficiente**: Considera upgrade antes que optimización swap
- **SSD vs HDD**: SSD para swap reduce impacto en latencia
- **NVME**: Mejor opción para swap si disponible
- **ZRAM**: Alternativa de compresión en memoria

---

Este módulo es crucial para mantener el rendimiento consistente del servidor L4D2 bajo diferentes cargas de memoria, minimizando las penalizaciones de latencia asociadas con el uso de almacenamiento secundario.
