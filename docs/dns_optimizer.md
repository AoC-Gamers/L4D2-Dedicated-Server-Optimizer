# Documentación del Módulo DNS Optimizer

## 📖 Descripción General

El módulo **DNS Optimizer** (`dns_optimizer.sh`) configura servidores DNS de alta velocidad y confiabilidad para optimizar la resolución de nombres de dominio del servidor. Incluye múltiples proveedores DNS reconocidos y soporte para configuración personalizada.

## 🎯 Objetivo

Optimizar el rendimiento DNS para:
- Reducir latencia en resolución de nombres de dominio
- Mejorar confiabilidad de conectividad del servidor
- Acelerar conexiones a servicios externos (Steam, updates, etc.)
- Configurar DNS con privacidad y seguridad mejoradas

## ⚙️ Funcionamiento Técnico

### Proveedores DNS Disponibles

| Proveedor | DNS Primario | DNS Secundario | Características |
|-----------|--------------|----------------|-----------------|
| **Cloudflare** | 1.1.1.1 | 1.0.0.1 | Velocidad, privacidad, global |
| **Google** | 8.8.8.8 | 8.8.4.4 | Confiabilidad, velocidad, estabilidad |
| **OpenDNS** | 208.67.222.222 | 208.67.220.220 | Filtrado opcional, seguridad |
| **Quad9** | 9.9.9.9 | 149.112.112.112 | Seguridad, bloqueo malware |
| **Custom** | Personalizado | Personalizado | DNS propio o del ISP |

### Sistemas de Configuración DNS

El módulo maneja múltiples sistemas de DNS en Linux:

#### 1. Configuración /etc/resolv.conf (Tradicional)
```bash
# Configuración directa
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
```

#### 2. Integración systemd-resolved
```bash
# Configuración via systemd-resolved
mkdir -p /etc/systemd/resolved.conf.d/
echo "[Resolve]" > /etc/systemd/resolved.conf.d/dns_servers.conf
echo "DNS=1.1.1.1 1.0.0.1" >> /etc/systemd/resolved.conf.d/dns_servers.conf
systemctl restart systemd-resolved
```

## 🔧 Variables de Configuración

| Variable | Descripción | Valores | Por Defecto |
|----------|-------------|---------|-------------|
| `NETWORK_DNS_PROVIDER` | Proveedor DNS | `cloudflare`, `google`, `opendns`, `quad9`, `custom` | `cloudflare` |
| `NETWORK_DNS_CUSTOM_PRIMARY` | DNS primario personalizado | IP válida | `8.8.8.8` |
| `NETWORK_DNS_CUSTOM_SECONDARY` | DNS secundario personalizado | IP válida | `8.8.4.4` |

### Ejemplo de Configuración (.env)

```bash
# DNS configuration for dns_optimizer.sh module
NETWORK_DNS_PROVIDER="cloudflare"  # Options: google, cloudflare, opendns, quad9, custom
NETWORK_DNS_CUSTOM_PRIMARY="8.8.8.8"     # Used only when NETWORK_DNS_PROVIDER=custom
NETWORK_DNS_CUSTOM_SECONDARY="8.8.4.4"   # Used only when NETWORK_DNS_PROVIDER=custom
```

## 📊 Impacto en el Rendimiento

### Beneficios para Servidores L4D2

- **Conexiones más Rápidas**: Resolución DNS más rápida para conexiones externas
- **Menor Timeout**: Reduce fallos de conexión por DNS lento
- **Actualizaciones**: Mejora velocidad de updates de Steam/servidor
- **Servicios Externos**: Mejor conectividad a APIs y servicios web

### Comparación de Rendimiento DNS

| Proveedor | Latencia Promedio | Uptime | Características Especiales |
|-----------|-------------------|--------|---------------------------|
| **Cloudflare** | ~14ms | 99.99% | Privacidad, no logs |
| **Google** | ~16ms | 99.99% | Muy estable, global |
| **OpenDNS** | ~18ms | 99.9% | Filtrado de contenido |
| **Quad9** | ~20ms | 99.9% | Bloqueo de malware |

## 🛠️ Proceso de Instalación

### Paso 1: Detección del Sistema DNS

```bash
# Detecta si systemd-resolved está activo
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  # Sistema con systemd-resolved
  DNS_SYSTEM="systemd-resolved"
else
  # Sistema tradicional con /etc/resolv.conf
  DNS_SYSTEM="resolv.conf"
fi
```

### Paso 2: Backup de Configuración Actual

```bash
# Backup de configuración existente
cp /etc/resolv.conf /etc/resolv.conf.backup
systemctl status systemd-resolved > systemd-resolved.backup.txt
resolvectl status > resolvectl.backup.txt 2>/dev/null
```

### Paso 3: Aplicación de DNS según Provider

```bash
# Ejemplo para Cloudflare
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

### Paso 4: Configuración según Sistema

```bash
if [[ "$DNS_SYSTEM" == "systemd-resolved" ]]; then
  # Configurar systemd-resolved
  mkdir -p /etc/systemd/resolved.conf.d/
  cat > /etc/systemd/resolved.conf.d/dns_servers.conf << EOF
[Resolve]
DNS=$PRIMARY_DNS $SECONDARY_DNS
FallbackDNS=
DNSSEC=no
DNSOverTLS=no
EOF
  systemctl restart systemd-resolved
else
  # Configurar /etc/resolv.conf tradicional
  cat > /etc/resolv.conf << EOF
nameserver $PRIMARY_DNS
nameserver $SECONDARY_DNS
EOF
fi
```

## 📋 Archivos Modificados

### Archivos del Sistema

| Archivo | Propósito | Sistema |
|---------|-----------|---------|
| `/etc/resolv.conf` | Configuración DNS tradicional | Todos |
| `/etc/systemd/resolved.conf.d/dns_servers.conf` | Configuración systemd-resolved | Systemd |
| `/run/systemd/resolve/resolv.conf` | DNS dinámico | Systemd |

### Ejemplos de Configuración

**resolv.conf tradicional**:
```bash
nameserver 1.1.1.1
nameserver 1.0.0.1
```

**systemd-resolved**:
```ini
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=
DNSSEC=no
DNSOverTLS=no
```

## 🔍 Verificación de Funcionamiento

### Comandos de Verificación

```bash
# Ver configuración DNS actual
cat /etc/resolv.conf

# Ver status de systemd-resolved (si está activo)
systemctl status systemd-resolved
resolvectl status

# Test de resolución DNS
nslookup google.com
dig google.com

# Test de velocidad DNS
dig @1.1.1.1 google.com | grep "Query time"
dig @8.8.8.8 google.com | grep "Query time"

# Ver qué DNS está usando el sistema
resolvectl query google.com
```

### Test de Rendimiento DNS

```bash
#!/bin/bash
# Script de benchmark DNS
echo "=== DNS Performance Test ==="

DOMAINS=("google.com" "steam.com" "github.com" "cloudflare.com")
DNS_SERVERS=("1.1.1.1" "8.8.8.8" "208.67.222.222" "9.9.9.9")

for dns in "${DNS_SERVERS[@]}"; do
  echo "Testing DNS: $dns"
  total=0
  for domain in "${DOMAINS[@]}"; do
    time=$(dig @$dns $domain | grep "Query time" | awk '{print $4}')
    echo "  $domain: ${time}ms"
    total=$((total + time))
  done
  avg=$((total / ${#DOMAINS[@]}))
  echo "  Average: ${avg}ms"
  echo "---"
done
```

## ⚠️ Consideraciones Importantes

### Compatibilidad con Network Manager

- **NetworkManager**: Puede sobreescribir /etc/resolv.conf
- **systemd-resolved**: Gestión automática de DNS
- **dhclient**: Puede recibir DNS del DHCP

### Persistencia de Configuración

```bash
# Para evitar que NetworkManager sobreescriba:
echo "dns=none" >> /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager

# Para sistemas con dhclient:
echo "prepend domain-name-servers 1.1.1.1, 1.0.0.1;" >> /etc/dhcp/dhclient.conf
```

## 🐛 Solución de Problemas

### Problema: DNS no cambia

**Diagnóstico**:
```bash
# Ver qué está gestionando DNS
systemctl status systemd-resolved
systemctl status NetworkManager

# Ver contenido real de resolv.conf
ls -la /etc/resolv.conf
readlink /etc/resolv.conf
```

**Solución**:
```bash
# Si es un symlink, elimínalo y crea archivo real
sudo rm /etc/resolv.conf
sudo tee /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Proteger contra sobreescritura
sudo chattr +i /etc/resolv.conf
```

### Problema: DNS lento después del cambio

**Diagnóstico**:
```bash
# Test de latencia a diferentes DNS
ping -c 4 1.1.1.1
ping -c 4 8.8.8.8
ping -c 4 9.9.9.9

# Ver si hay timeouts
dig google.com +time=5
```

**Solución**:
```bash
# Cambiar a DNS con mejor latencia desde tu ubicación
# Test desde tu servidor:
for dns in 1.1.1.1 8.8.8.8 208.67.222.222 9.9.9.9; do
  echo "Testing $dns:"
  ping -c 3 $dns | grep avg
done
```

## 📈 Monitoreo de DNS

### Métricas de Rendimiento

```bash
# Monitoreo continuo de resolución DNS
#!/bin/bash
while true; do
  echo "$(date): $(dig +short google.com @1.1.1.1 | head -1)"
  sleep 60
done

# Test de latencia DNS periódico
#!/bin/bash
echo "DNS Latency Monitor"
while true; do
  latency=$(dig @1.1.1.1 google.com | grep "Query time" | awk '{print $4}')
  echo "$(date '+%Y-%m-%d %H:%M:%S'): ${latency}ms"
  sleep 300  # cada 5 minutos
done
```

### Alertas DNS

```bash
# Script de alerta por DNS lento
#!/bin/bash
THRESHOLD=100  # ms
latency=$(dig @1.1.1.1 google.com | grep "Query time" | awk '{print $4}')

if [[ $latency -gt $THRESHOLD ]]; then
  echo "WARNING: DNS latency is ${latency}ms (threshold: ${THRESHOLD}ms)" | logger -t dns-monitor
  # Enviar alerta adicional si es necesario
fi
```

## 🔄 Reversión de Cambios

### Restaurar DNS Original

```bash
# Restaurar desde backup
sudo cp /etc/resolv.conf.backup /etc/resolv.conf

# O restaurar configuración automática
sudo rm /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Reiniciar servicios DNS
sudo systemctl restart systemd-resolved
sudo systemctl restart NetworkManager
```

### Restaurar DNS del ISP

```bash
# Obtener DNS del DHCP automáticamente
sudo dhclient -r  # release
sudo dhclient     # renew

# Verificar DNS recibido
cat /etc/resolv.conf
```

## 🧪 Testing y Validación

### Test de Funcionamiento Completo

```bash
#!/bin/bash
echo "=== Complete DNS Test ==="

# 1. Configuración actual
echo "Current DNS config:"
cat /etc/resolv.conf

# 2. Resolución básica
echo -e "\nBasic resolution test:"
nslookup google.com

# 3. Test de velocidad
echo -e "\nSpeed test:"
time nslookup google.com >/dev/null

# 4. Test de conectividad
echo -e "\nConnectivity test:"
curl -s -o /dev/null -w "DNS lookup: %{time_namelookup}s\n" http://google.com

# 5. Test múltiples dominios
echo -e "\nMultiple domains test:"
for domain in google.com github.com steam.com; do
  echo -n "$domain: "
  dig +short $domain | head -1
done
```

## 📚 Referencias Técnicas

### Documentación DNS

- [RFC 1035 - Domain Names](https://tools.ietf.org/html/rfc1035)
- [systemd-resolved](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html)
- [resolv.conf Manual](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)

### Proveedores DNS Recomendados

- **Cloudflare (1.1.1.1)**: Privacidad y velocidad
- **Google (8.8.8.8)**: Confiabilidad global
- **Quad9 (9.9.9.9)**: Seguridad y filtrado
- **OpenDNS**: Control parental y filtrado

### Herramientas de Diagnóstico

- `dig`: Herramienta completa de consulta DNS
- `nslookup`: Herramienta básica de resolución
- `resolvectl`: Control de systemd-resolved
- `host`: Herramienta simple de lookup

---

Este módulo es esencial para optimizar la conectividad externa del servidor y reducir latencias en resolución de nombres, especialmente importante para servidores que necesitan conectarse frecuentemente a servicios externos como Steam.
