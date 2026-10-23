# Inventario de Máquinas Virtuales

A continuación se detalla la lista de máquinas virtuales del proyecto en Proxmox, sus direcciones IP y la función asignada a cada una:

| Nombre de VM (Proxmox) | IP WAN (Laboratorio) | IP Privada (LAN) | Función principal |
|---|---|---|---|
| **244 (Ubuntu-BJ)** | `10.33.195.185` | `10.33.199.82` | **Borde perimetral:** Balanceador de carga (HAProxy con HTTPS/TLS), servidor de nombres autoritativo (DNS BIND9) y bastión SSH. |
| **243 (ubuntu-br)** | `10.33.195.206` | `10.33.199.83` | **CMS 1:** Servidor web principal con WordPress y tienda WooCommerce. |
| **260 (cms-2)** | `10.33.195.167` | `10.33.199.86` | **CMS 2:** Réplica idéntica de WordPress para balanceo de carga y tolerancia a fallos. |
| **220 (Marcelo)** | `10.33.195.192` | `10.33.199.84` | **Almacenamiento y Respaldos:** Servidor NFS para sincronizar imágenes de WordPress y tareas de backup automático. |
| **274 (ubuntu-db)** | *Sin WAN* | `10.33.199.85` | **Base de Datos:** Servidor MariaDB dedicado en puerto no estándar (7033), aislado de internet. |

---

## Detalle de recursos por máquina

Todas las máquinas virtuales corren sobre **Ubuntu Server 24.04 LTS** y tienen asignados los siguientes recursos base:

- **Procesador:** 2 vCPU
- **Memoria RAM:** 2.0 GB (1.9 GiB disponibles)
- **Disco:** 97 GB (gestión por volúmenes lógicos LVM)
