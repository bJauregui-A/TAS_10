# Runbook Operativo y Guion de Defensa · Nodo Sur (Grupo 10)

Guía operativa para diagnosticar, contener, recuperar y revertir incidentes en la plataforma **Nodo Sur**, más el guion paso a paso para la demostración en vivo.

> **Nota de seguridad:** Este documento no incluye contraseñas ni llaves privadas. Todos los accesos SSH hacia la red privada (`10.33.199.80/29`) se realizan saltando a través del bastión `ns1` (`10.33.195.185`).

---

## 1. Mapa rápido de componentes y responsables

| Componente | VM / IP privada | Servicio | Responsable |
|---|---|---|---|
| Borde (HAProxy + DNS + Bastión + NTP) | `ns1` · `10.33.199.82` (WAN `10.33.195.185`) | Docker Compose `/opt/nodo-sur-borde` + `chrony` | Marcelo Carrasco / Benjamín Jáuregui |
| Monitoreo (Prometheus + Grafana + Alertmanager) | `ns1` · `10.33.199.82` (Grafana `:3000`) | Docker Compose `/opt/nodo-sur-monitoreo` | Equipo Grupo 10 |
| CMS 1 (`cms_backend`) | `benserver` · `10.33.199.83` | Docker Compose `/home/ben_admin/docker` | Benjamín Reyes |
| CMS 2 (`nodo_cms2`) | `tascms2` · `10.33.199.86` | Docker Compose `/opt/nodo-sur-cms2` | Benjamín Reyes |
| Almacenamiento y Respaldos (NFS + Cron) | `marcelovers` · `10.33.199.84` | `nfs-kernel-server` + `/backups/scripts/hacer_backup.sh` | Marcelo Carrasco |
| Base de Datos (MariaDB `:7033`) | `ubuntudb` · `10.33.199.85` | `mariadb.service` | Benjamín Jáuregui |

### Cuentas preconfiguradas para la evaluación

| Usuario | Rol | Contraseña | Destino |
|:---|:---|:---|:---|
| `breyesc` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `ben4shot` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `profesor` | Administrador | `tas_10` | [wp-admin](https://cms.tas10.local/wp-admin/) / [Mi cuenta](https://cms.tas10.local/my-account/) |
| `cliente` | Cliente | `tas_10` | [Mi cuenta](https://cms.tas10.local/my-account/) / Tienda |

---

## 2. Guion paso a paso · Demo en vivo (6 etapas)

### Etapa 1 · Servicios operativos
1. Mostrar topología (borde único en WAN + 2 CMS en Docker + NFS/Backups + MariaDB en red privada).
2. Verificar contenedores y servicios activos:
   ```bash
   # En ns1 (borde + monitoreo)
   sudo docker ps --format "table {{.Names}}\t{{.Status}}"
   curl -s 'http://127.0.0.1:8404/;csv' | grep cms_backend | cut -d, -f1,2,18,37

   # En CMS1 y CMS2
   sudo docker ps --format "table {{.Names}}\t{{.Status}}"

   # En ubuntudb (MariaDB) y marcelovers (NFS/cron)
   systemctl is-active mariadb
   systemctl is-active nfs-kernel-server cron
   ```
3. Operación funcional desde el cliente (consulta real a BD): abrir `https://cms.tas10.local/shop/` y `https://cms.tas10.local/product/pintura/` y verificar respuesta `HTTP 200`.
4. Flujo transaccional de compra: agregar al carrito, abrir `https://cms.tas10.local/checkout/`, seleccionar *Pago contra entrega* y confirmar pedido; verificar registro inmediato en MariaDB:
   ```bash
   mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 wordpress -e "SELECT id, status, total_amount, payment_method_title FROM wp_wc_orders ORDER BY id DESC LIMIT 1;"
   ```

---

### Etapa 2 · Registro A del DNS
1. Mostrar el registro `A` en la zona autoritativa en `ns1`:
   ```bash
   cat /opt/nodo-sur-borde/bind9/zones/db.tas10.local
   ```
2. Consultar desde cliente al DNS del proyecto (`10.33.195.185`):
   ```bash
   dig @10.33.195.185 cms.tas10.local +short
   # Resultado esperado: 10.33.195.185
   ```
3. Explicar que `10.33.195.185` corresponde al **borde HAProxy**, el cual termina TLS (443) y balancea 50/50 hacia `CMS1` (`10.33.199.83`) y `CMS2` (`10.33.199.86`). Abrir `https://cms.tas10.local` por nombre en el navegador.

---

### Etapa 3 · Observabilidad e incidente controlado de Base de Datos
1. **Estado normal previo:** Abrir Grafana en `http://10.33.195.185:3000` (dashboard *Nodo Sur · Grupo 10 · Salud General*) y mostrar:
   - `Hosts Activos: 5`, `Backends CMS UP: 2`, `MariaDB: UP`, `Sonda HTTPS: 2`, `Alertas Activas: 0`.
2. **Inyectar falla controlada en `ubuntudb` (`10.33.199.85`):**
   ```bash
   date -u +"%Y-%m-%dT%H:%M:%SZ"
   sudo systemctl stop mariadb
   ```
   *(Nota: `systemctl stop` mantiene MariaDB detenido para la demo; ante un crash inesperado `kill -9`, `Restart=on-failure` lo levanta automáticamente en 5 s).*
3. **Repetir operación del CMS desde el cliente:** Recargar `https://cms.tas10.local/shop/` → falla con error de conexión a base de datos (`HTTP 500`).
4. **Evidencia con marcas de tiempo sincronizadas (NTP):**
   - **Grafana (`:3000`):** `MariaDB` pasa a **`DOWN`**, `Sonda HTTPS` cae a **`0`**, y tras `30 s` se disparan las alertas **`MariaDBCaida`** (`critical`) y **`SitioWebCaido`** (`critical`).
   - **Logs con hora UTC coincidente:**
     ```bash
     # En ubuntudb
     sudo journalctl -u mariadb -n 15 --no-pager

     # En CMS1 o CMS2
     sudo docker logs cms_backend --tail 15

     # En ns1 (HAProxy)
     sudo docker logs edge_haproxy --tail 15
     ```

---

### Etapa 4 · Estabilización y restauración de datos (dato ausente que reaparece)
1. **Estabilizar el motor en `ubuntudb`:**
   ```bash
   sudo systemctl start mariadb
   systemctl is-active mariadb
   ```
2. **Identificar el respaldo vigente en `marcelovers` (`10.33.199.84`):**
   ```bash
   sudo ls -lh /backups/db/
   # Ejemplo: /backups/db/db_wordpress_YYYYMMDD_HHMMSS.sql.gz
   ```
3. **Demostración segura de dato ausente que reaparece (usando copia de evaluación o dato de prueba):**
   - **Opción recomendada (sin alterar producción):** crear base temporal `wordpress_eval`, restaurar el respaldo, verificar el producto de prueba (`Pintura`, ID 33) o borrar un registro de prueba en `wordpress_eval` antes de restaurar para mostrar **antes (ausente) → restauración → después (reaparece)**:
     ```bash
     # En ubuntudb: crear BD de evaluacion vacia (dato ausente)
     sudo mariadb -e "DROP DATABASE IF EXISTS wordpress_eval; CREATE DATABASE wordpress_eval;"
     sudo mariadb -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wordpress_eval';"
     # Resultado antes de restaurar: 0 tablas / dato ausente

     # En marcelovers (o transfiriendo el dump a ubuntudb): restaurar con medicion de tiempo
     T0=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
     gunzip -c /backups/db/db_wordpress_<FECHA>.sql.gz | mariadb -h 10.33.199.85 -P 7033 -u tas_cms -p wordpress_eval
     T1=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
     echo "Restauracion: $T0 -> $T1"

     # En ubuntudb: comprobar que el producto reaparecio
     sudo mariadb -e "SELECT ID, post_title, post_status FROM wordpress_eval.wp_posts WHERE post_type='product';"
     ```
   - **Si se demuestra sobre un producto de prueba en producción:** asegurarse antes de la demo de correr `/backups/scripts/hacer_backup.sh` con el producto de prueba ya creado, borrar ese producto en WooCommerce/BD (mostrar que desapareció de `/shop/`), restaurar el `.sql.gz` sobre `wordpress` y recargar `/shop/` para ver que reaparece.

---

### Etapa 5 · Validación final
1. Recargar desde el cliente `https://cms.tas10.local/shop/` y `https://cms.tas10.local/product/pintura/` → `HTTP 200` con el dato visible.
2. Confirmar balanceo 50/50 desde `ns1`:
   ```bash
   for i in 1 2 3 4; do
     curl -skI -H 'Host: cms.tas10.local' https://127.0.0.1 | grep -iE 'HTTP/|set-cookie:'
   done
   ```
3. Confirmar en **Grafana (`:3000`)** que `MariaDB` volvió a **`UP`**, `Sonda HTTPS` volvió a **`2`**, `Backends CMS UP: 2` y las alertas críticas quedaron resueltas.
4. Limpiar base temporal de evaluación si se usó (`DROP DATABASE IF EXISTS wordpress_eval;`).

---

### Etapa 6 · Reparto sugerido para defensa individual
- **Benjamín Jáuregui:** DNS (`dig`, zona `db.tas10.local`), MariaDB (puerto `7033`, falla controlada, logs `journalctl`, restauración y SPOF de BD).
- **Marcelo Carrasco:** Borde HAProxy (HTTPS, balanceo, `/metrics`), NFS y respaldos (`cron`, script `hacer_backup.sh`, retención y RPO/RTO).
- **Benjamín Reyes:** Capa web en Docker (`cms_backend`, `nodo_cms2`, `healthcheck`, coherencia NFS en `/var/www/html/wp-content/uploads` y pruebas de carga `k6`).

---

## 3. Scripts Automatizados para la Demostración en Vivo

Para facilitar la ejecución fluida durante los 15-20 minutos de defensa frente a la comisión evaluadora, se han dispuesto tres scripts interactivos en la raíz del repositorio:

### A. Prueba de Ataque y Saturación con k6 (`./demo_ataque_k6.sh`)
Somete el clúster a una ráfaga agresiva de peticiones dinámicas (búsquedas SQL en WooCommerce, ordenamientos de catálogo y accesos concurrentes) para comprobar la resiliencia y el comportamiento ante sobrecarga.
```bash
./demo_ataque_k6.sh
# Modos disponibles:
#   1) Rápido (60s, hasta 120 VUs) - Recomendado para demostración en vivo.
#   2) Estándar (105s, hasta 200 VUs).
#   3) Extremo (145s, hasta 300 VUs - búsqueda de punto de quiebre).
```
- **Qué observar:** Abrir simultáneamente **Grafana** (`http://10.33.195.185:3000/`, `admin:tas10_grafana`) en los paneles de *Tráfico HAProxy*, *Uso de CPU* y *Latencia HTTPS*, más las estadísticas de HAProxy en `http://10.33.195.185:8404/`.

### B. Comprobación y Restauración de Respaldos en Vivo (`./demo_comprobar_respaldos.sh`)
Ejecuta automáticamente la **Etapa 4** de la evaluación:
```bash
./demo_comprobar_respaldos.sh
# Opciones no interactivas:
#   ./demo_comprobar_respaldos.sh --clean   (Restaura, audita y limpia la base de prueba)
#   ./demo_comprobar_respaldos.sh --keep    (Preserva 'wordpress_eval' para inspección docente)
```
- **Flujo automatizado:**
  1. Audita el almacenamiento de respaldos en `10.33.199.84` (`/backups/db/` y `/backups/wp_files/`).
  2. Verifica la integridad binaria (`gzip -t` y `tar -tzf`) y calcula el hash SHA-256.
  3. Comprueba en vivo que la base de datos `wordpress_eval` en MariaDB está **ausente** (0 tablas).
  4. Inicia cronómetro de alta precisión, crea `wordpress_eval` y restaura el volcado por streaming LAN.
  5. Imprime el **RTO medido en tiempo real** (~1.8 a 3.8 segundos).
  6. Compara exhaustivamente la paridad al 100% de tablas (67), usuarios (6), posts (44) y órdenes (5) entre `wordpress` (producción) y `wordpress_eval`.

### C. Caídas Controladas y Observabilidad (`./demo_caida_servicios.sh`)
Permite demostrar la **Etapa 3** (Observabilidad y alertas) con un menú de un solo paso:
```bash
./demo_caida_servicios.sh
# Opciones del menú:
#   1) Caída controlada de MariaDB (systemctl stop mariadb) -> Alerta MariaDBCaida y Timeline ROJO.
#   2) Caída y failover de CMS1 (docker stop cms_backend) -> HAProxy deriva al 100% a CMS2.
#   3) Caída de Host / node_exporter (CMS2) -> Visualización de Host DOWN en State Timeline.
```

---

## 4. Observabilidad y State Timeline en Grafana

El panel de control general en **`http://10.33.195.185:3000/`** (Credenciales: `admin` / `tas10_grafana`) cuenta con dos paneles históricos de disponibilidad:
- **Panel 12: Historial de Disponibilidad y Caídas por Máquina (State Timeline):**
  Monitorea de forma continua las 5 máquinas virtuales (`ns1-borde`, `cms1`, `cms2`, `nfs-backup`, `mariadb`). Cada barra horizontal refleja el historial de tiempo en verde (**UP / OPERATIVO**) y pinta inmediatamente en rojo (**DOWN / CAÍDA**) cualquier desconexión de máquina.
- **Panel 13: Historial de Estado de Servicios Críticos (State Timeline):**
  Registra el historial de salud de los backends de HAProxy (`cms1` y `cms2`), la base de datos MariaDB (`10.33.199.85:7033`) y las sondas sintéticas HTTPS de Blackbox Exporter.
- **Anotaciones de Alertas Prometheus:** Cualquier alerta disparada (`MariaDBCaida`, `SitioWebCaido`, `HostCaido`) se proyecta como una bandera roja vertical directamente sobre las gráficas de tráfico y latencia.

---

## 5. Procedimientos operativos por incidente

### Incidente A · Caída de un nodo CMS (`BackendCMSCaido`)
- **Síntoma:** Alerta `BackendCMSCaido` en Prometheus/Grafana; HAProxy `:8404` marca `cms1` o `cms2` en `DOWN (L7STS/L4CON)`. El sitio sigue operativo por el otro nodo.
- **Diagnóstico:**
  ```bash
  sudo docker ps -a
  sudo docker logs <cms_backend|nodo_cms2> --tail 30
  curl -sI -H 'Host: cms.tas10.local' -H 'X-Forwarded-Proto: https' http://127.0.0.1/wp-login.php
  ```
- **Corrección:**
  ```bash
  # En CMS1 (/home/ben_admin/docker) o CMS2 (/opt/nodo-sur-cms2)
  sudo docker compose up -d
  ```
- **Validación:** HAProxy vuelve a mostrar `UP (L7OK)` y `curl` local devuelve `200 OK`.
- **Reversión:** Si falló tras editar `compose.yaml`, restaurar la versión anterior desde git (`contenedores/cms1/compose.yaml` o `contenedores/cms2/compose.yaml`) y ejecutar `docker compose up -d --force-recreate`.

---

### Incidente B · Caída del borde HAProxy o DNS (`SitioWebCaido`)
- **Síntoma:** `https://cms.tas10.local` no responde o `dig @10.33.195.185 cms.tas10.local` falla.
- **Diagnóstico en `ns1`:**
  ```bash
  sudo docker ps -a
  sudo docker logs edge_haproxy --tail 30
  sudo docker logs edge_dns --tail 30
  sudo docker exec edge_haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
  ```
- **Corrección:**
  ```bash
  cd /opt/nodo-sur-borde && sudo docker compose up -d
  ```
- **Validación:** `dig @10.33.195.185 cms.tas10.local +short` → `10.33.195.185` y `curl -skI -H 'Host: cms.tas10.local' https://127.0.0.1` → `HTTP/2 200`.
- **Reversión:** Restaurar `/opt/nodo-sur-borde/haproxy/haproxy.cfg` o zona DNS desde `config/ns1-docker/` y reiniciar el contenedor.

---

### Incidente C · NFS desmontado o imágenes faltantes
- **Síntoma:** Las imágenes subidas en un CMS no aparecen en el otro o devuelven `404`.
- **Diagnóstico:**
  ```bash
  # En marcelovers
  systemctl status nfs-kernel-server
  showmount -e 127.0.0.1

  # En CMS1 y CMS2
  mount | grep uploads
  ```
- **Corrección:**
  ```bash
  # En marcelovers (si estaba caido)
  sudo systemctl restart nfs-kernel-server

  # En CMS1 / CMS2
  sudo mount -a
  sudo docker compose restart
  ```
- **Validación:** Crear y leer un archivo de prueba como `www-data` en `/var/www/html/wp-content/uploads` entre ambos contenedores.

---

### Incidente D · Disco alto (`DiscoAlto > 85%`) o fallo de respaldo
- **Síntoma:** Alerta `DiscoAlto` en Grafana o error en `/backups/logs/backup.log`.
- **Diagnóstico en `marcelovers`:**
  ```bash
  df -h
  sudo tail -n 30 /backups/logs/backup.log
  sudo ls -lh /backups/db /backups/wp_files
  ```
- **Corrección:** Ejecutar manualmente `/backups/scripts/hacer_backup.sh` (aplica retención automática de 7 días y verifica integridad con `gzip -t` y `tar -tzf`) o ajustar la retención si el disco creció por exceso de respaldos.
- **Reversión de monitoreo (si el stack de observabilidad consume recursos):**
  ```bash
  cd /opt/nodo-sur-monitoreo && sudo docker compose down
  ```
  *(No afecta HAProxy, BIND9 ni SSH).*
