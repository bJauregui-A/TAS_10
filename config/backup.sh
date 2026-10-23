#!/bin/bash
# Script de respaldos automatizados - Nodo Sur Grupo 10
# Ubicación en servidor: /backups/scripts/hacer_backup.sh
# Programado en crontab: todos los días a las 02:00 AM

set -e

FECHA=$(date +"%Y%m%d_%H%M%S")
DESTINO_DB="/backups/db"
DESTINO_FILES="/backups/wp_files"
LOG="/backups/logs/backup.log"

# Parámetros de conexión a la base de datos (puerto no estándar)
DB_HOST="10.33.199.85"
DB_PORT="7033"
DB_NAME="wordpress"
DB_USER="tas_cms"
# DB_PASS se lee desde archivo protegido de credenciales en el servidor

echo "=== INICIO BACKUP: $FECHA ===" >> "$LOG"

# 1. Respaldo de Base de Datos MariaDB comprimido al vuelo
echo "[$(date)] Respaldando Base de Datos..." >> "$LOG"
mariadb-dump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
  --single-transaction --quick "$DB_NAME" | gzip > "$DESTINO_DB/db_wordpress_$FECHA.sql.gz"

# 2. Respaldo de imágenes y archivos subidos (desde la carpeta local NFS)
echo "[$(date)] Respaldando archivos uploads..." >> "$LOG"
tar -czf "$DESTINO_FILES/uploads_$FECHA.tar.gz" -C /srv/nfs/wp-uploads .

# 3. Política de retención: Eliminar respaldos con más de 7 días de antigüedad
find /backups/db/ -type f -name "*.sql.gz" -mtime +7 -delete
find /backups/wp_files/ -type f -name "*.tar.gz" -mtime +7 -delete

echo "[$(date)] Backup completado con éxito." >> "$LOG"
echo "==============================" >> "$LOG"
