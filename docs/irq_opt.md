# Documentación del Módulo IRQ Optimization

## 📖 Descripción General

El módulo **IRQ Optimization** (`irq_opt.sh`) optimiza la distribución de interrupciones de red y CPU para mejorar el rendimiento del servidor. Este módulo configura el balanceado de interrupciones (IRQ) y la distribución de carga de red entre múltiples núcleos de CPU.

## 🎯 Objetivo

Optimizar la gestión de interrupciones del sistema para:
- Distribuir interrupciones de red entre todos los núcleos CPU disponibles
- Habilitar IRQ balancing automático
- Configurar RPS (Receive Packet Steering) para mejor distribución de carga
- Mejorar la utilización de CPU multinúcleo

## ⚙️ Funcionamiento Técnico

### Componentes Optimizados

1. **IRQBalance Service**
   - Instala y habilita el servicio `irqbalance`
   - Balancea automáticamente las interrupciones entre núcleos CPU
   - Mejora la distribución de carga de trabajo

2. **RPS (Receive Packet Steering)**
   - Configura la distribución de paquetes recibidos
   - Utiliza todos los núcleos CPU disponibles
   - Calcula máscara de CPU automáticamente

3. **XPS (Transmit Packet Steering)**
   - Optimiza la transmisión de paquetes
   - Alinea transmisión con núcleos específicos

### Detección Automática

```bash
# Detecta interfaz de red principal automáticamente
IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

# Calcula máscara para todos los núcleos CPU
CPUS=$(nproc)
MASK=$(printf '%x' $(( (1 << CPUS) - 1 )))
```

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `CPU_IRQ_BALANCE_ENABLED` | Habilitar IRQ balancing | `true`, `false` | `true` |
| `CPU_RPS_ENABLED` | Habilitar RPS | `true`, `false` | `true` |

### Ejemplo de Configuración (.env)

```bash
# CPU Module Configuration
CPU_IRQ_BALANCE_ENABLED="true"        # Enable IRQ balancing across CPUs
CPU_RPS_ENABLED="true"                # Enable Receive Packet Steering
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Mejor Utilización CPU**: Distribuye interrupciones entre todos los núcleos
- **Reducción de Latencia**: Evita sobrecarga en un solo núcleo
- **Mayor Throughput**: Mejor manejo de tráfico de red intensivo
- **Estabilidad**: Reduce picos de CPU en núcleos individuales

### Sistemas Objetivo

- **Servidores Multinúcleo**: Especialmente beneficioso en sistemas con 4+ núcleos
- **Alto Tráfico de Red**: Ideal para servidores con muchos jugadores conectados
- **Cargas Mixtas**: Mejora rendimiento cuando hay otros procesos ejecutándose

## 🛠️ Proceso de Instalación

### Paso 1: Detección de Sistema

```bash
# Detecta interfaz de red principal
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')

# Cuenta núcleos CPU disponibles
CPUS=$(nproc)
```

### Paso 2: Instalación de IRQBalance

```bash
# Verifica si irqbalance está instalado
if ! command -v irqbalance &> /dev/null; then
  # Instala irqbalance
  apt update && apt install -y irqbalance
  
  # Habilita e inicia el servicio
  systemctl enable irqbalance
  systemctl start irqbalance
fi
```

### Paso 3: Configuración RPS

```bash
# Calcula máscara para todos los núcleos
MASK=$(printf '%x' $(( (1 << CPUS) - 1 )))

# Configura RPS en la cola rx-0
echo "$MASK" > "/sys/class/net/$IFACE/queues/rx-0/rps_cpus"
```

## 📋 Archivos Modificados

### Servicios del Sistema

- **irqbalance.service**: Servicio de balanceado de interrupciones

### Archivos de Sistema

- `/sys/class/net/*/queues/rx-*/rps_cpus`: Configuración RPS por interfaz
- `/proc/interrupts`: Estado actual de interrupciones (solo lectura)

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Verificar estado de irqbalance
systemctl status irqbalance

# Ver distribución actual de interrupciones
cat /proc/interrupts

# Verificar configuración RPS
cat /sys/class/net/*/queues/rx-*/rps_cpus

# Ver información de CPU
lscpu | grep -E 'CPU|Core|Thread'

# Monitorear interrupciones en tiempo real
watch -n 1 'cat /proc/interrupts'
```

### Indicadores de Éxito

```bash
# IRQBalance activo
● irqbalance.service - irqbalance daemon
   Loaded: loaded (/lib/systemd/system/irqbalance.service; enabled)
   Active: active (running)

# RPS configurado correctamente (ejemplo para 8 núcleos)
# /sys/class/net/eth0/queues/rx-0/rps_cpus debería mostrar: ff
```

## ⚠️ Consideraciones Importantes

### Requisitos del Sistema

- **Paquete irqbalance**: Se instala automáticamente si no está presente
- **Interfaz de red activa**: Debe haber conectividad a internet para detección
- **Núcleos múltiples**: Más efectivo en sistemas multinúcleo

### Limitaciones

- **Dependiente de hardware**: La efectividad depende del hardware de red
- **Configuración temporal**: RPS se resetea al reiniciar (no persistente)
- **Una interfaz**: Solo configura la interfaz de red principal

### Compatibilidad

- ✅ **Debian 11/12**: Completamente compatible
- ✅ **Ubuntu 20.04/22.04/24.04**: Completamente compatible
- ⚠️ **Virtualización**: Efectividad limitada en VMs con pocos núcleos virtuales

## 🐛 Solución de Problemas

### Problema: IRQ no se distribuye

**Diagnóstico**:
```bash
# Ver si irqbalance está corriendo
systemctl status irqbalance

# Ver distribución actual
grep eth0 /proc/interrupts
```

**Solución**:
```bash
# Reiniciar irqbalance
sudo systemctl restart irqbalance

# Verificar logs
journalctl -u irqbalance -f
```

### Problema: RPS no se aplica

**Diagnóstico**:
```bash
# Verificar que el archivo existe
ls -la /sys/class/net/*/queues/rx-*/rps_cpus

# Ver valor actual
cat /sys/class/net/eth0/queues/rx-0/rps_cpus
```

**Solución**:
```bash
# Aplicar manualmente (reemplazar eth0 por tu interfaz)
echo "ff" > /sys/class/net/eth0/queues/rx-0/rps_cpus
```

### Problema: No se detecta interfaz

**Diagnóstico**:
```bash
# Ver rutas disponibles
ip route show

# Ver interfaces activas
ip link show up
```

**Solución**:
```bash
# Especificar interfaz manualmente en el módulo
IFACE="eth0"  # o la interfaz correcta
```

## 📈 Monitoreo de Rendimiento

### Métricas a Observar

```bash
# Distribución de interrupciones por CPU
grep -E "(CPU|eth0)" /proc/interrupts

# Uso de CPU por núcleo
htop  # o top presionando '1'

# Estadísticas de red
cat /proc/net/dev

# Estadísticas de RPS
cat /sys/class/net/eth0/queues/rx-0/rps_cpus
```

### Benchmarking

```bash
# Antes de aplicar el módulo
cat /proc/interrupts > before_interrupts.txt

# Aplicar el módulo
sudo ./server-optimizer.sh  # seleccionar IRQ optimization

# Después de un tiempo de uso
cat /proc/interrupts > after_interrupts.txt

# Comparar distribución
diff before_interrupts.txt after_interrupts.txt
```

## 🔄 Reversión de Cambios

### Desinstalar IRQBalance

```bash
# Parar y deshabilitar servicio
sudo systemctl stop irqbalance
sudo systemctl disable irqbalance

# Desinstalar paquete
sudo apt remove irqbalance
```

### Resetear RPS

```bash
# Resetear RPS a valor por defecto (solo CPU 0)
echo "01" > /sys/class/net/eth0/queues/rx-0/rps_cpus
```

## 📚 Referencias Técnicas

### Documentación del Kernel

- [RPS - Receive Packet Steering](https://www.kernel.org/doc/Documentation/networking/scaling.txt)
- [IRQ Affinity](https://www.kernel.org/doc/Documentation/IRQ-affinity.txt)

### Herramientas Relacionadas

- `irqbalance`: Balanceador automático de interrupciones
- `htop`: Monitor de CPU por núcleo
- `iftop`: Monitor de tráfico de red
- `netstat`: Estadísticas de red

---

Este módulo es especialmente útil en servidores dedicados con múltiples núcleos CPU que manejan alto tráfico de red, como es típico en servidores de juegos con muchos jugadores simultáneos.
