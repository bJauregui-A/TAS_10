# Bitácora de incidentes

## 1. El sitio mezclaba HTTP y HTTPS (errores CORS en la consola)

**Qué pasó:** después de poner el certificado HTTPS en el balanceador, la página cargaba bien, pero el navegador tiraba errores de "Mixed Content" y CORS: algunas imágenes, estilos y scripts se pedían por `http://` en vez de `https://`.

**Por qué pasaba:** el balanceador recibe la visita por HTTPS, pero le habla a WordPress por HTTP normal (así está pensado). WordPress no tenía forma de saber que, para el visitante, la conexión sí era segura, así que seguía generando enlaces con `http://`.

**Cómo lo arreglamos:** le agregamos a WordPress una regla que revisa un aviso que manda el balanceador (`X-Forwarded-Proto: https`) y, si lo ve, WordPress asume que la visita es segura y genera todos los enlaces con `https://`.

**Cómo lo comprobamos:** volvimos a cargar el sitio y ya no quedó ninguna referencia a `http://` en la página.

## 2. Después de arreglar lo anterior, el balanceador marcó los dos CMS como caídos

**Qué pasó:** justo después del arreglo de arriba, el balanceador empezó a decir que ambos servidores CMS estaban caídos, aunque el sitio funcionaba bien si uno entraba directo.

**Por qué pasaba:** el balanceador revisa cada cierto tiempo si el CMS sigue vivo, pero esa revisión no llevaba el mismo aviso (`X-Forwarded-Proto`) que sí lleva una visita real. WordPress, al no ver ese aviso, redirigía la revisión hacia `https://`, y el balanceador esperaba una respuesta directa, no una redirección — por eso lo marcaba como caído.

**Cómo lo arreglamos:** hicimos que la revisión del balanceador también mande ese mismo aviso, igual que una visita real.

**Cómo lo comprobamos:** el balanceador volvió a marcar los dos CMS como funcionando, y el sitio siguió respondiendo bien.

## 3. Al mover el balanceador al nuevo borde, CMS2 aparecía caído

**Qué pasó:** al instalar HAProxy en la máquina de borde (`ns1`), el panel de estadísticas mostraba que CMS1 estaba activo (verde), pero CMS2 aparecía caído (rojo).

**Por qué pasaba:** el firewall (`ufw`) de CMS2 estaba configurado para recibir conexiones solo desde la IP privada del balanceador anterior, por lo que bloqueaba las consultas que le enviaba el nuevo balanceador.

**Cómo lo arreglamos:** agregamos una regla en el firewall de CMS2 permitiendo el tráfico web en el puerto 80 desde la IP privada del nuevo borde (`10.33.199.82`).

**Cómo lo comprobamos:** revisamos el panel de HAProxy y CMS2 pasó inmediatamente a estado `UP` (verde), respondiendo las solicitudes de balanceo.

## 4. El script de respaldos no podía conectarse a la base de datos

**Qué pasó:** al ejecutar la primera prueba del script de backup desde la máquina de almacenamiento, arrojaba un error de conexión `Can't connect to server on '10.33.199.85' (115)`.

**Por qué pasaba:** por seguridad, el firewall de la base de datos y los permisos del usuario de MariaDB solo permitían conexiones desde los dos servidores CMS, bloqueando los intentos que venían desde la máquina de respaldos (`10.33.199.84`).

**Cómo lo arreglamos:** abrimos el puerto de la base de datos en el firewall para la IP de la máquina de respaldos y le otorgamos permisos en MariaDB al usuario de la base de datos desde esa dirección.

**Cómo lo comprobamos:** volvimos a ejecutar el script y generó sin problemas el archivo comprimido con la copia completa de la base de datos (379 KB).

## 5. Error al montar la carpeta compartida NFS en CMS2

**Qué pasó:** al intentar montar la carpeta compartida de imágenes en CMS2, el sistema devolvió un error de `bad option; for several filesystems you might need a mount helper program`.

**Por qué pasaba:** el sistema operativo no tenía instalado el programa auxiliar para entender y montar unidades de red NFS (`nfs-common`).

**Cómo lo arreglamos:** instalamos el paquete `nfs-common` mediante `apt` y recargamos la configuración del sistema.

**Cómo lo comprobamos:** volvimos a ejecutar el comando de montaje y la carpeta `/var/www/html/wp-content/uploads` se conectó de inmediato, mostrando todas las imágenes existentes.

## 6. El navegador no abría la página tras mover el balanceador

**Qué pasó:** después de terminar la configuración, al intentar entrar a `https://cms.tas10.local` desde el navegador, la página se quedaba cargando hasta dar error de tiempo de espera agotado.

**Por qué pasaba:** el computador personal tenía guardada en su archivo local `/etc/hosts` la dirección IP del balanceador viejo, por lo que el navegador intentaba conectarse a una máquina que ya no recibía tráfico web.

**Cómo lo arreglamos:** actualizamos la línea de `cms.tas10.local` en `/etc/hosts` apuntando a la nueva IP del borde (`10.33.195.185`).

**Cómo lo comprobamos:** recargamos el navegador y la página de WordPress y la tienda cargaron de inmediato por HTTPS.

## 7. Contenedor de HAProxy no podía enlazar puertos 80 y 443 al dockerizar el borde

**Qué pasó:** al iniciar el stack Docker Compose en `ns1`, el contenedor `edge_haproxy` entraba en bucle de reinicios indicando `cannot bind socket (Permission denied) for [0.0.0.0:80]` y `[0.0.0.0:443]`.

**Por qué pasaba:** en Linux los puertos inferiores a 1024 son privilegiados. Al usar `network_mode: host`, la imagen oficial de HAProxy arrancaba directamente con el usuario desprivilegiado `haproxy` (UID 99) sin la capacidad del kernel para enlazar puertos bajos del host.

**Cómo lo arreglamos:** se configuró en `docker-compose.yml` la ejecución inicial como `user: root` otorgando las capacidades `NET_BIND_SERVICE` y `SYS_CHROOT`, permitiendo a HAProxy abrir los sockets 80 y 443 y luego realizar el cambio interno seguro a su usuario `haproxy` definido en `haproxy.cfg`.

**Cómo lo comprobamos:** el contenedor inició en estado saludable (`Up`), respondiendo con código 301 en HTTP, código 200 en HTTPS y sirviendo el panel de estadísticas en el puerto 8404.

## 8. La tienda mostraba aviso de 'Próximamente' y los productos daban error 404

**Qué pasó:** al ingresar a la tienda (`/shop/`) aparecía el mensaje *"Great things are on the horizon. Something big is brewing! Our store is in the works and will be launching soon!"*, y al intentar ver un producto individual (`/product/pintura/`) el servidor devolvía un error HTTP 404 Not Found.

**Por qué pasaba:** por un lado, WooCommerce activa por defecto el modo *Coming Soon* (`woocommerce_coming_soon = yes`), bloqueando el acceso al catálogo público a usuarios no autenticados. Por otro lado, las reglas de reescritura de WordPress no se habían regenerado para los tipos de contenido personalizados (*custom post types*) de WooCommerce tras habilitar el modo multisitio.

**Cómo lo arreglamos:** mediante WP-CLI se cambiaron las opciones `woocommerce_coming_soon` y `woocommerce_store_pages_only` a `no`, se regeneraron las reglas de reescritura con `wp rewrite flush` en ambos servidores CMS y se habilitó la pasarela de pago contra entrega (`cod`) para permitir pedidos de prueba.

**Cómo lo comprobamos:** recargamos la página `/shop/` desde un navegador en modo incógnito; la tienda cargó con su catálogo y la página del producto `/product/pintura/` respondió inmediatamente con código HTTP 200 OK.

## 9. Los respaldos automáticos no estaban corriendo y el script tenía errores silenciosos

**Qué pasó:** al auditar el servidor de respaldos (`marcelovers`), no había ningún respaldo nuevo desde el 23 de octubre y existían archivos de base de datos vacíos (`0–20 bytes`) junto a mensajes de éxito en el log.

**Por qué pasaba:** nunca se había registrado el `crontab` de `root`. Además, `/backups/scripts/hacer_backup.sh` tenía un error de escritura en la primera línea (`#/!bin/bash` en vez de `#!/bin/bash`) y no usaba `set -o pipefail`, por lo que un error de `mariadb-dump` antes del pipe a `gzip` quedaba oculto.

**Cómo lo arreglamos:** corregimos el shebang, agregamos `set -euo pipefail`, `PATH` explícito, validación de integridad (`gzip -t` y `tar -tzf`), restringimos permisos a `700`, limpiamos los archivos vacíos y programamos el cron diario a las 02:00 AM.

**Cómo lo comprobamos:** ejecutamos el script manualmente y luego realizamos una prueba controlada de restauración en una base temporal (`wordpress_restore_test`), validando 100% de integridad (67 tablas, 23 archivos) con un RTO técnico de 3.63 segundos (ver `config/restauracion-rpo-rto.md`).

## 10. Reglas de firewall abiertas de más en CMS1 y panel de estadísticas en `ns1`

**Qué pasó:** en la auditoría en vivo de `ufw`, CMS1 tenía los puertos `80` y `443` abiertos a `Anywhere`, y `ns1` tenía el puerto `8404` (estadísticas HAProxy) abierto a `Anywhere` con reglas duplicadas.

**Por qué pasaba:** quedaron reglas residuales de pruebas anteriores que no se habían retirado tras consolidar el balanceador.

**Cómo lo arreglamos:** eliminamos las reglas `Anywhere` de los puertos `80` y `443` en CMS1 (dejando solo `80/tcp` desde `10.33.199.82`) y restringimos el puerto `8404/tcp` en `ns1` únicamente a las redes de administración USM y la red privada del proyecto.

**Cómo lo comprobamos:** revisamos `ufw status numbered` en ambos equipos y confirmamos que HAProxy seguía viendo ambos CMS en estado `UP` y sirviendo `HTTP/2 200` por HTTPS.

## 11. Hora desincronizada en las máquinas privadas sin salida a internet

**Qué pasó:** `marcelovers` y `ubuntudb` mostraban `System clock synchronized: no`, con desfases de `+5.98 s` y `-34.35 s` respectivamente, lo que impedía correlacionar logs y eventos con precisión.

**Por qué pasaba:** ambas VMs están aisladas sin interfaz WAN y el gateway de la red privada no tiene salida a internet, por lo que `systemd-timesyncd` no alcanzaba servidores NTP externos.

**Cómo lo arreglamos:** instalamos `chrony` en `ns1` (`10.33.199.82`) como servidor NTP interno restringido a `10.33.199.80/29` (puerto `123/udp` en `ufw`), y apuntamos `systemd-timesyncd` de `marcelovers` y `ubuntudb` hacia `10.33.199.82`.

**Cómo lo comprobamos:** ejecutamos `timedatectl status` y `timedatectl timesync-status` en ambas VMs, confirmando `System clock synchronized: yes` contra `10.33.199.82`.

## 12. Error HTTP 500 en CMS1 por signo `$` sin escapar en `compose.yaml`

**Qué pasó:** tras corregir el montaje NFS en el contenedor de CMS1, HAProxy marcó `cms1` como `DOWN (L7STS)` y todas las visitas pasaron automáticamente a `cms2`.

**Por qué pasaba:** al descomentar `WORDPRESS_CONFIG_EXTRA` en `compose.yaml`, Docker Compose interpretó `$_SERVER` como una variable de entorno vacía, inyectando código PHP inválido en `wp-config.php` (`PHP Fatal error: Cannot use isset() on the result of an expression`).

**Cómo lo diagnosticamos:** consultamos el estado de HAProxy (`L7STS`), verificamos `HTTP 500` con `curl` y leímos el error exacto en `docker logs cms_backend`; además la alerta `BackendCMSCaido` se disparó en Prometheus/Grafana confirmando el monitoreo en vivo. La corrección consiste en escapar el símbolo como `$$_SERVER` en `compose.yaml`.


