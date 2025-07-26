# Documentación del Módulo Network Advanced

## 📖 Descripción General

El módulo **Network Advanced** (`network_advanced.sh`) aplica configuraciones avanzadas de red para optimizar el rendimiento del servidor mediante la eliminación de bufferbloat, optimización de MTU y control de offloads de hardware. Está diseñado para entornos de red de alto rendimiento.

## 🎯 Objetivo

Optimizar la red a nivel avanzado para:
- Eliminar bufferbloat que causa latencia variable
- Maximizar throughput con configuraciones MTU optimizadas
- Controlar offloads de hardware para gaming consistente
- Aplicar disciplinas de cola (QDisc) optimizadas

## ⚙️ Funcionamiento Técnico

### 1. Disciplina de Cola: fq_codel

**FQ-CoDel** (Fair Queuing with Controlled Delay):
- **Fair Queuing**: Separa flujos de tráfico para evitar monopolización
- **CoDel**: Algoritmo para detectar y eliminar bufferbloat automáticamente
- **Gaming-optimized**: Reduce latencia variable manteniendo throughput

```bash
# Aplica fq_codel como disciplina de cola raíz
tc qdisc del dev $IFACE root 2>/dev/null  # Elimina qdisc existente
tc qdisc add dev $IFACE root fq_codel     # Aplica fq_codel
```

### 2. Configuración MTU (Maximum Transmission Unit)

**Jumbo Frames (MTU 9000)**:
- **Reducción de overhead**: Menos headers por byte transmitido
- **Mayor eficiencia**: Especialmente beneficioso para transferencias grandes
- **Compatibility check**: Automático, funciona solo si la red lo soporta

```bash
# Detecta MTU actual
current_mtu=$(ip link show $IFACE | grep -o 'mtu [0-9]\+' | awk '{print $2}')

# Configura Jumbo Frames
ip link set dev $IFACE mtu 9000
```

### 3. Control de Offloads de Hardware

**Deshabilitación de offloads problemáticos**:
- **GRO (Generic Receive Offload)**: Puede aumentar latencia
- **GSO (Generic Segmentation Offload)**: Puede causar inconsistencias
- **TSO (TCP Segmentation Offload)**: Puede interferir con timing preciso

```bash
# Desactiva offloads que pueden afectar gaming
ethtool -K $IFACE gro off gso off tso off
```

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `NETWORK_QDISC_TYPE` | Disciplina de cola | `fq_codel`, `fq`, `pfifo_fast` | `fq_codel` |
| `NETWORK_MTU_SIZE` | Tamaño MTU | `1500`, `9000`, `auto` | `9000` |
| `NETWORK_DISABLE_OFFLOADS` | Desactivar offloads | `true`, `false` | `true` |
| `NETWORK_TARGET_INTERFACE` | Interfaz específica | `auto`, `eth0`, `ens18` | `auto` |

### Comparación de QDisc

| QDisc | Uso Recomendado | Ventajas | Desventajas |
|-------|------------------|----------|-------------|
| **fq_codel** | Gaming, uso general | Anti-bufferbloat, fairness | Overhead CPU ligero |
| **fq** | Alta velocidad | Muy eficiente, low-latency | Sin control bufferbloat |
| **pfifo_fast** | Sistemas básicos | Muy simple, bajo overhead | Sin optimizaciones |

### Configuración MTU por Escenario

| MTU | Escenario | Ventajas | Consideraciones |
|-----|-----------|----------|-----------------|
| **1500** | Internet estándar | Compatibilidad total | Overhead mayor |
| **9000** | LAN/Datacenter | Máxima eficiencia | Requiere soporte de red |
| **auto** | Detección automática | Balance automático | Puede no ser óptimo |

### Ejemplo de Configuración (.env)

```bash
# Advanced network configuration for network_advanced.sh module
NETWORK_QDISC_TYPE="fq_codel"         # Options: fq_codel, fq, pfifo_fast
NETWORK_MTU_SIZE="9000"               # MTU size (1500 for standard, 9000 for jumbo frames)
NETWORK_DISABLE_OFFLOADS="true"       # Disable GRO/GSO/TSO offloads
NETWORK_TARGET_INTERFACE="auto"       # Network interface (auto for auto-detection)
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Latencia Consistente**: fq_codel elimina picos de latencia por bufferbloat
- **Mayor Throughput**: Jumbo frames reducen overhead de red
- **Fairness**: Múltiples conexiones de jugadores reciben trato equitativo
- **Timing Preciso**: Control de offloads mejora predictibilidad

### Escenarios de Mejora

- **Servidores con 16+ jugadores**: Mejor manejo de múltiples conexiones
- **Transferencias de contenido**: Descargas de mapas/mods más eficientes
- **Redes LAN**: Máximo beneficio con Jumbo Frames
- **Conexiones mixtas**: fq_codel maneja bien tráfico heterogéneo

## 🛠️ Proceso de Instalación

### Paso 1: Detección de Interfaz

```bash
# Detecta automáticamente la interfaz de red principal
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')

# Verifica que la interfaz sea válida
if [[ -z "$IFACE" ]]; then
  echo "No se pudo detectar interfaz de red"
  exit 1
fi
```

### Paso 2: Configuración QDisc

```bash
# Verifica QDisc actual
current_qdisc=$(tc qdisc show dev $IFACE | grep -o 'fq_codel' || true)

# Aplica fq_codel si no está configurado
if [[ "$current_qdisc" != "fq_codel" ]]; then
  tc qdisc del dev $IFACE root 2>/dev/null
  tc qdisc add dev $IFACE root fq_codel
fi
```

### Paso 3: Configuración MTU

```bash
# Lee MTU actual
current_mtu=$(ip link show $IFACE | grep -o 'mtu [0-9]\+' | awk '{print $2}')

# Aplica Jumbo Frames si es diferente
if [[ "$current_mtu" -ne 9000 ]]; then
  ip link set dev $IFACE mtu 9000
fi
```

### Paso 4: Control de Offloads

```bash
# Desactiva offloads problemáticos para gaming
ethtool -K $IFACE gro off gso off tso off
```

## 📋 Archivos y Configuraciones Modificadas

### Configuraciones Temporales

- **QDisc**: Configuración activa hasta reinicio
- **MTU**: Configuración activa hasta reinicio
- **Offloads**: Configuración activa hasta reinicio

### Persistencia

⚠️ **Importante**: Este módulo aplica cambios temporales. Para persistencia:

```bash
# Ejemplo de persistencia con systemd-networkd
cat > /etc/systemd/network/50-advanced.link << EOF
[Match]
OriginalName=$IFACE

[Link]
MTUBytes=9000
EOF

# Ejemplo con NetworkManager
nmcli connection modify "$CONNECTION_NAME" ethernet.mtu 9000
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Verificar QDisc activo
tc qdisc show dev eth0

# Verificar MTU configurado
ip link show eth0 | grep mtu

# Verificar offloads desactivados
ethtool -k eth0 | grep -E "(generic-receive-offload|generic-segmentation-offload|tcp-segmentation-offload)"

# Ver estadísticas de QDisc
tc -s qdisc show dev eth0

# Test de MTU (ping con paquete grande)
ping -M do -s 8972 google.com  # 8972 + 28 (headers) = 9000
```

### Indicadores de Éxito

```bash
# QDisc debería mostrar:
qdisc fq_codel 1: root refcnt 2 limit 10240p flows 1024 quantum 1514 target 5.0ms interval 100.0ms memory_limit 32Mb ecn

# MTU debería mostrar:
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 ...

# Offloads desactivados:
generic-receive-offload: off
generic-segmentation-offload: off
tcp-segmentation-offload: off
```

## ⚠️ Consideraciones Importantes

### Requisitos de Red

- **Jumbo Frames**: Toda la infraestructura de red debe soportar MTU 9000
- **Switch/Router**: Deben soportar Jumbo Frames
- **Otros dispositivos**: Todos en la misma red deben usar MTU consistente

### Compatibilidad

- **Redes domésticas**: MTU 9000 puede no funcionar
- **Internet público**: Solo usar MTU 1500
- **Datacenters**: Generalmente soportan Jumbo Frames
- **Virtualización**: Verificar soporte del hypervisor

### Paquetes Requeridos

- **iproute2**: Para comandos `tc` e `ip`
- **ethtool**: Para control de offloads de hardware

## 🐛 Solución de Problemas

### Problema: Jumbo Frames no funcionan

**Diagnóstico**:
```bash
# Test de conectividad con MTU grande
ping -M do -s 8972 8.8.8.8

# Si falla, la red no soporta Jumbo Frames
```

**Solución**:
```bash
# Reducir MTU a valor estándar
ip link set dev eth0 mtu 1500

# O configurar en .env
NETWORK_MTU_SIZE="1500"
```

### Problema: QDisc no se aplica

**Diagnóstico**:
```bash
# Verificar que tc está disponible
which tc

# Ver qdisc actual
tc qdisc show dev eth0

# Verificar errores de kernel
dmesg | grep -i qdisc
```

**Solución**:
```bash
# Instalar herramientas de red
sudo apt install iproute2

# Aplicar manualmente
sudo tc qdisc del dev eth0 root
sudo tc qdisc add dev eth0 root fq_codel
```

### Problema: Offloads no se desactivan

**Diagnóstico**:
```bash
# Verificar que ethtool está disponible
which ethtool

# Ver capabilities de la interfaz
ethtool -k eth0
```

**Solución**:
```bash
# Instalar ethtool
sudo apt install ethtool

# Aplicar manualmente
sudo ethtool -K eth0 gro off gso off tso off
```

## 📈 Monitoreo de Rendimiento

### Métricas de Red

```bash
# Estadísticas de QDisc en tiempo real
watch -n 1 'tc -s qdisc show dev eth0'

# Throughput de interfaz
watch -n 1 'cat /sys/class/net/eth0/statistics/{rx_bytes,tx_bytes}'

# Latencia de red (bufferbloat test)
fping -c 100 -p 100 8.8.8.8

# Análisis de tráfico
tcpdump -i eth0 -c 100
```

### Benchmarking

```bash
# Test de throughput con iperf3
# En el servidor:
iperf3 -s

# En el cliente:
iperf3 -c servidor_ip -t 60

# Test de latencia bajo carga
# Terminal 1: generar carga
iperf3 -c servidor_ip -t 300

# Terminal 2: medir latencia
ping -c 100 servidor_ip
```

### Verificación de Bufferbloat

```bash
# Test de bufferbloat básico
# Terminal 1: saturar conexión
curl -o /dev/null http://speedtest.wdc01.softlayer.com/downloads/test500.zip

# Terminal 2: medir latencia
ping -c 20 8.8.8.8

# La latencia NO debería aumentar significativamente
```

## 🔄 Reversión de Cambios

### Revertir QDisc

```bash
# Eliminar fq_codel y usar por defecto
sudo tc qdisc del dev eth0 root

# El sistema aplicará qdisc por defecto (usualmente pfifo_fast)
```

### Revertir MTU

```bash
# Volver a MTU estándar
sudo ip link set dev eth0 mtu 1500
```

### Reactivar Offloads

```bash
# Reactivar offloads de hardware
sudo ethtool -K eth0 gro on gso on tso on
```

## 🧪 Testing Avanzado

### Test de Bufferbloat

```bash
# Instalar herramientas de test
sudo apt install netperf

# Test de bufferbloat completo
netperf -H servidor_remoto -t TCP_STREAM -l 60 &
ping -c 100 servidor_remoto

# Analizar variación de latencia
```

### Validación de Jumbo Frames

```bash
# Test de MTU progresivo
for size in 1472 4000 8000 8972; do
  echo "Testing MTU $((size + 28)):"
  ping -M do -s $size -c 3 8.8.8.8
done
```

### Análisis de Rendimiento QDisc

```bash
# Generar tráfico variado
tc qdisc add dev eth0 root handle 1: fq_codel limit 1000

# Monitorear comportamiento
tc -s -d qdisc show dev eth0

# Ver estadísticas detalladas
tc -s class show dev eth0
```

## 📚 Referencias Técnicas

### Algoritmos y Conceptos

- **fq_codel**: Fair Queuing with Controlled Delay
- **Bufferbloat**: Problema de latencia excesiva por buffers grandes
- **Jumbo Frames**: Frames Ethernet mayores a 1500 bytes
- **Hardware Offloads**: Procesamiento en hardware de red

### Herramientas Relacionadas

- `tc`: Control de tráfico (Traffic Control)
- `ethtool`: Configuración de interfaces Ethernet
- `iperf3`: Testing de rendimiento de red
- `fping`: Ping optimizado para múltiples hosts

### Documentación Adicional

- [Linux Traffic Control HOWTO](https://tldp.org/HOWTO/Traffic-Control-HOWTO/)
- [CoDel Algorithm](https://tools.ietf.org/html/rfc8289)
- [Jumbo Frames Configuration](https://www.kernel.org/doc/Documentation/networking/jumbo-frames.txt)

---

Este módulo es ideal para servidores de gaming en entornos de red controlados (LAN, datacenter) donde se puede garantizar soporte para configuraciones avanzadas como Jumbo Frames.
