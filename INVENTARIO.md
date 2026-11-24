# Inventario de Máquinas Virtuales

A continuación se detalla la lista de máquinas virtuales del proyecto en Proxmox, sus direcciones IP y la función asignada a cada una:

| Nombre de VM (Proxmox) | IP WAN (Laboratorio) | IP Privada (LAN) | Función principal |
|---|---|---|---|
| **244 (Ubuntu-BJ)** | `10.33.195.185` | `10.33.199.82` | **Borde perimetral y observabilidad:** Balanceador (HAProxy con HTTPS/TLS y `/metrics`) y DNS (BIND9) en Docker Compose; bastión SSH y servidor NTP interno (`chrony`) en host; stack de monitoreo (`Prometheus`, `Grafana`, `Alertmanager`, `Blackbox`, `mysqld_exporter`) en Docker Compose separado. |
| **243 (ubuntu-br)** | `10.33.195.206` | `10.33.199.83` | **CMS 1:** Servidor web principal con WordPress y WooCommerce en Docker, conectado a MariaDB y NFS. |
| **260 (cms-2)** | `10.33.195.167` | `10.33.199.86` | **CMS 2:** Réplica idéntica de WordPress en Docker (`nodo_cms2`) para balanceo de carga y tolerancia a fallos, conectada a MariaDB y NFS. |
| **220 (Marcelo)** | *Sin WAN* | `10.33.199.84` | **Almacenamiento y Respaldos:** Servidor NFS (`/srv/nfs/wp-uploads`) y backups automatizados diarios (`cron` 02:00 AM) con verificación de integridad, aislado de internet. |
| **274 (ubuntu-db)** | *Sin WAN* | `10.33.199.85` | **Base de Datos:** Servidor MariaDB dedicado en puerto no estándar (`7033`), aislado de internet. |

---

## Detalle de recursos y servicios transversales

Todas las máquinas virtuales corren sobre **Ubuntu Server 24.04 LTS** y tienen asignados los siguientes recursos base:

- **Procesador:** 2 vCPU
- **Memoria RAM:** 2.0 GB (1.9 GiB disponibles)
- **Disco:** 97 GB (gestión por volúmenes lógicos LVM)
- **Métricas de host:** `node_exporter` activo en las 5 VMs (puerto `9100/tcp`, accesible únicamente desde `10.33.199.82`).
- **Sincronización horaria (NTP):** Las 5 VMs sincronizadas (`ns1`, `CMS1` y `CMS2` hacia internet; `marcelovers` y `ubuntudb` contra `chrony` interno en `10.33.199.82`).

---

## Servicios Web y Cuentas de Acceso

- **CMS y Motor E-commerce:** WordPress 6.7.2 + WooCommerce 9.7.1 sobre PHP 8.3 Apache en contenedores Docker (`CMS1` y `CMS2`).
- **Tema:** Storefront 4.6.2 en español (`es_ES`).
- **Almacenamiento de Medios:** `/var/www/html/wp-content/uploads` montado vía NFSv4 desde `10.33.199.84:/srv/nfs/wp-uploads`.
- **Cuentas de Acceso (todas con clave `tas_10`):**
  - `breyesc`: Administrador (Super Admin)
  - `ben4shot`: Administrador (Super Admin)
  - `profesor`: Administrador (Super Admin)
  - `cliente`: Cliente (Customer)
