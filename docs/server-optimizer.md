# Sistema Principal del Optimizador L4D2

## 📖 Introducción

El **server-optimizer.sh** es el núcleo del sistema L4D2 Dedicated Server Optimizer. Este documento explica de manera simple cómo funciona el sistema, cómo interactúan sus componentes y cómo las variables de entorno configuran el comportamiento de los módulos.

## 🏗️ Arquitectura del Sistema

### Flujo de Operación Simplificado

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Inicio del    │───▶│   Carga de      │───▶│   Descubrimiento│
│     Sistema     │    │ Configuración   │    │   de Módulos    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Menú          │◀───│   Verificación  │◀───│   Validación    │
│   Interactivo   │    │   de Permisos   │    │   del Sistema   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Ejecución de Módulos                        │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐      │
│  │ Verificación  │─▶│   Creación    │─▶│   Ejecución   │      │
│  │Dependencias   │  │   Respaldos   │  │   del Módulo  │      │
│  └───────────────┘  └───────────────┘  └───────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Componentes del Sistema

### 1. Gestión de Configuración

El sistema carga configuración en este orden de prioridades:

```bash
# 1. Valores por defecto en el script
OPTIMIZER_DEBUG=1
OPTIMIZER_TIMEOUT_DURATION=180

# 2. Variables desde archivo .env (si existe)
# Estas sobreescriben los valores por defecto
```

#### Variables de Sistema Principales

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `OPTIMIZER_DEBUG` | Habilita modo debug con información detallada | `1` |
| `OPTIMIZER_TIMEOUT_DURATION` | Tiempo límite para cada módulo (segundos) | `180` |
| `OPTIMIZER_CONFIG_DIR` | Directorio de configuración del sistema | `/etc/l4d2-optimizer` |
| `OPTIMIZER_DATA_DIR` | Directorio de datos y respaldos | `/var/lib/l4d2-optimizer` |
| `OPTIMIZER_LOG_DIR` | Directorio de logs | `/var/log/l4d2-optimizer` |

### 2. Sistema de Descubrimiento de Módulos

El sistema escanea automáticamente la carpeta `modules/` y:

1. **Busca archivos `.sh`** ejecutables
2. **Carga cada módulo** mediante `source`
3. **Llama a `register_module()`** para obtener metadatos
4. **Valida la información** requerida
5. **Almacena metadatos** en arrays asociativos

```bash
# Ejemplo de metadatos almacenados por módulo:
MODULE_METADATA["dns_optimizer.sh:name"]="DNS Optimizer"
MODULE_METADATA["dns_optimizer.sh:description"]="Configure DNS servers..."
MODULE_METADATA["dns_optimizer.sh:category"]="network"
MODULE_METADATA["dns_optimizer.sh:dependencies"]=""
MODULE_METADATA["dns_optimizer.sh:packages"]=""
```

### 3. Sistema de Dependencias

Cada módulo puede declarar dos tipos de dependencias:

#### Dependencias de Módulos
```bash
# En register_module() del módulo
MODULE_DEPENDENCIES=("network_base" "swap_optimization")
```

#### Dependencias de Paquetes del Sistema
```bash
# En register_module() del módulo  
MODULE_REQUIRED_PACKAGES=("curl" "wget" "systemd")
```

**Verificación Automática**: Antes de ejecutar un módulo, el sistema:
- Verifica que los módulos dependientes estén instalados
- Comprueba que los paquetes requeridos estén presentes
- Muestra errores descriptivos si faltan dependencias

### 4. Sistema de Respaldos

Los módulos pueden configurar respaldos automáticos:

```bash
# Configuración en register_module()
MODULE_REQUIRES_BACKUP=true
MODULE_BACKUP_FILES=("/etc/resolv.conf" "/etc/systemd/resolved.conf")
MODULE_BACKUP_COMMANDS=("systemctl status systemd-resolved")
```

**Funcionamiento**:
1. **Antes de ejecutar** un módulo con respaldos habilitados
2. **Crea directorio** con timestamp: `/var/lib/l4d2-optimizer/backups/modulo/YYYY-MM-DD_HH-MM-SS/`
3. **Copia archivos** especificados en `MODULE_BACKUP_FILES`
4. **Ejecuta comandos** de `MODULE_BACKUP_COMMANDS` y guarda salida

### 5. Sistema de Estados

El sistema mantiene un registro persistente del estado de cada módulo:

```bash
# Archivo: /var/lib/l4d2-optimizer/module_status
dns_optimizer_STATUS="INSTALLED"
dns_optimizer_TIMESTAMP="2025-01-15 14:30:22"
swap_optimization_STATUS="FAILED"
swap_optimization_TIMESTAMP="2025-01-15 14:25:10"
```

**Estados Posibles**:
- `NOT_INSTALLED`: Módulo no ejecutado
- `INSTALLED`: Módulo ejecutado exitosamente
- `FAILED`: Módulo falló durante ejecución
- `DEPENDENCIES_MISSING`: Faltan dependencias requeridas

## 🌐 Variables de Entorno de Módulos

### Cómo Funcionan las Variables de Entorno

Los módulos pueden leer variables de entorno para personalizar su comportamiento:

```bash
# 1. El módulo declara qué variables usa
MODULE_ENV_VARIABLES=("NETWORK_DNS_PROVIDER" "NETWORK_DNS_CUSTOM_PRIMARY")

# 2. El sistema muestra estas variables en la información del módulo

# 3. El módulo lee las variables durante ejecución
DNS_PROVIDER="${NETWORK_DNS_PROVIDER:-cloudflare}"  # Valor por defecto si no está definida
```

### Ejemplos de Variables por Categoría

#### 🌐 Variables de Red

| Variable | Descripción | Valores Ejemplo | Usado por |
|----------|-------------|-----------------|-----------|
| `NETWORK_DNS_PROVIDER` | Proveedor de DNS | `cloudflare`, `google`, `opendns`, `quad9`, `custom` | `dns_optimizer.sh` |
| `NETWORK_DNS_CUSTOM_PRIMARY` | DNS primario personalizado | `8.8.8.8` | `dns_optimizer.sh` |
| `NETWORK_TCP_CONGESTION` | Algoritmo control congestión TCP | `bbr`, `cubic`, `reno` | `tcp_udp_params.sh` |
| `NETWORK_MTU_SIZE` | Tamaño MTU de red | `1500`, `9000` | `network_advanced.sh` |
| `NETWORK_RMEM_MAX` | Buffer máximo recepción | `262144` | `network_base.sh` |

#### 🧠 Variables de Memoria

| Variable | Descripción | Valores Ejemplo | Usado por |
|----------|-------------|-----------------|-----------|
| `MEMORY_SWAPPINESS` | Tendencia a usar swap | `10`, `60` | `swap_opt.sh` |
| `MEMORY_THP_MODE` | Modo Transparent Huge Pages | `never`, `always`, `madvise` | `thp_disable.sh` |
| `MEMORY_OVERCOMMIT_MEMORY` | Política overcommit memoria | `0`, `1`, `2` | `swap_opt.sh` |

#### 💾 Variables de Disco

| Variable | Descripción | Valores Ejemplo | Usado por |
|----------|-------------|-----------------|-----------|
| `DISK_SCHEDULER` | Scheduler I/O | `mq-deadline`, `kyber`, `bfq`, `none` | `disk_opt.sh` |
| `DISK_TARGET_DEVICE` | Dispositivo objetivo | `auto`, `/dev/sda`, `/dev/nvme0n1` | `disk_opt.sh` |

### Ejemplo Práctico: DNS Optimizer

Veamos cómo el módulo `dns_optimizer.sh` usa variables de entorno:

```bash
# 1. Configuración en .env
NETWORK_DNS_PROVIDER="cloudflare"
NETWORK_DNS_CUSTOM_PRIMARY="1.1.1.1" 
NETWORK_DNS_CUSTOM_SECONDARY="1.0.0.1"

# 2. El módulo lee las variables
DNS_PROVIDER="${NETWORK_DNS_PROVIDER:-google}"  # Por defecto: google

# 3. Comportamiento basado en la configuración
case "$DNS_PROVIDER" in
  "cloudflare")
    PRIMARY_DNS="1.1.1.1"
    SECONDARY_DNS="1.0.0.1"
    ;;
  "google")
    PRIMARY_DNS="8.8.8.8"
    SECONDARY_DNS="8.8.4.4"
    ;;
  "custom")
    PRIMARY_DNS="${NETWORK_DNS_CUSTOM_PRIMARY:-8.8.8.8}"
    SECONDARY_DNS="${NETWORK_DNS_CUSTOM_SECONDARY:-8.8.4.4}"
    ;;
esac
```

## 🚀 Flujo de Ejecución de un Módulo

### Paso a Paso

1. **Usuario selecciona módulo** del menú interactivo

2. **Verificación de dependencias**:
   ```bash
   check_module_dependencies "dns_optimizer.sh"
   # Verifica MODULE_DEPENDENCIES y MODULE_REQUIRED_PACKAGES
   ```

3. **Creación de respaldos** (si está habilitado):
   ```bash
   # Si MODULE_REQUIRES_BACKUP=true
   # Crea /var/lib/l4d2-optimizer/backups/dns_optimizer/2025-01-15_14-30-22/
   # Copia archivos de MODULE_BACKUP_FILES
   # Ejecuta comandos de MODULE_BACKUP_COMMANDS
   ```

4. **Ejecución con timeout**:
   ```bash
   timeout "${MODULE_TIMEOUT:-180}" bash "$module_path"
   ```

5. **Registro de resultado**:
   ```bash
   # Actualiza /var/lib/l4d2-optimizer/module_status
   save_module_status "$module_name" "INSTALLED" "$(date)"
   ```

## 🐛 Sistema de Debug y Logging

### Niveles de Logging

#### Log Principal (`log_message`)
```bash
log_message "MODULE_NAME" "TYPE" "MESSAGE"
# Tipos: INFO, SUCCESS, WARNING, ERROR
```

#### Log de Debug (`debug_log`)
```bash
debug_log "MODULE" "MESSAGE" "FUNCTION" [show_terminal]
# Solo activo cuando OPTIMIZER_DEBUG=1
```

### Archivos de Log

```bash
/var/log/l4d2-optimizer/
├── optimizer.log     # Log principal con todas las operaciones
└── debug.log        # Log detallado (solo en modo debug)
```

### Información Debug Disponible

Cuando `OPTIMIZER_DEBUG=1`:
- **Carga de módulos**: Qué archivos se procesan
- **Metadatos**: Información extraída de cada módulo  
- **Dependencias**: Verificación detallada
- **Ejecución**: Comandos ejecutados y resultados
- **Variables**: Valores de configuración utilizados

## ⚙️ Personalización Avanzada

### Archivo .env Completo

```bash
# Sistema
OPTIMIZER_DEBUG=1
OPTIMIZER_TIMEOUT_DURATION=300

# Red - DNS
NETWORK_DNS_PROVIDER="cloudflare"
NETWORK_DNS_CUSTOM_PRIMARY="1.1.1.1"
NETWORK_DNS_CUSTOM_SECONDARY="1.0.0.1"

# Red - TCP/UDP  
NETWORK_TCP_CONGESTION="bbr"
NETWORK_TCP_MTU_PROBING="1"
NETWORK_UDP_MEM="65536 131072 262144"

# Red - Base
NETWORK_RMEM_MAX="262144"
NETWORK_WMEM_MAX="262144"  
NETWORK_NETDEV_BACKLOG="5000"

# Red - Avanzado
NETWORK_MTU_SIZE="1500"
NETWORK_QDISC_TYPE="fq_codel"
NETWORK_DISABLE_OFFLOADS="true"

# Memoria
MEMORY_SWAPPINESS="10"
MEMORY_THP_MODE="never"
MEMORY_OVERCOMMIT_MEMORY="1"

# Disco
DISK_SCHEDULER="mq-deadline"
DISK_TARGET_DEVICE="auto"
```

### Modificación de Timeouts por Módulo

Los módulos pueden especificar su propio timeout:

```bash
# En register_module() del módulo
MODULE_TIMEOUT=60  # 60 segundos en lugar de 180 por defecto
```

## 🔍 Solución de Problemas Comunes

### Problema: Módulo no aparece en el menú

**Causas posibles**:
1. Archivo no tiene permisos de ejecución: `chmod +x modules/modulo.sh`
2. Función `register_module()` falta o tiene errores
3. Variables requeridas (`MODULE_NAME`, `MODULE_DESCRIPTION`) no definidas

### Problema: Dependencias faltantes

**Solución**:
1. Revisar salida del sistema al seleccionar el módulo
2. Instalar paquetes requeridos: `apt install paquete1 paquete2`
3. Ejecutar módulos dependientes primero

### Problema: Timeout en ejecución

**Soluciones**:
1. Aumentar `OPTIMIZER_TIMEOUT_DURATION` en `.env`
2. Especificar `MODULE_TIMEOUT` mayor en el módulo
3. Revisar logs de debug para identificar qué proceso se cuelga

### Problema: Cambios no persistentes tras reinicio

**Verificar**:
1. Módulo escribe configuración a archivos permanentes (`/etc/sysctl.conf`)
2. Servicios systemd creados correctamente
3. Scripts de inicio actualizados (como GRUB)

## 📊 Monitoreo del Sistema

### Comandos Útiles

```bash
# Ver estado de todos los módulos
cat /var/lib/l4d2-optimizer/module_status

# Ver logs en tiempo real
tail -f /var/log/l4d2-optimizer/optimizer.log

# Ver logs de debug (si está habilitado)
tail -f /var/log/l4d2-optimizer/debug.log

# Verificar respaldos creados
ls -la /var/lib/l4d2-optimizer/backups/

# Ver configuración cargada
grep "OPTIMIZER\|NETWORK\|MEMORY\|DISK" .env
```

### Verificación de Aplicación

```bash
# Verificar parámetros sysctl aplicados
sysctl -a | grep -E "(swappiness|rmem_max|tcp_congestion)"

# Verificar servicios systemd
systemctl status l4d2-thp-disable

# Verificar configuración DNS
cat /etc/resolv.conf

# Verificar scheduler de disco
cat /sys/block/sda/queue/scheduler
```

---

Este documento proporciona una comprensión completa del funcionamiento interno del sistema. Para información sobre desarrollo de módulos, consulta [`template.md`](template.md).
