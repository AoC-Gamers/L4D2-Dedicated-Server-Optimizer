# L4D2 Dedicated Server Optimizer

<div align="center">

🎮 **Sistema Modular de Optimización para Servidores Dedicados de Left 4 Dead 2** 🎮

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/AoC-Gamers/L4D2-Dedicated-Server-Optimizer)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Compatibility](https://img.shields.io/badge/OS-Debian%2011%2F12%20%7C%20Ubuntu%2020.04%2F22.04%2F24.04-orange.svg)](README.md)

</div>

## 📋 Descripción del Proyecto

El **L4D2 Dedicated Server Optimizer** es un sistema modular desarrollado por AoC-Gamers que permite aplicar optimizaciones específicas al sistema operativo para mejorar el rendimiento de servidores dedicados de Left 4 Dead 2.

### 🎯 Objetivos Principales

- **Optimización Modular**: Sistema de módulos independientes para diferentes aspectos del sistema
- **Configuración Centralizada**: Variables de entorno para personalizar cada optimización
- **Seguridad**: Sistema de respaldos automáticos antes de aplicar cambios
- **Monitoreo**: Registro detallado de todas las operaciones y estados
- **Compatibilidad**: Soporte específico para sistemas Debian/Ubuntu
- **Facilidad de Uso**: Menú interactivo con información detallada de cada módulo

## 🏗️ Arquitectura del Sistema

```
L4D2-Dedicated-Server-Optimizer/
├── server-optimizer.sh    # Script principal con menú interactivo
├── .env.example          # Plantilla de configuración
├── modules/              # Módulos de optimización
│   ├── disk_opt.sh       # Optimización de disco I/O
│   ├── dns_optimizer.sh  # Configuración DNS optimizada
│   ├── ipv6_disable.sh   # Deshabilitación IPv6
│   ├── irq_opt.sh        # Optimización IRQ
│   ├── network_*.sh      # Módulos de red (base, avanzado, tcp/udp)
│   ├── swap_opt.sh       # Optimización memoria virtual
│   ├── thp_disable.sh    # Deshabilitación Transparent Huge Pages
│   └── template.sh       # Plantilla para nuevos módulos
└── docs/                 # Documentación del proyecto
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Sistema operativo compatible: Debian 11/12 o Ubuntu 20.04/22.04/24.04
- Acceso root al servidor
- Bash 4.0 o superior

### Instalación y Uso
```bash
# 1. Clonar el repositorio
git clone https://github.com/AoC-Gamers/L4D2-Dedicated-Server-Optimizer.git
cd L4D2-Dedicated-Server-Optimizer

# 2. Configurar permisos de ejecución
chmod +x server-optimizer.sh
chmod +x modules/*.sh

# 3. Copiar y personalizar la configuración (opcional)
cp .env.example .env
nano .env

# 4. Ejecutar el optimizador
sudo ./server-optimizer.sh
```

## 📦 Módulos de Optimización Disponibles

### 🧠 Memoria
- **`swap_opt.sh`** - Optimización Memoria Virtual
  - Configura `vm.swappiness=10` para reducir uso de swap
  - Habilita `vm.overcommit_memory=1` para mejor gestión de memoria
  - *Impacto*: Mejora la gestión de memoria y reduce el uso de swap para mejor rendimiento

- **`thp_disable.sh`** - Deshabilitación Transparent Huge Pages
  - Desactiva THP que puede causar latencia impredecible
  - Crea servicio systemd para persistencia tras reinicios
  - *Impacto*: Reduce latencia y mejora consistencia del rendimiento

### 🌐 Red
- **`network_base.sh`** - Configuración Base de Red
  - Optimiza buffers del kernel (`rmem_max`, `wmem_max`)
  - Ajusta `netdev_max_backlog` para mejor manejo de paquetes
  - *Impacto*: Optimiza buffers de red para reducir pérdida de paquetes y mejorar rendimiento UDP

- **`network_advanced.sh`** - Configuración Avanzada de Red
  - Configura disciplinas de cola (`fq_codel`, `fq`, `pfifo_fast`)
  - Ajusta MTU y desactiva offloads problemáticos
  - *Impacto*: Configuración avanzada de red para latencia mínima y máximo throughput

- **`tcp_udp_params.sh`** - Parámetros TCP/UDP Avanzados
  - Habilita BBR congestion control para TCP
  - Optimiza parámetros UDP específicos para gaming
  - *Impacto*: Optimiza TCP congestion control y memoria UDP para mejor rendimiento de red

- **`dns_optimizer.sh`** - Optimización DNS
  - Configura servidores DNS de alta velocidad (Cloudflare, Google, OpenDNS, Quad9)
  - Soporte para DNS personalizados
  - *Impacto*: Mejora conectividad del servidor y reduce latencia en operaciones de red

- **`ipv6_disable.sh`** - Deshabilitación IPv6
  - Desactiva IPv6 mediante sysctl y GRUB
  - Evita problemas de conectividad dual-stack
  - *Impacto*: Elimina problemas de conectividad IPv6 y simplifica configuración de red

### 💾 Disco
- **`disk_opt.sh`** - Optimización I/O de Disco
  - Configura scheduler I/O optimizado (`mq-deadline`, `kyber`, `bfq`)
  - Ajustes específicos para SSDs y HDDs
  - *Impacto*: Mejora rendimiento de I/O para carga/guardado más rápido de mapas y datos

### ⚡ CPU
- **`irq_opt.sh`** - Optimización IRQ
  - Balancea interrupciones entre núcleos CPU
  - Habilita Receive Packet Steering (RPS)
  - *Impacto*: Distribuye interrupciones de red para mejor utilización de CPU multinúcleo

## 🔧 Configuración Avanzada

### Variables de Entorno
El sistema utiliza un archivo `.env` para configuración centralizada:

```bash
# Ejemplo de configuración de red
NETWORK_DNS_PROVIDER="cloudflare"          # Proveedor DNS
NETWORK_TCP_CONGESTION="bbr"               # Control de congestión TCP
NETWORK_MTU_SIZE="1500"                    # Tamaño MTU
MEMORY_SWAPPINESS="10"                     # Tendencia a usar swap
DISK_SCHEDULER="mq-deadline"               # Scheduler I/O
```

### Sistema de Respaldos
- Respaldo automático de archivos de configuración
- Almacenamiento en `/var/lib/l4d2-optimizer/backups/`
- Comandos de estado del sistema antes de cambios

### Modo Debug
```bash
# Habilitar modo debug en .env
OPTIMIZER_DEBUG=1

# Información detallada en terminal y logs
# Archivo debug: /var/log/l4d2-optimizer/debug.log
```

## 📊 Características Avanzadas

- **🔍 Verificación de Dependencias**: Validación automática de módulos y paquetes requeridos
- **⏱️ Sistema de Timeout**: Protección contra módulos bloqueados
- **📝 Registro Completo**: Logs detallados de todas las operaciones
- **🔄 Gestión de Estado**: Seguimiento del estado de instalación de cada módulo
- **🎯 Categorización**: Módulos organizados por tipo (memoria, red, disco, cpu, etc.)
- **🛡️ Modo Seguro**: Verificaciones de compatibilidad antes de ejecutar

## 🤝 Desarrollo de Módulos

El sistema incluye un `template.sh` que facilita la creación de nuevos módulos de optimización. Consulta la documentación en [`docs/template.md`](docs/template.md) para aprender a desarrollar tus propios módulos.

## 📚 Documentación

### Documentación del Sistema
- [`docs/server-optimizer.md`](docs/server-optimizer.md) - Funcionamiento del sistema principal
- [`docs/template.md`](docs/template.md) - Guía para desarrollo de módulos

### Documentación de Módulos
- [`docs/irq_opt.md`](docs/irq_opt.md) - IRQ Optimization - Optimización de interrupciones CPU
- [`docs/disk_opt.md`](docs/disk_opt.md) - Disk Optimization - Optimización de scheduler I/O de disco
- [`docs/network_advanced.md`](docs/network_advanced.md) - Network Advanced - Configuraciones avanzadas de red (QDisc, MTU, Offloads)
- [`docs/ipv6_disable.md`](docs/ipv6_disable.md) - IPv6 Disable - Desactivación completa del protocolo IPv6
- [`docs/thp_disable.md`](docs/thp_disable.md) - THP Disable - Desactivación de Transparent HugePages para menor latencia
- [`docs/dns_optimizer.md`](docs/dns_optimizer.md) - DNS Optimizer - Optimización de servidores DNS para mejor conectividad
- [`docs/network_base.md`](docs/network_base.md) - Network Base - Configuración fundamental de buffers y parámetros de red
- [`docs/swap_opt.md`](docs/swap_opt.md) - Swap Optimization - Optimización de memoria virtual y swappiness
- [`docs/tcp_udp_params.md`](docs/tcp_udp_params.md) - TCP/UDP Parameters - Optimización de protocolos TCP y UDP

## 🐛 Depuración y Logs

### Ubicaciones de Logs
```bash
/var/log/l4d2-optimizer/
├── optimizer.log    # Log principal del sistema
└── debug.log       # Log detallado (modo debug)
```

### Estado del Sistema
```bash
/var/lib/l4d2-optimizer/
├── module_status    # Estado de instalación de módulos
└── backups/        # Respaldos automáticos
```

## ⚠️ Consideraciones Importantes

- **Requiere permisos root** para modificar configuraciones del sistema
- **Crear respaldos** antes de usar en producción
- **Probar en entorno de desarrollo** antes de aplicar en servidores en vivo
- **Revisar logs** después de cada aplicación de módulos

## 🆘 Soporte

- **Issues**: [GitHub Issues](https://github.com/AoC-Gamers/L4D2-Dedicated-Server-Optimizer/issues)
- **Discusiones**: [GitHub Discussions](https://github.com/AoC-Gamers/L4D2-Dedicated-Server-Optimizer/discussions)
- **Wiki**: [GitHub Wiki](https://github.com/AoC-Gamers/L4D2-Dedicated-Server-Optimizer/wiki)

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 👥 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Haz fork del proyecto
2. Crea una rama para tu funcionalidad
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 🏆 Créditos

Desarrollado por **AoC-Gamers** para la comunidad de Left 4 Dead 2.

---

<div align="center">

**¿Te ha sido útil este proyecto? ⭐ Dale una estrella en GitHub!**

</div>
