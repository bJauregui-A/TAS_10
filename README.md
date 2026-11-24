# Nodo Sur · TAS 2026 · Grupo #10

## Integrantes
- **Marcelo Carrasco**
- **Benjamín Jáuregui**
- **Benjamín Reyes**

**Docente:** José Antonio Arellano V.  
**Asignatura:** Taller de Administración de Sistemas (EIN-090B)  
**Semestre:** Segundo Semestre · 2026

---

## 1. Arquitectura de la Plataforma

El proyecto implementa una arquitectura modular y distribuida de 5 máquinas virtuales en Proxmox, estructurada en capas funcionales con perímetro de seguridad y almacenamiento compartido:

```
                                [ Cliente / Navegador ]
                                           │
                         DNS (53/udp)      │ HTTPS (443/tcp)
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ BORDE PERIMETRAL · ns1 (10.33.195.185 / 10.33.199.82)                       │
│  - HAProxy 3.0 (TLS termination, balanceo 50/50 roundrobin, stats :8404)    │
│  - BIND 9.20 (DNS autoritativo cms.tas10.local y recursivo para LAN)        │
│  - Bastión SSH (acceso estricto por llave criptográfica profesor_tas10.pem)│
│  - Servidor NTP interno (chrony en 10.33.199.82 para sincronización LAN)    │
│  - Stack de Observabilidad: Prometheus, Grafana (:3000), Alertmanager,      │
│    Blackbox exporter y mysqld_exporter (Docker Compose separado)           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Red Privada (10.33.199.80/29)
                  ┌────────────────────┴────────────────────┐
                  ▼                                         ▼
┌───────────────────────────────────┐     ┌───────────────────────────────────┐
│ CMS 1 · benserver (10.33.199.83)  │     │ CMS 2 · tascms2 (10.33.199.86)    │
│  - WordPress 6.7 + WooCommerce    │     │  - WordPress 6.7 + WooCommerce    │
│  - Tema oficial Storefront        │     │  - Tema oficial Storefront        │
│  - Contenedor Docker cms_backend  │     │  - Contenedor Docker nodo_cms2    │
│  - Healthcheck HTTP cada 30s      │     │  - Healthcheck HTTP cada 30s      │
└───────────────┬───────────────────┘     └───────────────┬───────────────────┘
                │                                         │
                ├────────────────────┬────────────────────┤
                │ NFS (2049/tcp)     │                    │ MariaDB (7033/tcp)
                ▼                    │                    ▼
┌─────────────────────────────────┐  │  ┌─────────────────────────────────────┐
│ STORAGE · marcelovers (.84)     │  │  │ BASE DE DATOS · ubuntudb (.85)      │
│  - NFS Server /srv/nfs/wp-uploads  │  │  - MariaDB 10.11 en puerto 7033     │
│  - Respaldo diario cron 02:00 AM│  │  - Drop-in systemd Restart=on-failure  │
│  - Retención 7 días (.sql.gz)   │  │  - Aislada sin salida a internet       │
│  - Drop-in systemd autorestart  │  │  - Verificación de integridad y RTO ~4s│
└─────────────────────────────────┘  │  └─────────────────────────────────────┘
```

1. **Borde perimetral (`ns1` · `10.33.195.185` / `10.33.199.82`):** Única máquina con interfaz pública en la WAN del laboratorio. Termina TLS en HAProxy, responde consultas DNS con BIND9, sincroniza la hora de la LAN con `chrony` y aloja el bastión SSH y la observabilidad (Prometheus + Grafana).
2. **Capa Web (`CMS1` · `10.33.199.83` y `CMS2` · `10.33.199.86`):** Dos servidores idénticos en contenedores Docker ejecutando WordPress 6.7 + WooCommerce 9.7 sobre el tema oficial **Storefront**. HAProxy reparte las solicitudes en proporción 50/50 con balanceo `roundrobin` e inserción de cookie `SRV`.
3. **Almacenamiento Compartido y Respaldos (`marcelovers` · `10.33.199.84`):** Servidor NFSv4 (`/srv/nfs/wp-uploads`) montado en `/var/www/html/wp-content/uploads` en ambos CMS vía `/etc/fstab` con opciones `defaults,_netdev,vers=4`. Ejecuta respaldos diarios automatizados de base de datos e imágenes a las 02:00 AM con rotación de 7 días.
4. **Base de Datos (`ubuntudb` · `10.33.199.85`):** Instancia MariaDB dedicada en el puerto no estándar `7033/tcp`, aislada en la red privada y accesible únicamente por CMS1, CMS2 y la máquina de almacenamiento para respaldos.

---

## 2. WordPress, Tienda y Experiencia de Usuario

- **Tema:** **Storefront** oficial de WooCommerce, adaptado en español nativo (`es_ES`) en ambos nodos.
- **Cabecera y Navegación:** Menú principal limpio con enlaces a **Inicio** y **Tienda**. En el extremo derecho se ubica el canasto del carrito en tiempo real (`$0 0 artículos`) y un acceso directo a **Mi cuenta** mediante ícono de usuario SVG.
- **Catálogo de Productos:**
  - *Taller de Pintura Acrílica* (`/product/pintura/`, ID 33): $25.000 CLP, con fotografía real en NFS y stock activo.
  - *Cerámica Artesanal Nodo Sur* (`/product/marceloco/`, ID 28): $18.990 CLP, con fotografía real en NFS y stock activo.
- **Flujo de Compra y Pasarelas de Pago:**
  - Páginas de Carrito (`/cart/`) y Checkout (`/checkout/`) configuradas con shortcodes clásicos estándar (`[woocommerce_cart]` y `[woocommerce_checkout]`), eliminando dependencias de bloques experimentales y garantizando estabilidad y traducción 100% en español.
  - Pasarelas activas: **Pago contra entrega (COD)** por defecto y **Transferencia bancaria directa (BACS)** con instrucciones de pago de Nodo Sur.
- **Cuentas de Acceso Preconfiguradas:**

| Usuario | Rol | Contraseña | Destino |
|:---|:---|:---|:---|
| `breyesc` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `ben4shot` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `profesor` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `cliente` | Cliente | `tas_10` | [Mi cuenta](https://cms.tas10.local/my-account/) / Tienda |

---

## 3. Alta Disponibilidad, Resiliencia y Pruebas de Carga

### Autolevantamiento ante fallos
- **MariaDB (`ubuntudb`):** Configurado con drop-in systemd `/etc/systemd/system/mariadb.service.d/autorestart.conf` con directivas `Restart=on-failure` y `RestartSec=5s`. Si el proceso muere inesperadamente (`kill -9`), se recupera automáticamente en 5 segundos sin alterar detenciones manuales programadas (`systemctl stop`).
- **NFS y Cron (`marcelovers`):** Servicios `nfs-mountd` y `cron` con drop-ins systemd `Restart=on-failure` y `RestartSec=5s`.
- **Contenedores Web (`CMS1` y `CMS2`):** Políticas de reinicio `restart: unless-stopped` combinadas con healthchecks periódicos cada 30s contra `/wp-login.php`.

### Rendimiento medido con k6
Se diseñaron y ejecutaron tres suites de pruebas de carga contra `https://cms.tas10.local`:
1. **Carga nominal ([k6-resistencia.js](file:///home/ben4shot/Develop/TAS_10/config/pruebas/k6-resistencia.js)):** 30 usuarios virtuales concurrentes durante 1 minuto navegando por portada, tienda y producto. **Resultado:** 100% éxito (0% errores), mediana de latencia 297 ms, p95 2.10 s.
2. **Estrés de lectura ([k6-estres.js](file:///home/ben4shot/Develop/TAS_10/config/pruebas/k6-estres.js)):** Rampa progresiva 30 → 60 → 100 → 150 VUs (2.310 peticiones, 20.06 req/s). **Resultado:** 0% de errores sostenido hasta ~135–140 VUs simultáneos. Punto de saturación en ~145 VUs por saturación de CPU de Apache/PHP sin caída de HAProxy ni MariaDB.
3. **E-commerce realista con escritura ([k6-ecommerce-realista.js](file:///home/ben4shot/Develop/TAS_10/config/pruebas/k6-ecommerce-realista.js)):** Rampa de 15 → 35 → 60 → 80 VUs ejecutando el flujo transaccional completo: Portada → Catálogo → Descarga de imagen NFS (.webp/jpg) → Ficha de producto → `POST add_to_cart` (escritura en MariaDB) → Carrito → Checkout. **Resultado:** 2.751 peticiones, 384 compras/carritos completados, **0.00% de errores**, p95 de 5.67 s en el pico máximo de 80 VUs concurrentes con escrituras activas.

---

## 4. Estructura del Repositorio

```
/
├── README.md                                  # Visión general, arquitectura y accesos
├── INVENTARIO.md                              # Tabla de VMs, IPs WAN/LAN y servicios
├── DECISIONES.md                              # Registro formal de decisiones técnicas (ADR)
├── bitacora.md                                # Bitácora de incidentes y soluciones
├── RUNBOOK.md                                 # Guía operativa y guion paso a paso de la demo
├── CONTRIBUCIONES.md                          # Matriz de aportes por integrante
├── ia-uso.md                                  # Declaración de uso ético de IA
├── Informe_Entrega_Final_TAS_2026_Grupo10.docx# Informe formal para evaluación docente
├── profesor_tas10.pem                         # Llave SSH privada para evaluación docente
├── contenedores/
│   ├── cms1/                                  # Docker Compose y configs de CMS 1
│   └── cms2/                                  # Docker Compose y configs de CMS 2
└── config/
    ├── ns1-docker/                            # Compose y configs del borde (HAProxy y BIND9)
    ├── monitoreo/                             # Stack Prometheus, Grafana y exporters
    ├── pruebas/                               # Scripts de carga k6 (nominal, estrés, e-commerce)
    ├── firewall.md                            # Matriz de reglas UFW por nodo
    └── restauracion-rpo-rto.md                # Validación de RPO/RTO y prueba de restauración
```

---

## 5. Accesos Rápidos para Evaluación

- **Tienda Pública:** [https://cms.tas10.local/](https://cms.tas10.local/)
- **Panel de Administración:** [https://cms.tas10.local/wp-admin/](https://cms.tas10.local/wp-admin/)
- **Informe de Entrega Final:** [Informe_Entrega_Final_TAS_2026_Grupo10.pdf](Informe_Entrega_Final_TAS_2026_Grupo10.pdf) y [Informe_Entrega_Final_TAS_2026_Grupo10.docx](Informe_Entrega_Final_TAS_2026_Grupo10.docx)
- **Cuentas de Acceso para Evaluación:**
  | Usuario | Rol | Contraseña | Propósito |
  |---|---|---|---|
  | `profesor` | Administrador (Super Admin) | `tas_10` | Evaluación docente y gestión completa |
  | `breyesc` | Administrador (Super Admin) | `tas_10` | Cuenta de equipo / Integrante |
  | `ben4shot` | Administrador (Super Admin) | `tas_10` | Cuenta de equipo / Integrante |
  | `cliente` | Cliente (Customer) | `tas_10` | Pruebas de compra, carrito y checkout |
- **Estadísticas HAProxy:** [http://10.33.195.185:8404/](http://10.33.195.185:8404/)
- **Panel de Monitoreo Grafana:** [http://10.33.195.185:3000/](http://10.33.195.185:3000/) *(Usuario: `admin` · Clave: `tas10_grafana` · Incluye paneles 12 y 13 con State Timeline de caídas de máquinas y servicios)*
- **Bastión SSH:**
  ```bash
  ssh -i profesor_tas10.pem profesor@10.33.195.185
  ```
- **Salto hacia equipos privados desde el cliente:**
  ```bash
  ssh -i profesor_tas10.pem -J profesor@10.33.195.185 profesor@10.33.199.85  # MariaDB
  ssh -i profesor_tas10.pem -J profesor@10.33.195.185 profesor@10.33.199.84  # Storage/Backups
  ssh -i profesor_tas10.pem -J profesor@10.33.195.185 profesor@10.33.199.83  # CMS1
  ssh -i profesor_tas10.pem -J profesor@10.33.195.185 profesor@10.33.199.86  # CMS2
  ```

---

## 6. Scripts Automatizados para Demostración en Vivo

Para ejecutar la demostración y defensa de forma rápida y controlada, se disponen tres scripts en el directorio raíz:

1. **Ataque y Saturación con k6 (`./demo_ataque_k6.sh`):**
   ```bash
   ./demo_ataque_k6.sh
   ```
   Ejecuta ráfagas de peticiones concurrentes contra `https://cms.tas10.local/` (60s a 120 VUs en modo rápido, hasta 300 VUs en modo extremo) para observar el comportamiento y la resiliencia en tiempo real en Grafana y HAProxy.
2. **Comprobación y Restauración de Respaldos (`./demo_comprobar_respaldos.sh`):**
   ```bash
   ./demo_comprobar_respaldos.sh
   ```
   Audita los respaldos en `10.33.199.84`, valida su integridad binaria (`gzip -t` / `tar -tzf`), mide el **RTO en vivo** (~3.7s) restaurando contra `wordpress_eval` y compara la consistencia del 100% de tablas y registros frente a producción (cumple la **Etapa 4** de la rúbrica).
3. **Caídas Controladas y Failover (`./demo_caida_servicios.sh`):**
   ```bash
   ./demo_caida_servicios.sh
   ```
   Menú interactivo para inyectar caídas de MariaDB (`systemctl stop mariadb`), failover de contenedor CMS1 o caída de host (`node_exporter`) para ver cómo el **State Timeline de Grafana** pinta el incidente en rojo y cómo se recupera en verde (cumple la **Etapa 3** de la rúbrica).

---

## 7. Etapas de Evaluación y Defensa en Vivo (Viernes 27/11)

Las 6 etapas establecidas para la defensa presencial se encuentran detalladas y automatizadas con comandos exactos en **[RUNBOOK.md](RUNBOOK.md)**:
1. **Etapa 1:** Servicios operativos y validación de dependencia de Base de Datos.
2. **Etapa 2:** Resolución DNS (`cms.tas10.local` $\to$ `10.33.195.185`) y navegación HTTPS.
3. **Etapa 3:** Observabilidad y caída controlada de BD (`systemctl stop mariadb`, alertas Grafana y logs NTP).
4. **Etapa 4:** Restauración de BD en base de evaluación (`wordpress_eval`, RTO real 3.79s, RPO 0s).
5. **Etapa 5:** Validación final y recuperación de servicios.
6. **Etapa 6:** Defensa individual sobre arquitectura, decisiones y operación.
