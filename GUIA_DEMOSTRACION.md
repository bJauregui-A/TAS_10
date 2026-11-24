# Guía Completa de Scripts de Demostración y Pruebas en Vivo
## Proyecto Integrador Nodo Sur · TAS 2026 (Grupo 10)

Esta guía documenta en detalle qué hace cada script, cómo funciona internamente a nivel de arquitectura y red, y cómo utilizarlos paso a paso durante la defensa práctica del viernes 27 de noviembre.

---

## 1. Resumen de Herramientas y Ubicación

Todos los scripts ejecutables se encuentran directamente en el directorio raíz del repositorio:

| Script | Propósito Principal | Etapa de la Rúbrica | Componentes Involucrados |
|---|---|:---:|---|
| **[`./demo_ataque_k6.sh`](demo_ataque_k6.sh)** | Ataque de saturación k6 (búsqueda de límite de resistencia) | Pruebas de Carga | HAProxy (`.185`), CMS1 (`.83`), CMS2 (`.86`), MariaDB (`.85`) |
| **[`./demo_comprobar_respaldos.sh`](demo_comprobar_respaldos.sh)** | Auditoría de respaldos, test de integridad y medición de RTO en vivo | **Etapa 4** | Storage/NFS (`.84`), MariaDB (`.85`), Bastión (`.185`) |
| **[`./demo_caida_servicios.sh`](demo_caida_servicios.sh)** | Inyección de fallas controladas, failover y observabilidad | **Etapa 3** | MariaDB (`.85`), CMS1 (`.83`), CMS2 (`.86`), Grafana (`.185`) |
| **[`./toggle_rate_limiting.sh`](toggle_rate_limiting.sh)** | Interruptor en caliente de Rate Limiting y Bloqueo por IP (HTTP 429) | Seguridad L7 | HAProxy Borde (`10.33.195.185`) |

### Requisitos previos para ejecutar los scripts:
1. Ejecutar desde el equipo de trabajo (o clon del repositorio) que tenga conectividad a la red del proyecto (`10.33.195.185`).
2. La llave SSH `profesor_tas10.pem` debe estar en la raíz con permisos `600`.
3. Contar con `k6` instalado localmente (`~/.local/bin/k6` o en `$PATH`).

---

## 2. Script 1: Prueba de Ataque y Saturación (`./demo_ataque_k6.sh`)

### ¿Qué hace?
Somete el clúster a una ráfaga agresiva de peticiones concurrentes dinámicas para comprobar la capacidad de absorción de carga, la estabilidad de los workers Apache/PHP y el pool de conexiones de MariaDB, permitiendo determinar empíricamente el punto de quiebre (*break-point*) del sistema.

### ¿Cómo funciona internamente?
1. **Lanzador Bash (`demo_ataque_k6.sh`):** Detecta automáticamente el binario de `k6`, ofrece un menú interactivo con 3 perfiles de carga, exporta las variables de entorno necesarias (`TARGET_URL=https://10.33.195.185`, `HOST_HEADER=cms.tas10.local`) y lanza el motor de k6.
2. **Lógica de Carga (`config/pruebas/k6-ataque-saturacion.js`):**
   - **Perfil Rápido (Recomendado para la defensa):** Rampa de 10s a 25 VUs $\to$ 20s a 70 VUs $\to$ 20s a 120 VUs $\to$ 10s de enfriamiento (Duración: 60 segundos).
   - **Perfil Estándar:** Sube progresivamente hasta 200 VUs en 105 segundos.
   - **Perfil Extremo:** Escala agresivamente hasta 300 VUs en 145 segundos.
3. **Estrategia anti-caché y estrés de Base de Datos:**
   - En lugar de consultar únicamente páginas estáticas, cada usuario virtual ejecuta búsquedas aleatorias en WooCommerce (`/?s=<término>&post_type=product`) utilizando un pool rotativo de palabras (`pintura`, `tornillo`, `martillo`, `adhesivo`, etc.). Esto fuerza a WordPress a ejecutar consultas SQL `LIKE` pesadas y `JOINs` sobre `wp_posts` y `wp_postmeta` en MariaDB (`10.33.199.85:7033`).
   - Se alternan ordenamientos dinámicos del catálogo (`/shop/?orderby=price-desc`) y accesos a productos individuales.
4. **Cálculo de Métricas y Diagnóstico:**
   - La función `handleSummary()` recopila las métricas del motor de k6, calcula la tasa de error porcentual, la latencia mediana, percentil 95 ($p95$) y percentil 99 ($p99$).
   - Emite un diagnóstico automático en la terminal clasificando el resultado como:
     - `[EXCELENTE]`: Menos de 2% de fallos bajo carga pico.
     - `[RESILIENTE]`: Entre 2% y 10% de fallos con saturación controlada sin caída de HAProxy.
     - `[PUNTO DE QUIEBRE]`: Más de 10% de fallos, indicando saturación de workers de backend.

### Modo de uso:
```bash
# Modo interactivo (pregunta el perfil)
./demo_ataque_k6.sh

# O pasando el argumento directamente:
./demo_ataque_k6.sh --rapido      # 60s, hasta 120 VUs (ideal defensa)
./demo_ataque_k6.sh --estandar    # 105s, hasta 200 VUs
./demo_ataque_k6.sh --extremo     # 145s, hasta 300 VUs
```

### Qué observar durante la prueba:
- **En Grafana (`http://10.33.195.185:3000/`):** Observar los paneles *Tráfico HAProxy (req/s por backend)* repartiendo 50/50 entre CMS1 y CMS2, y el panel *Uso de CPU (%) por VM*.
- **En HAProxy Stats (`http://10.33.195.185:8404/`):** Ver las columnas `Session rate`, `Cur`, `Max` y el encolamiento de peticiones sin errores 503.

---

## 3. Script 2: Comprobación de Respaldos y Medición de RTO (`./demo_comprobar_respaldos.sh`)

### ¿Qué hace?
Cumple rigurosamente con la **Etapa 4** de la rúbrica docente: audita los respaldos generados automáticamente, certifica su integridad criptográfica y realiza una restauración controlada en una base de datos de evaluación (`wordpress_eval`), demostrando la condición de "dato ausente" antes de restaurar, midiendo el **RTO real con cronómetro de alta precisión** y auditando la paridad del 100% de los datos.

### ¿Cómo funciona internamente?
El script se ejecuta desde la máquina cliente o bastión y orquesta por SSH las siguientes 5 fases:

1. **Fase 1 · Auditoría de Inventario:**
   - Conecta con `marcelovers` (`10.33.199.84`) mediante túnel SSH a través del bastión `10.33.195.185`.
   - Lista `/backups/db/` (volcados MariaDB `.sql.gz`) y `/backups/wp_files/` (archivos NFS `.tar.gz`), seleccionando automáticamente el respaldo más reciente.
2. **Fase 2 · Verificación de Integridad Binaria:**
   - Ejecuta `gzip -t /backups/db/<archivo>.sql.gz` para certificar que el archivo comprimido no posee bloques corruptos.
   - Ejecuta `tar -tzf /backups/wp_files/<archivo>.tar.gz` para validar la estructura del tarball de medios.
   - Calcula el hash SHA-256 del volcado para garantizar no-repudio e inmutabilidad.
3. **Fase 3 · Condición "Dato Ausente" y Medición de RTO:**
   - Conecta a MariaDB (`10.33.199.85:7033`) y ejecuta `SHOW DATABASES;`, certificando que la base `wordpress_eval` está **ausente** (0 tablas).
   - Inicia un cronómetro con resolución de nanosegundos (`date +%s%N`).
   - Crea la base de datos `wordpress_eval` y transfiere el volcado en streaming directo por la red LAN privada:
     ```bash
     gunzip -c /backups/db/<backup>.sql.gz | mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 wordpress_eval
     ```
   - Detiene el cronómetro y calcula:
     $$\text{RTO Técnico} = \frac{T_{\text{fin}} - T_{\text{inicio}}}{10^9} \approx \mathbf{3.79\text{ segundos}}$$
4. **Fase 4 · Auditoría Comparativa de Consistencia:**
   - Ejecuta consultas SQL simultáneas sobre la base de producción (`wordpress`) y la base restaurada (`wordpress_eval`) comparando:
     - Número total de tablas (`information_schema.tables`).
     - Cantidad de usuarios registrados (`wp_users`).
     - Cantidad de publicaciones y productos (`wp_posts`).
     - Cantidad de pedidos y transacciones WooCommerce (`wp_wc_orders`).
   - Imprime una tabla comparativa con verificación de estado (`IDÉNTICO`).
5. **Fase 5 · Veredicto y Limpieza:**
   - Emite el resumen formal de cumplimiento de RPO y RTO.
   - Ofrece conservar la base (`--keep`) para que el profesor la audite manualmente por CLI, o eliminarla (`--clean`) para dejar el ambiente limpio.

### Modo de uso:
```bash
# Modo interactivo (pregunta si se desea conservar wordpress_eval al final)
./demo_comprobar_respaldos.sh

# Modo automático limpiando tras la prueba
./demo_comprobar_respaldos.sh --clean

# Modo automático preservando wordpress_eval para inspección docente
./demo_comprobar_respaldos.sh --keep
```

---

## 4. Script 3: Caídas Controladas, Failover y State Timeline (`./demo_caida_servicios.sh`)

### ¿Qué hace?
Permite demostrar la **Etapa 3** de la evaluación: simula caídas reales de servicios e infraestructura mediante un menú interactivo, permitiendo observar cómo el **State Timeline de Grafana** pinta el incidente en rojo en tiempo real y cómo se restablece en verde tras la recuperación.

### ¿Cómo funciona internamente?
Ofrece tres escenarios de prueba:

#### Opción 1: Caída Controlada de MariaDB (Etapa 3 de la Rúbrica)
1. Ejecuta por SSH en `ubuntudb` (`10.33.199.85`):
   ```bash
   sudo systemctl stop mariadb
   ```
2. **Efecto observable:**
   - En Grafana, el panel *MariaDB (10.33.199.85:7033)* pasa a **`DOWN`** y el **Panel 13 (Historial de Estado de Servicios)** pinta la línea de MariaDB inmediatamente en **rojo**.
   - Tras 30 segundos, Prometheus dispara la alerta crítica **`MariaDBCaida`** y **`SitioWebCaido`**.
   - Al recargar la tienda en `https://cms.tas10.local/shop/`, se observa el mensaje `"Error establishing a database connection"`.
3. Al presionar `[ENTER]`, el script ejecuta `sudo systemctl start mariadb`, verificando que el servicio vuelve a estar `active` y el Timeline de Grafana regresa a **verde**.

#### Opción 2: Caída y Failover de Backend CMS1 (Alta Disponibilidad)
1. Ejecuta por SSH en `benserver` (`10.33.199.83`):
   ```bash
   sudo docker stop cms_backend
   ```
2. **Efecto observable:**
   - El healthcheck de HAProxy (`check inter 5s`) detecta la caída en menos de 5 segundos y marca el servidor `cms1` como `DOWN (L4CON)`.
   - El balanceador deriva automáticamente el **100% de las peticiones hacia CMS2** (`10.33.199.86`).
   - La navegación en la tienda `https://cms.tas10.local/` continúa **sin interrupciones para el usuario**.
   - En Grafana, el Panel 13 muestra la fila `cms1` en **rojo** mientras `cms2` permanece en **verde**.
3. Al presionar `[ENTER]`, reinicia el contenedor (`docker start cms_backend`), HAProxy valida el retorno con `UP (L7OK)` y el tráfico vuelve al balanceo 50/50.

#### Opción 3: Simulación de Caída de Host / Máquina Virtual
1. Ejecuta en `tascms2` (`10.33.199.86`):
   ```bash
   sudo systemctl stop node_exporter
   ```
2. **Efecto observable:**
   - Prometheus deja de recibir métricas de sistema del nodo.
   - En Grafana, el contador *Hosts Activos* cae de 5 a 4 y el **Panel 12 (Historial de Disponibilidad por Máquina)** pinta la fila de `cms2` en **rojo**, demostrando cómo se audita visualmente la caída de cualquier máquina del clúster.
3. Al presionar `[ENTER]`, reactiva `node_exporter`, normalizando el indicador en **verde**.

### Modo de uso:
```bash
./demo_caida_servicios.sh
```

---

## 5. Script 4: Interruptor en Caliente de Rate Limiting (`./toggle_rate_limiting.sh`)

### ¿Qué hace?
Permite activar o desactivar en caliente (**en 0.2 segundos y con cero caída de servicio**) la regla de corte perimetral de HAProxy que bloquea IPs abusivas que superen 120 req/10s (`HTTP 429 Too Many Requests`).

### ¿Para qué sirve durante la defensa?
Permite demostrar a la comisión la eficacia de la seguridad en Capa 7:
1. **Con protección ACTIVADA:**
   Al lanzar `./demo_ataque_k6.sh`, el atacante comienza a recibir respuestas `429 Too Many Requests`. Las peticiones son interceptadas en el borde HAProxy y no tocan a los servidores CMS ni a la base de datos, manteniéndolos al 0% de uso.
2. **Con protección DESACTIVADA (Modo permisivo):**
   Al desactivarlo con `./toggle_rate_limiting.sh off` y volver a lanzar el ataque, todo el tráfico ingresa directamente a los contenedores `CMS1` y `CMS2`, permitiendo evaluar el límite físico de CPU de Apache/PHP y la concurrencia de MariaDB.

### Modo de uso:
```bash
# Menú interactivo
./toggle_rate_limiting.sh

# Comandos directos:
./toggle_rate_limiting.sh on      # Activa el bloqueo perimetral (>120 req/10s -> 429)
./toggle_rate_limiting.sh off     # Desactiva el bloqueo (modo permisivo de estrés)
./toggle_rate_limiting.sh status  # Consulta el estado actual de la regla en HAProxy
```

---

## 6. El Historial de Caídas en Grafana (State Timeline)

### Cómo Ingresar a Grafana:

1. **Vía Navegador Web (Conexión Directa en Red USM / VPN):**
   - **URL:** [http://10.33.195.185:3000/](http://10.33.195.185:3000/)
   - **Usuario:** `admin`
   - **Contraseña:** `tas10_grafana`

2. **Vía Túnel SSH (Si se accede desde una red externa o sin VPN):**
   Si la IP `10.33.195.185` no abre directamente en tu navegador, ejecuta en una terminal:
   ```bash
   ssh -i profesor_tas10.pem -L 3000:localhost:3000 profesor@10.33.195.185
   ```
   Luego abre en tu navegador local: **[http://localhost:3000/](http://localhost:3000/)** (e ingresa con `admin` / `tas10_grafana`).

3. **Ubicación del Dashboard Principal:**
   - En el menú lateral izquierdo de Grafana, haz clic en **Dashboards**.
   - Ingresa a la carpeta **Nodo Sur**.
   - Selecciona el dashboard: **`Nodo Sur · Grupo 10 · Salud General`** (enlace directo: `/d/nodo-sur-overview/`).
   - *(Recomendación para la demo: en la esquina superior derecha, cambia el intervalo de refresco de `Off` a `5s` o `10s` para ver las métricas actualizarse en vivo sin recargar la página).*

### ¿Cómo interpretar los Paneles 12 y 13?
Al final del dashboard se ubican los dos paneles de línea temporal de estado:

```
+-----------------------------------------------------------------------------------------+
| Panel 12: Historial de Disponibilidad y Caídas por Máquina (State Timeline)             |
+-----------------------------------------------------------------------------------------+
| ns1-borde   [=================================== VERDE ===============================] |
| cms1        [=================================== VERDE ===============================] |
| cms2        [======================== VERDE =============| ROJO |======= VERDE =======] |  <- Muestra caída pasada
| nfs-backup  [=================================== VERDE ===============================] |
| mariadb     [=================================== VERDE ===============================] |
+-----------------------------------------------------------------------------------------+
```

- **Métrica utilizada:** `up{job="hosts"}` para máquinas, `haproxy_server_status` para backends, `mysql_up` para MariaDB y `probe_success` para HTTPS.
- **Rango temporal ajustable:** En la esquina superior derecha de Grafana se puede seleccionar `Last 30 minutes`, `Last 6 hours` o `Last 24 hours` para auditar cualquier evento ocurrido durante el día o en las pruebas previas.
- **Anotaciones automáticas:** Cada vez que una alerta crítica se dispara, se traza una línea vertical roja con el detalle de la alerta sobre las gráficas de tráfico y latencia.

---

## 6. Checklist Rápido para el Día de la Defensa (15 Minutos)

1. **Minuto 0-3 (Etapa 1 y 2):**
   - Abrir `https://cms.tas10.local/` y `http://10.33.195.185:8404/`.
   - Mostrar resolución DNS con `dig @10.33.195.185 cms.tas10.local +short`.
   - Realizar una compra de prueba con usuario `cliente` (`tas_10`).
2. **Minuto 3-7 (Etapa 3 - Observabilidad y Caída):**
   - Abrir Grafana en `http://10.33.195.185:3000/`.
   - Ejecutar `./demo_caida_servicios.sh` y seleccionar opción 1 (detener MariaDB).
   - Mostrar cómo Grafana marca rojo y cómo recobra en verde.
3. **Minuto 7-11 (Etapa 4 - Respaldos y RTO):**
   - Ejecutar `./demo_comprobar_respaldos.sh`.
   - Mostrar la verificación de integridad SHA-256, la ausencia inicial de `wordpress_eval`, la restauración cronometrada (~3.79s) y la tabla de paridad de datos al 100%.
4. **Minuto 11-13 (Prueba de Ataque y Resiliencia):**
   - Ejecutar `./demo_ataque_k6.sh --rapido` mientras la comisión observa la gráfica de tráfico de HAProxy y CPU en Grafana absorbiendo la carga.
5. **Minuto 13-15 (Etapa 6 - Preguntas y Defensa Individual):**
   - Defender decisiones según el rol asignado en [RUNBOOK.md](RUNBOOK.md#etapa-6--reparto-sugerido-para-defensa-individual).
