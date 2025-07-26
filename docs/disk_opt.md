# Documentación del Módulo Disk Optimization

## 📖 Descripción General

El módulo **Disk Optimization** (`disk_opt.sh`) optimiza el subsistema de almacenamiento del servidor mediante la configuración del scheduler de I/O más apropiado para aplicaciones de gaming que requieren acceso rápido y consistente al disco.

## 🎯 Objetivo

Optimizar el rendimiento del disco para:
- Reducir latencia en operaciones de I/O críticas
- Mejorar tiempos de carga de mapas y recursos del juego
- Configurar el scheduler de I/O más eficiente para gaming
- Asegurar persistencia de la configuración tras reinicios

## ⚙️ Funcionamiento Técnico

### Scheduler I/O: mq-deadline

El módulo configura el scheduler **mq-deadline** como optimización principal:

- **mq-deadline**: Diseñado para equilibrar throughput y latencia
- **Multiqueue**: Aprovecha múltiples colas para sistemas multinúcleo
- **Deadline scheduling**: Garantiza que ninguna I/O espere demasiado tiempo
- **Gaming-friendly**: Optimizado para cargas de trabajo mixtas read/write

### Detección Automática de Disco

```bash
# Detecta automáticamente el disco principal del sistema
device=$(lsblk -ndo NAME,TYPE | awk '$2 == "disk" {print "/dev/"$1; exit}')

# Construye la ruta del archivo de configuración
elevator_file="/sys/block/$(basename $device)/queue/scheduler"
```

### Persistencia GRUB

El módulo modifica `/etc/default/grub` para mantener configuración tras reinicios:

```bash
# Si ya existe parámetro elevator, lo reemplaza
sed -i 's/elevator=[^ ]*/elevator=mq-deadline/' /etc/default/grub

# Si no existe, lo añade
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="elevator=mq-deadline /' /etc/default/grub

# Actualiza GRUB
update-grub
```

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `DISK_SCHEDULER` | Scheduler I/O a usar | `mq-deadline`, `kyber`, `bfq`, `none` | `mq-deadline` |
| `DISK_TARGET_DEVICE` | Dispositivo específico | `auto`, `/dev/sda`, `/dev/nvme0n1` | `auto` |
| `DISK_UPDATE_GRUB` | Actualizar GRUB | `true`, `false` | `true` |

### Comparación de Schedulers

| Scheduler | Uso Recomendado | Ventajas | Desventajas |
|-----------|------------------|----------|-------------|
| **mq-deadline** | Gaming, uso general | Balance latencia/throughput | - |
| **kyber** | SSDs rápidos | Muy baja latencia | Menor throughput |
| **bfq** | Uso interactivo | Fairness, responsividad | Overhead CPU |
| **none** | NVMe premium | Throughput máximo | Latencia variable |

### Ejemplo de Configuración (.env)

```bash
# Disk Module Configuration
DISK_SCHEDULER="mq-deadline"          # I/O scheduler (mq-deadline, none, kyber, bfq)
DISK_TARGET_DEVICE="auto"             # Target device (auto for auto-detection, or /dev/sdX)
DISK_UPDATE_GRUB="true"               # Whether to update GRUB configuration
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Carga de Mapas**: Reducción del tiempo de carga inicial
- **Streaming de Recursos**: Mejor rendimiento al cargar texturas/sonidos
- **Logs y Saves**: Escritura más eficiente de logs del servidor
- **Base de Datos**: Mejor rendimiento en SQLite/MySQL (si se usa)

### Escenarios de Mejora

- **Cambios de Mapa**: Reduce tiempo de transición entre mapas
- **Picos de I/O**: Mejor manejo durante salvado de estadísticas
- **Cargas Concurrentes**: Mejora cuando múltiples procesos acceden al disco

## 🛠️ Proceso de Instalación

### Paso 1: Detección de Hardware

```bash
# Lista todos los dispositivos de bloque
lsblk -ndo NAME,TYPE

# Identifica disco principal
device=$(lsblk -ndo NAME,TYPE | awk '$2 == "disk" {print "/dev/"$1; exit}')

# Ejemplo de salida:
# /dev/sda (disco tradicional)
# /dev/nvme0n1 (disco NVMe)
```

### Paso 2: Verificación del Estado Actual

```bash
# Lee scheduler actual
current_scheduler=$(cat /sys/block/sda/queue/scheduler)

# Ejemplo de salida:
# none [mq-deadline] kyber
# El scheduler entre [] es el activo
```

### Paso 3: Aplicación del Cambio

```bash
# Cambio inmediato (temporal)
echo mq-deadline > /sys/block/sda/queue/scheduler

# Cambio permanente en GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="elevator=mq-deadline /' /etc/default/grub

# Actualización de GRUB
update-grub
```

## 📋 Archivos Modificados

### Archivos del Sistema

- `/sys/block/*/queue/scheduler`: Configuración temporal del scheduler
- `/etc/default/grub`: Configuración permanente de arranque
- `/boot/grub/grub.cfg`: Archivo generado por update-grub

### Ejemplo de Modificación GRUB

**Antes**:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

**Después**:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="elevator=mq-deadline quiet splash"
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Ver scheduler activo (entre corchetes)
cat /sys/block/sda/queue/scheduler

# Ver todos los schedulers por disco
for disk in /sys/block/*/queue/scheduler; do
  echo "$disk: $(cat $disk)"
done

# Verificar configuración GRUB
grep GRUB_CMDLINE /etc/default/grub

# Ver parámetros del kernel actual
cat /proc/cmdline | grep elevator

# Información detallada de discos
lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT
```

### Indicadores de Éxito

```bash
# Scheduler activo debería mostrar:
none [mq-deadline] kyber bfq

# GRUB debería contener:
GRUB_CMDLINE_LINUX_DEFAULT="elevator=mq-deadline quiet splash"

# Kernel activo debería mostrar:
... elevator=mq-deadline ...
```

## ⚠️ Consideraciones Importantes

### Compatibilidad de Hardware

- **SSDs SATA**: mq-deadline es ideal
- **NVMe PCIe 4.0**: Considerar `none` para máximo rendimiento
- **HDDs tradicionales**: mq-deadline mejora significativamente la latencia
- **RAID arrays**: Verificar compatibilidad con el controlador

### Reinicio Requerido

- **Cambio inmediato**: Activo inmediatamente para la sesión actual
- **Cambio permanente**: Requiere reinicio para que GRUB tome efecto
- **Verificación**: Comprobar tanto configuración temporal como permanente

### Impacto en Otros Workloads

- **Bases de datos**: Generalmente beneficioso para transacciones mixtas
- **Compilación**: Puede mejorar tiempos de build
- **Backups**: Mejor rendimiento en operaciones de escritura secuencial

## 🐛 Solución de Problemas

### Problema: Scheduler no cambia

**Diagnóstico**:
```bash
# Verificar que el archivo existe
ls -la /sys/block/sda/queue/scheduler

# Ver schedulers disponibles
cat /sys/block/sda/queue/scheduler
```

**Solución**:
```bash
# Verificar permisos de escritura
sudo echo mq-deadline > /sys/block/sda/queue/scheduler

# Si falla, verificar soporte del kernel
grep DEADLINE /boot/config-$(uname -r)
```

### Problema: GRUB no se actualiza

**Diagnóstico**:
```bash
# Verificar sintaxis de GRUB
grep GRUB_CMDLINE /etc/default/grub

# Verificar errores de update-grub
sudo update-grub 2>&1 | grep -i error
```

**Solución**:
```bash
# Backup y corrección manual
sudo cp /etc/default/grub /etc/default/grub.backup
sudo nano /etc/default/grub

# Actualizar GRUB manualmente
sudo update-grub
sudo grub-install /dev/sda  # si es necesario
```

### Problema: Disco no detectado

**Diagnóstico**:
```bash
# Ver todos los discos
lsblk

# Ver discos de sistema
cat /proc/partitions

# Verificar montajes
df -h
```

**Solución**:
```bash
# Especificar disco manualmente
DISK_TARGET_DEVICE="/dev/sda"  # en .env
```

## 📈 Monitoreo de Rendimiento

### Herramientas de Benchmarking

```bash
# Test de latencia de I/O
sudo ioping -c 10 /

# Test de throughput secuencial
sudo dd if=/dev/zero of=/tmp/test bs=1G count=1 oflag=dsync

# Test de I/O aleatoria
sudo fio --name=random-rw --ioengine=posix --rw=randrw --bs=4k --numjobs=1 --size=1g --runtime=60 --time_based --end_fsync=1 --filename=/tmp/fio-test

# Monitoreo en tiempo real
sudo iotop -a
```

### Métricas Importantes

```bash
# Estadísticas de I/O por dispositivo
cat /proc/diskstats

# Estadísticas del scheduler
cat /sys/block/sda/queue/iosched/stats

# Información de colas
cat /sys/block/sda/queue/nr_requests
```

## 🔄 Reversión de Cambios

### Revertir Scheduler Temporal

```bash
# Cambiar a scheduler por defecto (usually none or bfq)
echo none > /sys/block/sda/queue/scheduler
```

### Revertir Configuración GRUB

```bash
# Editar GRUB manualmente
sudo nano /etc/default/grub

# Remover elevator=mq-deadline de GRUB_CMDLINE_LINUX_DEFAULT
# Actualizar GRUB
sudo update-grub

# Reiniciar para aplicar
sudo reboot
```

## 🧪 Testing y Validación

### Test Antes/Después

```bash
# Antes del módulo
sudo ioping -c 100 / > before_latency.txt
sudo dd if=/dev/zero of=/tmp/before_test bs=1M count=100 oflag=dsync

# Aplicar módulo
sudo ./server-optimizer.sh  # seleccionar disk optimization

# Después del módulo
sudo ioping -c 100 / > after_latency.txt
sudo dd if=/dev/zero of=/tmp/after_test bs=1M count=100 oflag=dsync

# Comparar resultados
echo "=== ANTES ==="
cat before_latency.txt | tail -1

echo "=== DESPUÉS ==="
cat after_latency.txt | tail -1
```

### Validación en Producción

```bash
# Monitorear latencia promedio durante gameplay
iostat -x 1

# Verificar que no hay cuellos de botella
iotop -a

# Verificar logs del servidor L4D2 para mejorar en tiempos de carga
```

## 📚 Referencias Técnicas

### Documentación del Kernel

- [Linux I/O Schedulers](https://www.kernel.org/doc/Documentation/block/switching-sched.txt)
- [Multi-queue Block Layer](https://www.kernel.org/doc/html/latest/block/blk-mq.html)

### Schedulers Específicos

- **mq-deadline**: Balance entre latencia y throughput
- **kyber**: Scheduler diseñado para SSDs de alta velocidad
- **bfq**: Budget Fair Queueing para máxima fairness
- **none**: Sin scheduling, máximo throughput

### Herramientas de Análisis

- `iotop`: Monitor de I/O por proceso
- `iostat`: Estadísticas de dispositivos de I/O
- `ioping`: Test de latencia de I/O
- `fio`: Framework completo de benchmarking I/O

---

Este módulo es fundamental para optimizar el rendimiento de servidores de juegos que requieren acceso frecuente y rápido al almacenamiento, especialmente durante cambios de mapa y carga de recursos.
