# Prueba de Restauración y Medición de RPO / RTO

Evidencia de la prueba controlada de restauración de respaldos de **Nodo Sur (Grupo 10)** ejecutada el **23 de noviembre de 2026** sin afectar el entorno productivo.

---

## 1. Respaldos evaluados

Generados por `/backups/scripts/hacer_backup.sh` en el servidor de respaldos (`marcelovers`, `10.33.199.84`), con verificación de integridad (`gzip -t` y `tar -tzf`):

- **Base de datos:** `/backups/db/db_wordpress_20261123_213440.sql.gz` (`387 KB`, marca de tiempo `2026-11-23T21:34:40Z`)
- **Archivos subidos (NFS):** `/backups/wp_files/uploads_20261123_213440.tar.gz` (`26 KB`, marca de tiempo `2026-11-23T21:34:41Z`)
- **Programación automática (`cron`):** diario a las `02:00 AM` (`0 2 * * * /backups/scripts/hacer_backup.sh >> /backups/logs/cron.log 2>&1`), con retención de 7 días.

---

## 2. Procedimiento ejecutado (ambiente controlado)

1. En `ubuntudb` (`10.33.199.85`), se creó una base de datos temporal `wordpress_restore_test` sin modificar la base productiva `wordpress`.
2. Desde `marcelovers` (`10.33.199.84`), se restauró el volcado comprimido por red privada hacia `10.33.199.85:7033`:
   ```bash
   gunzip -c /backups/db/db_wordpress_20261123_213440.sql.gz \
     | mariadb -h 10.33.199.85 -P 7033 -u tas_cms -p wordpress_restore_test
   ```
3. En `marcelovers`, se extrajo el respaldo de medios en un directorio temporal `/tmp/restore_test_uploads`:
   ```bash
   tar -xzf /backups/wp_files/uploads_20261123_213440.tar.gz -C /tmp/restore_test_uploads
   ```
4. Se contrastó la integridad de datos y archivos contra producción y finalmente se eliminaron la base de prueba y el directorio temporal.

---

## 3. Tiempos medidos (RPO y RTO)

| Componente | Inicio (UTC) | Fin (UTC) | Duración medida |
|---|---|---|---|
| Restauración BD (`wordpress_restore_test` vía LAN) | `2026-11-23T21:44:15Z` | `2026-11-23T21:44:19Z` | **3.615 s** |
| Restauración medios (`uploads`) | `2026-11-23T21:44:19Z` | `2026-11-23T21:44:19Z` | **0.011 s** |
| **RTO técnico total (restauración de datos)** | `2026-11-23T21:44:15Z` | `2026-11-23T21:44:19Z` | **3.626 s** (~4 segundos) |

- **RPO efectivo de la prueba:** `9 min 35 s` (entre el respaldo `21:34:40Z` y la restauración `21:44:15Z`).
- **RPO operativo máximo (política actual):** **24 horas** (frecuencia diaria del cron a las 02:00 AM). Si se requiere menor RPO, basta aumentar la frecuencia del cron (por ejemplo, cada 6 horas).
- **RTO operativo estimado (incluyendo detección, acceso SSH y validación):** **< 5 minutos** (con restauración técnica real de **3.63 s**).

---

## 4. Validación de integridad

### Base de datos (producción vs. restaurada)

| Base de datos | Tablas | Posts (`wp_posts`) | Usuarios (`wp_users`) | Productos WooCommerce |
|---|---:|---:|---:|---:|
| `wordpress` (producción) | 67 | 36 | 3 | 2 |
| `wordpress_restore_test` (restaurada) | 67 | 36 | 3 | 2 |

### Archivos de medios (`uploads`)

- **Producción (`/srv/nfs/wp-uploads`):** 23 archivos (`240 KB`)
- **Restaurado (`/tmp/restore_test_uploads`):** 23 archivos
- **Comparación (`diff -rq`):** **0 diferencias** (archivos 100% idénticos).

---

## 5. Limpieza posterior

Tras confirmar la integridad:
- Se revocó el permiso temporal y se ejecutó `DROP DATABASE wordpress_restore_test;` en `ubuntudb`.
- Se eliminó `/tmp/restore_test_uploads` en `marcelovers`.
- La base productiva `wordpress` y el recurso NFS no sufrieron cortes ni modificaciones.
