# Uso de IA en el proyecto

Se usó IA generativa principalmente para entender **por qué** ocurrían errores en consola o servicios caídos, facilitando el diagnóstico sin sustituir el criterio técnico. Cada uso real quedó registrado abajo con: herramienta, propósito, síntoma/fragmento, validación y cambio aplicado.

## 1. Errores de Mixed Content / CORS en la consola del navegador

- **Herramienta:** Claude (Claude Code).
- **Propósito:** entender por qué el sitio, teniendo HTTPS en el balanceador, arrojaba errores de CORS y contenido mixto en la consola del navegador.
- **Fragmento relevante:** `Access to script at 'http://cms.tas10.local/...' from origin 'https://cms.tas10.local' has been blocked by CORS policy`.
- **Validación realizada:** se revisó el archivo `wp-config.php` y se verificó que WordPress desconocía que la visita venía por HTTPS, pues el balanceador le habla por HTTP hacia adentro.
- **Cambio aplicado:** se añadió a `wp-config.php` la detección del encabezado `X-Forwarded-Proto: https` y se actualizó la URL en la base de datos a `https://`.

## 2. El balanceador marcó los dos servidores como caídos

- **Herramienta:** Claude (Claude Code).
- **Propósito:** diagnosticar por qué el balanceador marcaba ambos CMS caídos tras el cambio anterior.
- **Fragmento relevante:** estado `DOWN` en HAProxy con código `L7STS/302` (esperaba `200`).
- **Validación realizada:** se simuló a mano la consulta del balanceador y se observó que WordPress la redirigía a HTTPS en vez de devolver código 200 directo.
- **Cambio aplicado:** se ajustó la comprobación de salud en `haproxy.cfg` para que envíe el encabezado `X-Forwarded-Proto https`.

## 3. La base de datos rechazaba la conexión desde el segundo servidor

- **Herramienta:** Claude (Claude Code).
- **Propósito:** saber por qué el segundo CMS no lograba conectarse a MariaDB si tenía las mismas credenciales.
- **Fragmento relevante:** `Host '10.33.199.86' is not allowed to connect to this MariaDB server`.
- **Validación realizada:** se consultó la tabla de permisos en MariaDB y se constató que el usuario solo tenía permitida la IP del primer servidor.
- **Cambio aplicado:** se otorgaron permisos al mismo usuario desde la IP de CMS2 en MariaDB.

## 4. Análisis integral de la plataforma y contraste con la pauta de Entrega 2

- **Herramienta:** Antigravity.
- **Propósito:** auditar las máquinas en vivo para detectar desajustes de configuración, validar el cumplimiento de la rúbrica y proponer mejoras de seguridad.
- **Validación realizada:** se auditaron servicios, puertos y firewalls en las 5 VMs, aplicando solo los cambios necesarios y descartando opciones complejas.
- **Cambio aplicado:** consolidación del borde (HAProxy + DNS), limpieza de reglas huérfanas en los firewalls de CMS1, CMS2 y BD, y configuración de llaves para el usuario profesor.

## 5. Diagnóstico de CMS2 caído tras unificar el balanceador en el borde

- **Herramienta:** Antigravity.
- **Propósito:** determinar por qué CMS1 estaba activo en el nuevo HAProxy pero CMS2 figuraba caído por timeout.
- **Fragmento relevante:** `Failed to connect to 10.33.199.86 port 80: Timeout was reached`.
- **Validación realizada:** se inspeccionaron las reglas de `ufw` en CMS2 y se constató que solo aceptaba tráfico HTTP desde la IP del balanceador anterior (`10.33.199.84`).
- **Cambio aplicado:** se agregó la regla en el firewall de CMS2 para autorizar el puerto 80 desde la IP privada del nuevo borde (`10.33.199.82`).

## 6. Fallo de conexión en el script de respaldo hacia la base de datos

- **Herramienta:** Antigravity.
- **Propósito:** identificar la causa del fallo de `mariadb-dump` desde el servidor de respaldos.
- **Fragmento relevante:** `mariadb-dump: Got error: 2002: Can't connect to server on '10.33.199.85' (115)`.
- **Validación realizada:** se verificó el puerto 7033 en la base de datos y se confirmó que UFW y los privilegios de MariaDB no incluían la IP del servidor de respaldos (`10.33.199.84`).
- **Cambio aplicado:** se autorizó la IP en el firewall de MariaDB y se ejecutó un `GRANT` para esa dirección.

## 7. Error de montaje NFS en CMS2

- **Herramienta:** Antigravity.
- **Propósito:** interpretar el fallo del comando `mount` al conectar la carpeta de imágenes compartidas.
- **Fragmento relevante:** `mount: /var/www/html/wp-content/uploads: bad option; for several filesystems you might need a /sbin/mount.<type> helper program`.
- **Validación realizada:** se revisaron los paquetes instalados en CMS2 y se verificó la ausencia del cliente NFS.
- **Cambio aplicado:** se instaló el paquete `nfs-common` en el sistema.

## 8. Contenerización de servicios perimetrales en ns1 (Entrega 3)

- **Herramienta:** Antigravity.
- **Propósito:** diseñar e implementar la suite multicontenedor con Docker Compose para los servicios de borde (HAProxy y BIND9) manteniendo la seguridad perimetral y el bastión SSH en el host.
- **Fragmento relevante:** `[ALERT] (1) : Binding [/usr/local/etc/haproxy/haproxy.cfg:23] for frontend http_in: cannot bind socket (Permission denied) for [0.0.0.0:80]`.
- **Validación realizada:** se comprobó la sintaxis previa con `named-checkconf` y `haproxy -c`, y se analizó el requerimiento de capacidades Linux para enlace de puertos privileged en `network_mode: host`.
- **Cambio aplicado:** se instaló Docker en `ns1`, se estructuró `/opt/nodo-sur-borde/` con configuraciones montadas en modo solo lectura, se concedió `NET_BIND_SERVICE` a HAProxy y se crearon scripts de prueba y reversión.

## Nota

Ningún comando o configuración se aplicó a ciegas. Todas las contraseñas reales y credenciales se mantuvieron fuera de las consultas.
