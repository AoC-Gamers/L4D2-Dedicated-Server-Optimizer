# Documentación del Módulo IPv6 Disable

## 📖 Descripción General

El módulo **IPv6 Disable** (`ipv6_disable.sh`) desactiva completamente el protocolo IPv6 en el sistema para simplificar la configuración de red, eliminar posibles problemas de conectividad dual-stack y optimizar el rendimiento de red para aplicaciones que solo requieren IPv4.

## 🎯 Objetivo

Desactivar IPv6 completamente para:
- Simplificar la configuración de red del servidor
- Eliminar problemas de conectividad dual-stack
- Reducir la complejidad de troubleshooting de red
- Optimizar el rendimiento al usar solo IPv4
- Evitar conflictos en redes que no soportan IPv6 adecuadamente

## ⚙️ Funcionamiento Técnico

### Métodos de Desactivación

El módulo utiliza múltiples métodos para asegurar desactivación completa:

#### 1. Desactivación via sysctl (Inmediata)

```bash
# Desactiva IPv6 globalmente
sysctl -w net.ipv6.conf.all.disable_ipv6=1

# Desactiva IPv6 en interfaz por defecto
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Desactiva IPv6 en loopback
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
```

#### 2. Persistencia en sysctl.conf

```bash
# Hace los cambios permanentes
echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6=1' >> /etc/sysctl.conf
```

#### 3. Desactivación completa via GRUB

```bash
# Añade parámetro del kernel para desactivación total
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
update-grub
```

### Niveles de Desactivación

| Nivel | Método | Efectividad | Persistencia |
|-------|--------|-------------|--------------|
| **Básico** | sysctl runtime | Inmediata | Hasta reinicio |
| **Persistente** | sysctl.conf | Tras reinicio | Permanente |
| **Completo** | GRUB kernel | Total | Permanente |

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `NETWORK_IPV6_DISABLE_METHOD` | Método de desactivación | `sysctl`, `grub`, `both` | `both` |
| `NETWORK_IPV6_GRUB_UPDATE` | Modificar GRUB | `true`, `false` | `true` |

### Métodos de Desactivación

| Método | Descripción | Cuándo Usar |
|--------|-------------|-------------|
| **sysctl** | Solo parámetros sysctl | Desactivación temporal o testing |
| **grub** | Solo parámetro del kernel | Desactivación completa desde boot |
| **both** | Ambos métodos | Desactivación completa y redundante |

### Ejemplo de Configuración (.env)

```bash
# IPv6 configuration for ipv6_disable.sh module
NETWORK_IPV6_DISABLE_METHOD="both"    # Options: sysctl, grub, both
NETWORK_IPV6_GRUB_UPDATE="true"       # Whether to modify GRUB configuration
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Conectividad Simplificada**: Solo IPv4, sin complejidad dual-stack
- **Troubleshooting Más Fácil**: Una sola pila de protocolos para debuggear
- **Compatibilidad**: Evita problemas en redes mal configuradas para IPv6
- **Recursos**: Libera memoria y CPU utilizados por la pila IPv6

### Escenarios de Mejora

- **Redes Legacy**: Entornos donde IPv6 no está correctamente implementado  
- **Hosting Económico**: Proveedores que ofrecen IPv6 problemático
- **Simplicidad Operativa**: Administración más simple de firewall/routing
- **Aplicaciones Legacy**: Software que no maneja bien dual-stack

## 🛠️ Proceso de Instalación

### Paso 1: Verificación del Estado Actual

```bash
# Verifica si IPv6 está actualmente activo
current_ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
current_ipv6_default=$(sysctl -n net.ipv6.conf.default.disable_ipv6)
current_ipv6_lo=$(sysctl -n net.ipv6.conf.lo.disable_ipv6)

# Ver direcciones IPv6 actuales
ip -6 addr show
```

### Paso 2: Desactivación via sysctl

```bash
# Desactiva IPv6 inmediatamente
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
```

### Paso 3: Persistencia en sysctl.conf

```bash
# Elimina entradas previas para evitar duplicados
sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf

# Añade configuraciones nuevas
echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6=1' >> /etc/sysctl.conf
```

### Paso 4: Modificación GRUB (Opcional)

```bash
# Verifica si ya está configurado
if ! grep -q "ipv6.disable=1" /etc/default/grub; then
  # Añade parámetro del kernel
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
  
  # Actualiza GRUB
  update-grub
fi
```

## 📋 Archivos Modificados

### Archivos del Sistema

| Archivo | Propósito | Tipo de Cambio |
|---------|-----------|----------------|
| `/etc/sysctl.conf` | Parámetros del kernel | Añade líneas de desactivación IPv6 |
| `/etc/default/grub` | Configuración GRUB | Añade `ipv6.disable=1` a CMDLINE |
| `/boot/grub/grub.cfg` | GRUB generado | Se regenera con update-grub |

### Ejemplo de Modificaciones

**sysctl.conf - Antes**:
```bash
# /etc/sysctl.conf - System Variables
vm.swappiness=60
```

**sysctl.conf - Después**:
```bash
# /etc/sysctl.conf - System Variables  
vm.swappiness=60
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
```

**GRUB - Antes**:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

**GRUB - Después**:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 quiet splash"
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Verificar parámetros sysctl
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6
sysctl net.ipv6.conf.lo.disable_ipv6

# Verificar que no hay direcciones IPv6
ip -6 addr show

# Verificar configuración GRUB
grep GRUB_CMDLINE /etc/default/grub

# Verificar parámetros del kernel actual
cat /proc/cmdline | grep ipv6

# Test de conectividad IPv6 (debería fallar)
ping6 google.com

# Ver módulos IPv6 del kernel
lsmod | grep ipv6
```

### Indicadores de Éxito

```bash
# sysctl debería mostrar valor 1:
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# ip -6 addr show debería estar vacío o mostrar:
# No hay salida (sin direcciones IPv6)

# GRUB debería contener:
GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 quiet splash"

# ping6 debería fallar:
ping6: connect: Network is unreachable
```

## ⚠️ Consideraciones Importantes

### Compatibilidad de Aplicaciones

- **Aplicaciones modernas**: Pueden requerir IPv6, verificar documentación
- **Contenedores**: Docker/LXC pueden tener problemas sin IPv6
- **Servicios del sistema**: SSH, DNS, etc. deben estar configurados para IPv4

### Reversibilidad

- **Cambios temporales**: Se pueden revertir inmediatamente
- **Cambios GRUB**: Requieren update-grub y reinicio para revertir
- **Testing**: Probar en entorno de desarrollo primero

### Red y Conectividad

- **ISP IPv6**: Si el ISP solo ofrece IPv6, puede causar pérdida de conectividad
- **Servicios remotos**: Algunos servicios pueden ser solo IPv6
- **Monitoreo**: Herramientas de monitoreo pueden usar IPv6

## 🐛 Solución de Problemas

### Problema: IPv6 sigue activo después del módulo

**Diagnóstico**:
```bash
# Verificar direcciones IPv6 existentes
ip -6 addr show

# Ver parámetros sysctl
sysctl -a | grep ipv6 | grep disable

# Ver si hay servicios usando IPv6
netstat -tuln | grep :::
```

**Solución**:
```bash
# Aplicar manualmente
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

# Si persiste, reiniciar servicios de red
sudo systemctl restart networking

# O reiniciar completamente
sudo reboot
```

### Problema: Aplicaciones fallan sin IPv6

**Diagnóstico**:
```bash
# Ver logs de aplicaciones
journalctl -xe | grep -i ipv6

# Verificar configuración de aplicaciones específicas
sudo ss -tuln | grep ":::"
```

**Solución**:
```bash
# Reconfigurar aplicaciones para usar solo IPv4
# Ejemplo para SSH:
echo "AddressFamily inet" >> /etc/ssh/sshd_config

# Para aplicaciones específicas, consultar documentación
```

### Problema: GRUB no se actualiza

**Diagnóstico**:
```bash
# Verificar sintaxis de GRUB
sudo grub-probe --target=device /

# Ver errores de update-grub
sudo update-grub 2>&1 | grep -i error
```

**Solución**:
```bash
# Backup y corrección manual
sudo cp /etc/default/grub /etc/default/grub.backup
sudo nano /etc/default/grub

# Reinstalar GRUB si es necesario
sudo grub-install /dev/sda
sudo update-grub
```

## 📈 Monitoreo Post-Instalación

### Verificación Continua

```bash
# Script de monitoreo de estado IPv6
#!/bin/bash
echo "=== IPv6 Status Check ==="
echo "sysctl disable values:"
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6  
sysctl net.ipv6.conf.lo.disable_ipv6

echo -e "\nIPv6 addresses:"
ip -6 addr show | wc -l

echo -e "\nIPv6 in kernel cmdline:"
cat /proc/cmdline | grep -o ipv6.disable=1 || echo "Not found"
```

### Alertas y Logging

```bash
# Configurar alerta si IPv6 se reactiva accidentalmente
# Crontab entry:
*/15 * * * * [ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -eq 0 ] && echo "WARNING: IPv6 has been re-enabled" | logger -t ipv6-monitor
```

## 🔄 Reversión de Cambios

### Reactivar IPv6 Temporalmente

```bash
# Reactivar IPv6 inmediatamente
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=0

# Reiniciar servicios de red
sudo systemctl restart networking
```

### Reactivar IPv6 Permanentemente

```bash
# Eliminar configuración de sysctl.conf
sudo sed -i '/net.ipv6.conf.*disable_ipv6=1/d' /etc/sysctl.conf

# Eliminar parámetro de GRUB
sudo sed -i 's/ipv6.disable=1 //g' /etc/default/grub
sudo update-grub

# Reiniciar para aplicar cambios completos
sudo reboot
```

## 🧪 Testing y Validación

### Test de Conectividad

```bash
# Antes de aplicar el módulo
ping6 -c 3 google.com  # Debería funcionar
ip -6 addr show        # Debería mostrar direcciones

# Después de aplicar el módulo
ping6 -c 3 google.com  # Debería fallar
ip -6 addr show        # Debería estar vacío

# Test de aplicaciones IPv4
ping -c 3 google.com   # Debería seguir funcionando
curl -4 http://google.com  # Debería funcionar
```

### Validación de Servicios

```bash
# Verificar que servicios críticos siguen funcionando
systemctl status ssh
systemctl status networking

# Test de conectividad de aplicaciones
netstat -tuln | grep :22  # SSH debería estar en IPv4
netstat -tuln | grep :80  # HTTP debería estar en IPv4
```

## 📚 Referencias Técnicas

### Parámetros del Kernel

- `net.ipv6.conf.all.disable_ipv6`: Desactiva IPv6 en todas las interfaces
- `net.ipv6.conf.default.disable_ipv6`: Desactiva IPv6 en interfaces nuevas
- `net.ipv6.conf.lo.disable_ipv6`: Desactiva IPv6 en loopback
- `ipv6.disable=1`: Parámetro del kernel para desactivación completa

### Documentación Relacionada

- [IPv6 Configuration in Linux](https://www.kernel.org/doc/Documentation/networking/ipv6.txt)
- [sysctl Parameters](https://www.kernel.org/doc/Documentation/sysctl/net.txt)
- [GRUB Configuration](https://www.gnu.org/software/grub/manual/grub/grub.html)

### Herramientas Útiles

- `sysctl`: Configuración de parámetros del kernel
- `ip`: Configuración y visualización de red
- `ping6`: Test de conectividad IPv6
- `netstat`/`ss`: Visualización de conexiones de red

---

Este módulo es especialmente útil en entornos donde IPv6 no es necesario o causa problemas de conectividad, permitiendo simplificar la configuración de red y focusing en un rendimiento IPv4 optimizado.
