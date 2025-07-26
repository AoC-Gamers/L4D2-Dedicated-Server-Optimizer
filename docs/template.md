# Guía para Desarrollo de Módulos - Template.sh

## 📖 Introducción

El archivo `template.sh` es una plantilla completa que facilita la creación de nuevos módulos de optimización para el L4D2 Dedicated Server Optimizer. Este documento explica paso a paso cómo usar la plantilla para desarrollar tus propios módulos.

## 🎯 ¿Qué es un Módulo?

Un módulo es un script de Bash independiente que:
- Aplica una optimización específica al sistema
- Puede crear respaldos automáticos antes de hacer cambios
- Se integra automáticamente con el sistema principal
- Tiene metadatos que describen su función y dependencias

## 🏗️ Estructura de un Módulo

### Componentes Obligatorios

Todo módulo debe tener estos elementos:

```bash
#!/bin/bash

# 1. FUNCIÓN DE REGISTRO (OBLIGATORIA)
register_module() {
  # Metadatos del módulo
}

# 2. LÓGICA DE EJECUCIÓN (OBLIGATORIA)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Código de optimización
fi
```

## 📝 Usando la Plantilla

### Paso 1: Copiar la Plantilla

```bash
# Copiar template.sh a tu nuevo módulo
cp modules/template.sh modules/mi_modulo.sh

# Dar permisos de ejecución
chmod +x modules/mi_modulo.sh
```

### Paso 2: Configurar Metadatos

Edita la función `register_module()` con la información de tu módulo:

```bash
register_module() {
  # INFORMACIÓN BÁSICA (OBLIGATORIA)
  MODULE_NAME="Mi Optimización"
  MODULE_DESCRIPTION="Descripción breve de lo que hace el módulo"
  MODULE_VERSION="1.0.0"
  
  # CATEGORÍA (OBLIGATORIA - elegir una)
  # Opciones: "memory", "network", "disk", "cpu", "security", "system", "gaming", "other"
  MODULE_CATEGORY="network"
  
  # CONFIGURACIÓN DE EJECUCIÓN (OPCIONAL)
  MODULE_TIMEOUT=60  # Tiempo límite en segundos (por defecto: 180)
  MODULE_REQUIRES_REBOOT=false  # true si requiere reinicio
  
  # DEPENDENCIAS (OPCIONAL - dejar arrays vacíos si no hay)
  MODULE_DEPENDENCIES=()  # Otros módulos requeridos (por MODULE_NAME)
  MODULE_REQUIRED_PACKAGES=("curl" "wget")  # Paquetes del sistema
  
  # COMPATIBILIDAD DE SISTEMA (OBLIGATORIA)
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  
  # DOCUMENTACIÓN Y METADATOS (OPCIONAL)
  MODULE_AUTHOR="Tu Nombre"
  MODULE_DOCUMENTATION_URL="https://github.com/tu-usuario/tu-proyecto"
  MODULE_GAME_IMPACT="Descripción del impacto en el rendimiento del juego"
  
  # VARIABLES DE ENTORNO (OPCIONAL)
  MODULE_ENV_VARIABLES=("MI_VARIABLE_CONFIG" "OTRA_VARIABLE")
  
  # CONFIGURACIÓN DE RESPALDOS (OPCIONAL)
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/mi-config.conf" "/proc/sys/mi/parametro")
  MODULE_BACKUP_COMMANDS=("systemctl status mi-servicio" "cat /proc/mi/status")
}
```

### Paso 3: Implementar la Lógica de Optimización

Reemplaza la sección de ejecución con tu código:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Nombre del módulo para logging
  MODULE_NAME="mi_optimizacion"
  
  # Inicio del módulo
  log_message "$MODULE_NAME" "INFO" "=== Iniciando Mi Optimización ==="
  
  # PASO 1: Crear respaldo (automático si MODULE_REQUIRES_BACKUP=true)
  if [[ "${MODULE_REQUIRES_BACKUP:-false}" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Creando respaldo..."
    if ! perform_module_backup "$MODULE_NAME"; then
      log_message "$MODULE_NAME" "ERROR" "Falló el respaldo - abortando"
      exit 1
    fi
  fi
  
  # PASO 2: Leer variables de entorno
  MI_PARAMETRO="${MI_VARIABLE_CONFIG:-valor_por_defecto}"
  
  # PASO 3: Verificar estado actual
  current_value=$(cat /proc/sys/mi/parametro)
  desired_value="nuevo_valor"
  
  if [[ "$current_value" == "$desired_value" ]]; then
    log_message "$MODULE_NAME" "INFO" "Ya está configurado correctamente"
  else
    # PASO 4: Aplicar cambios
    log_message "$MODULE_NAME" "INFO" "Aplicando optimización..."
    
    # Cambio temporal
    echo "$desired_value" > /proc/sys/mi/parametro
    
    # Cambio permanente
    sed -i "/^mi.parametro=/d" /etc/sysctl.conf
    echo "mi.parametro=$desired_value" >> /etc/sysctl.conf
    
    log_message "$MODULE_NAME" "SUCCESS" "Optimización aplicada"
  fi
  
  # PASO 5: Verificar resultado
  new_value=$(cat /proc/sys/mi/parametro)
  if [[ "$new_value" == "$desired_value" ]]; then
    log_message "$MODULE_NAME" "SUCCESS" "Verificación exitosa"
    exit 0
  else
    log_message "$MODULE_NAME" "ERROR" "Verificación falló"
    exit 1
  fi
fi
```

## 🔧 Características Avanzadas

### Variables de Entorno

Los módulos pueden leer configuración desde el archivo `.env`:

```bash
# En register_module()
MODULE_ENV_VARIABLES=("NETWORK_MI_PARAMETRO" "NETWORK_OTRO_PARAMETRO")

# En la lógica de ejecución
mi_valor="${NETWORK_MI_PARAMETRO:-valor_por_defecto}"
otro_valor="${NETWORK_OTRO_PARAMETRO:-otro_default}"

log_message "$MODULE_NAME" "INFO" "Usando configuración: $mi_valor"
```

### Sistema de Respaldos Automático

Si habilitas respaldos, el sistema creará automáticamente:

```bash
/var/lib/l4d2-optimizer/backups/
└── mi_modulo/
    └── 20250115_143022/
        ├── backup_metadata.json    # Información del respaldo
        ├── files/                  # Archivos respaldados
        │   ├── etc/
        │   │   └── mi-config.conf
        │   └── proc/
        │       └── sys/
        │           └── mi/
        │               └── parametro
        └── commands/               # Salida de comandos
            ├── command_1.txt       # systemctl status mi-servicio
            └── command_2.txt       # cat /proc/mi/status
```

### Dependencias de Módulos

Si tu módulo depende de otros:

```bash
# En register_module()
MODULE_DEPENDENCIES=("network_base" "swap_optimization")

# El sistema verificará automáticamente que estos módulos estén instalados
# antes de permitir la ejecución de tu módulo
```

### Dependencias de Paquetes

Para paquetes del sistema:

```bash
# En register_module()
MODULE_REQUIRED_PACKAGES=("curl" "jq" "systemd")

# El sistema verificará que estén instalados usando:
# - dpkg (Debian/Ubuntu)
# - rpm (RedHat/CentOS) 
# - pacman (Arch)
# - command -v (genérico)
```

## 📊 Funciones de Utilidad Disponibles

### 1. Logging

```bash
# Función principal de logging
log_message "MODULO" "TIPO" "MENSAJE"

# Tipos disponibles:
log_message "$MODULE_NAME" "INFO" "Información general"
log_message "$MODULE_NAME" "SUCCESS" "Operación exitosa"
log_message "$MODULE_NAME" "WARNING" "Advertencia importante"
log_message "$MODULE_NAME" "ERROR" "Error que no detiene ejecución"

# Logging de debug (solo cuando OPTIMIZER_DEBUG=1)
debug_log "$MODULE_NAME" "Mensaje debug" "funcion_nombre"
```

### 2. Respaldos (disponibles en template.sh)

```bash
# Crear directorio de respaldo
backup_dir=$(create_backup_directory "$MODULE_NAME" "$(date '+%Y%m%d_%H%M%S')")

# Respaldar archivos
backup_files "$MODULE_NAME" "$backup_dir" "${archivos[@]}"

# Respaldar comandos
backup_commands "$MODULE_NAME" "$backup_dir" "${comandos[@]}"

# Proceso completo automático
perform_module_backup "$MODULE_NAME"
```

## 🎮 Buenas Prácticas

### 1. Nombres y Descripciones

```bash
# ✅ Bueno
MODULE_NAME="tcp_optimization"
MODULE_DESCRIPTION="TCP Congestion Control Optimization (BBR, Window Scaling)"

# ❌ Malo  
MODULE_NAME="tcp"
MODULE_DESCRIPTION="tcp stuff"
```

### 2. Verificación de Estado

```bash
# ✅ Siempre verificar estado actual antes de aplicar cambios
current_value=$(sysctl -n net.ipv4.tcp_congestion_control)
if [[ "$current_value" == "bbr" ]]; then
  log_message "$MODULE_NAME" "INFO" "BBR ya está configurado"
else
  log_message "$MODULE_NAME" "INFO" "Configurando BBR..."
  sysctl -w net.ipv4.tcp_congestion_control=bbr
fi
```

### 3. Cambios Persistentes

```bash
# ✅ Hacer cambios temporales Y permanentes
# Cambio inmediato
sysctl -w vm.swappiness=10

# Cambio permanente
sed -i '/^vm.swappiness=/d' /etc/sysctl.conf
echo 'vm.swappiness=10' >> /etc/sysctl.conf
```

### 4. Manejo de Errores

```bash
# ✅ Verificar resultados de comandos importantes
if systemctl enable mi-servicio; then
  log_message "$MODULE_NAME" "SUCCESS" "Servicio habilitado"
else
  log_message "$MODULE_NAME" "ERROR" "No se pudo habilitar el servicio"
  exit 1
fi
```

### 5. Variables de Entorno

```bash
# ✅ Usar valores por defecto sensatos
TCP_CONGESTION="${NETWORK_TCP_CONGESTION:-bbr}"
MTU_SIZE="${NETWORK_MTU_SIZE:-1500}"

# ✅ Validar valores cuando sea crítico
if [[ "$MTU_SIZE" -lt 68 || "$MTU_SIZE" -gt 9000 ]]; then
  log_message "$MODULE_NAME" "ERROR" "MTU inválido: $MTU_SIZE"
  exit 1
fi
```

## 🧪 Testing y Debug

### Modo Debug

Habilita debug en `.env`:

```bash
OPTIMIZER_DEBUG=1
```

Esto mostrará:
- Proceso de carga del módulo
- Verificación de dependencias
- Variables de entorno utilizadas
- Comandos ejecutados

### Testing Manual

```bash
# Ejecutar módulo directamente (modo debug)
sudo bash modules/mi_modulo.sh

# Ver logs en tiempo real
tail -f /var/log/l4d2-optimizer/debug.log

# Verificar metadatos del módulo
sudo ./server-optimizer.sh
# Seleccionar opción M) para ver información detallada
```

### Verificación de Cambios

```bash
# Verificar parámetros sysctl
sysctl -a | grep mi_parametro

# Verificar archivos de configuración
cat /etc/mi-config.conf

# Verificar servicios
systemctl status mi-servicio
```

## 📋 Ejemplos Prácticos

### Ejemplo 1: Módulo de Kernel Parameter

```bash
#!/bin/bash

register_module() {
  MODULE_NAME="kernel_parameter_opt"
  MODULE_DESCRIPTION="Custom Kernel Parameter Optimization"
  MODULE_VERSION="1.0.0"
  MODULE_CATEGORY="system"
  MODULE_TIMEOUT=30
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="Mi Nombre"
  MODULE_GAME_IMPACT="Mejora el manejo de memoria del kernel para mejor rendimiento"
  
  MODULE_ENV_VARIABLES=("KERNEL_PARAM_VALUE")
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/proc/sys/kernel/mi_parametro")
  MODULE_BACKUP_COMMANDS=("sysctl -a | grep kernel.mi_parametro")
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="kernel_parameter_opt"
  
  # Leer configuración
  PARAM_VALUE="${KERNEL_PARAM_VALUE:-1}"
  
  log_message "$MODULE_NAME" "INFO" "Configurando kernel.mi_parametro=$PARAM_VALUE"
  
  # Verificar estado actual
  current=$(sysctl -n kernel.mi_parametro 2>/dev/null || echo "0")
  
  if [[ "$current" == "$PARAM_VALUE" ]]; then
    log_message "$MODULE_NAME" "INFO" "Parámetro ya configurado correctamente"
  else
    # Aplicar cambio
    if sysctl -w kernel.mi_parametro="$PARAM_VALUE"; then
      # Hacer permanente
      sed -i '/^kernel.mi_parametro=/d' /etc/sysctl.conf
      echo "kernel.mi_parametro=$PARAM_VALUE" >> /etc/sysctl.conf
      
      log_message "$MODULE_NAME" "SUCCESS" "Parámetro configurado: $PARAM_VALUE"
    else
      log_message "$MODULE_NAME" "ERROR" "No se pudo configurar el parámetro"
      exit 1
    fi
  fi
  
  exit 0
fi
```

### Ejemplo 2: Módulo de Servicio Systemd

```bash
#!/bin/bash

register_module() {
  MODULE_NAME="custom_service_opt"
  MODULE_DESCRIPTION="Custom Service Configuration"
  MODULE_VERSION="1.0.0"
  MODULE_CATEGORY="system"
  MODULE_TIMEOUT=45
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("systemd")
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="Mi Nombre"
  MODULE_GAME_IMPACT="Optimiza un servicio del sistema para mejor rendimiento del servidor"
  
  MODULE_ENV_VARIABLES=("SERVICE_ENABLE")
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/systemd/system/mi-servicio.service")
  MODULE_BACKUP_COMMANDS=("systemctl status mi-servicio" "systemctl is-enabled mi-servicio")
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="custom_service_opt"
  
  # Leer configuración
  ENABLE_SERVICE="${SERVICE_ENABLE:-true}"
  
  # Crear archivo de servicio
  SERVICE_FILE="/etc/systemd/system/mi-servicio.service"
  
  log_message "$MODULE_NAME" "INFO" "Configurando servicio personalizado..."
  
  # Crear contenido del servicio
  cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Mi Servicio de Optimización
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF

  if [[ "$ENABLE_SERVICE" == "true" ]]; then
    # Recargar systemd y habilitar servicio
    if systemctl daemon-reload && systemctl enable mi-servicio; then
      log_message "$MODULE_NAME" "SUCCESS" "Servicio habilitado correctamente"
    else
      log_message "$MODULE_NAME" "ERROR" "No se pudo habilitar el servicio"
      exit 1
    fi
  else
    log_message "$MODULE_NAME" "INFO" "Servicio creado pero no habilitado (SERVICE_ENABLE=false)"
  fi
  
  exit 0
fi
```

## 🚨 Errores Comunes

### 1. Función register_module() faltante

```bash
# ❌ Error: El módulo no aparece en el menú
# Causa: Falta la función register_module()

# ✅ Solución: Siempre incluir la función
register_module() {
  MODULE_NAME="mi_modulo"
  MODULE_DESCRIPTION="Mi descripción"
  # ... resto de metadatos
}
```

### 2. Permisos de ejecución

```bash
# ❌ Error: Module filename is not executable
# Solución:
chmod +x modules/mi_modulo.sh
```

### 3. Variables requeridas faltantes

```bash
# ❌ Error: Module missing required metadata
# Causa: MODULE_NAME o MODULE_DESCRIPTION vacíos

# ✅ Solución: Asegurar que estén definidos
MODULE_NAME="nombre_no_vacio"
MODULE_DESCRIPTION="descripcion_no_vacia"
```

### 4. Salida incorrecta del script

```bash
# ❌ Script termina sin exit explícito
# El sistema puede interpretar como fallo

# ✅ Siempre terminar con exit explícito
if [[ condicion_exitosa ]]; then
  log_message "$MODULE_NAME" "SUCCESS" "Completado"
  exit 0
else
  log_message "$MODULE_NAME" "ERROR" "Falló"
  exit 1
fi
```

## 📚 Recursos Adicionales

### Archivos de Referencia

- `modules/network_base.sh` - Ejemplo simple de optimización
- `modules/dns_optimizer.sh` - Ejemplo con múltiples opciones
- `modules/swap_opt.sh` - Ejemplo de optimización de memoria
- `modules/tcp_udp_params.sh` - Ejemplo con múltiples parámetros

### Comandos Útiles para Desarrollo

```bash
# Verificar sintaxis del script
bash -n modules/mi_modulo.sh

# Ejecutar solo la función register_module()
source modules/mi_modulo.sh && register_module && echo "Metadatos OK"

# Ver todos los metadatos cargados
sudo ./server-optimizer.sh
# Opción M) para información detallada
```

### Documentación del Sistema

- [`server-optimizer.md`](server-optimizer.md) - Funcionamiento del sistema principal
- `README.md` - Documentación general del proyecto

---

Con esta guía tienes todo lo necesario para crear módulos de optimización robustos y bien integrados con el sistema L4D2 Dedicated Server Optimizer. ¡Recuerda siempre probar tus módulos en un entorno de desarrollo antes de usarlos en producción!
