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



## 13. Consultas DNS daban `REFUSED` desde la red de estudiantes/Eduroam (`10.33.96.0/19`)

**Qué pasó:** al intentar resolver nombres contra el DNS de borde (`10.33.195.185`) desde un equipo conectado a la red Eduroam, `dig` arrojaba `;; ->>HEADER<<- opcode: QUERY, status: REFUSED`.

**Por qué pasaba:** el ACL `trusted` en `/opt/nodo-sur-borde/bind9/named.conf.options` solo incluía `10.33.112.0/24` y tenía la red privada mal definida como `10.33.199.0/29` en lugar de `10.33.199.80/29`. La subred asignada por DHCP a los clientes en la universidad era `10.33.96.0/19` (fuera del ACL). Además, la zona `db.private.local` carecía de los registros `A` para `cms2` y `storage`.

**Cómo lo arreglamos:** se actualizó `named.conf.options` agregando `10.33.96.0/19`, `127.0.0.1` y corrigiendo la red privada a `10.33.199.80/29`. Se agregaron los registros de `cms1`, `cms2` y `storage` en `db.private.local` (serial 3) y se reinició el contenedor `edge_dns`.

**Cómo lo comprobamos:** se ejecutó `dig @10.33.195.185 cms.tas10.local +short` desde el cliente y resolvió inmediatamente `10.33.195.185` sin errores.

## 14. HAProxy marcaba los CMS como caídos por timeout de healthcheck con paquetes de idioma

**Qué pasó:** tras instalar y activar los paquetes de idioma español (`es_ES`) en WordPress y WooCommerce, HAProxy marcó intermitentemente a `cms1` y `cms2` como `DOWN` por `L7TOUT` (Layer 7 Timeout), generando errores 503 en el navegador.

**Por qué pasaba:** la carga y parseo en frío de los catálogos de traducción `.l10n` y `.mo` en PHP 8.3 durante la comprobación de `/wp-login.php` superaba el tiempo de espera por defecto de HAProxy (2 segundos).

**Cómo lo arreglamos:** se añadió `timeout check 10s` y se configuró el intervalo entre chequeos a 5 segundos (`check inter 5s cookie ...`) en `haproxy.cfg`.

**Cómo lo comprobamos:** HAProxy validó ambos backends como `UP (L7OK)` de forma permanente y las consultas web volvieron a responder con latencia menor a 350 ms.

## 15. Error "No hay métodos de pago disponibles" en la página de Checkout

**Qué pasó:** al intentar comprar un producto desde el carrito, la página de finalizar compra (`/checkout/`) no mostraba ninguna opción de pago y al presionar comprar arrojaba un error de *"No hay ningún método de pago disponible"*.

**Por qué pasaba:** confluían dos causas técnicas:
1. La opción `woocommerce_cod_settings` en la tabla `wp_options` se había editado manualmente mediante una consulta SQL directa con longitudes de string serializadas erróneas (`s:18:"Pago contra entrega"` cuando la cadena tiene 19 caracteres). PHP fallaba al des-serializar la opción (`unserialize() === false`), dejando la pasarela inoperativa.
2. La página de checkout utilizaba el bloque moderno de Gutenberg (`wp:woocommerce/checkout`), el cual requiere pasarelas compatibles con la API de React de WooCommerce; al no detectarlas en el frontend cliente, ocultaba los campos de pago.

**Cómo lo arreglamos:** se reconfiguraron las pasarelas mediante la API nativa de WordPress en PHP (`update_option('woocommerce_cod_settings', ...)`) habilitando Pago contra entrega y Transferencia bancaria directa. Asimismo, se migraron las páginas de Carrito (ID 12) y Checkout (ID 13) a los shortcodes estándar `[woocommerce_cart]` y `[woocommerce_checkout]`.

**Cómo lo comprobamos:** se ejecutó un flujo de compra completo simulando un cliente real, creándose exitosamente la Orden #43 por $25.000 con estado `wc-processing` en la tabla `wp_wc_orders`.

## 16. Desincronización de plugins en el contenedor de CMS1 (`cms_backend`)

**Qué pasó:** durante las pruebas se constató que la carpeta `/var/www/html/wp-content/plugins/woocommerce` no existía dentro del contenedor Docker `cms_backend` en CMS1, mientras que en CMS2 sí estaba presente.

**Por qué pasaba:** el archivo `compose.yaml` de CMS1 utilizaba un volumen con nombre (`wp_data:/var/www/html`), aislando el contenedor de los archivos reales que residían en el host en `/var/www/html/wp-content/plugins/`. Al recrear el contenedor, la imagen base solo inicializó los plugins por defecto.

**Cómo lo arreglamos:** se copiaron los directorios `woocommerce` y `woocommerce-mercadopago` desde el host hacia el contenedor `cms_backend` con permisos `www-data:www-data`, verificando su carga mediante CLI.

**Cómo lo comprobamos:** se verificó que `WC()` carga correctamente en ambos CMS y que ambos devuelven las pasarelas `cod` y `bacs` en estado activo (`is_available: YES`).

## 17. Actualización definitiva del Informe de Entrega Final y Rúbricas de Defensa

**Qué pasó:** el archivo `Informe_Entrega_Final_TAS_2026_Grupo10.docx` correspondía a un borrador preliminar de la Entrega 1 con diagramas y tablas desactualizadas (ej. balanceador en VM 220, CMS2 no implementado, ausencia de métricas k6 y de pruebas de restauración).

**Por qué pasaba:** la infraestructura evolucionó a un cluster distribuido final con balanceador en VM 185, dos nodos CMS en contenedores Docker, MariaDB dedicado en VM 85 y servidor de almacenamiento y backups en VM 84, pero el documento no había sido sincronizado tras las pruebas de carga y resiliencia.

**Cómo lo arreglamos:** se reescribió íntegramente el contenido del informe en formato `.docx` y se compiló a `.pdf` de 12 páginas, integrando:
1. Tabla de inventario real de 5 VMs y contenedores Docker.
2. Resultados empíricos de las pruebas de carga k6 (nominal y estrés con 0% tasa de fallo HTTP).
3. Métricas reales de resiliencia (RPO = 0s, RTO = 1.83s medido en restauración sobre `wordpress_eval`).
4. Matriz de riesgos operacionales, plan de contingencia y controles UFW implementados.
5. Sincronización de las 6 etapas de la defensa práctica descritas por el profesor para el viernes 27/11.

**Cómo lo comprobamos:** se validó la integridad estructural del documento con 8 tablas y 55 párrafos, y se generó la versión oficial en PDF (`Informe_Entrega_Final_TAS_2026_Grupo10.pdf`).

## 18. Instrumentación de Suite de Demostración: Ataque k6, State Timeline en Grafana y Verificación de Respaldos

**Qué pasó:** para la defensa práctica del viernes 27/11, se requería una batería de pruebas demostrables en vivo para evidenciar el límite de resistencia del clúster bajo ataque, registrar el historial de caídas de máquinas en Grafana y comprobar los respaldos con cálculo de RTO en tiempo real según la rúbrica docente.

**Por qué pasaba:** el dashboard de Grafana únicamente mostraba el número instantáneo de hosts y servicios (ej. `sum(up) = 5`), sin un panel temporal continuo (State Timeline) que permitiera auditar caídas pasadas o visualizarlas en vivo. Además, los respaldos y pruebas de carga carecían de scripts ejecutables interactivos con diagnóstico formateado.

**Cómo lo arreglamos:**
1. **Historial de Caídas en Grafana:** se incorporaron los paneles 12 y 13 (`state-timeline`) en `nodo-sur-overview.json` mapeando `up{job="hosts"}` (verde para UP, rojo para DOWN) y los servicios críticos (HAProxy backends, MariaDB y HTTPS), sincronizándolo en `/opt/nodo-sur-monitoreo/` en VM 185.
2. **Ataque k6 (`demo_ataque_k6.sh` y `k6-ataque-saturacion.js`):** se implementó un test de saturación agresivo con búsquedas dinámicas SQL y ordenamientos en WooCommerce para medir el límite de concurrencia de workers PHP/Apache (hasta 300 VUs).
3. **Comprobación de Respaldos (`demo_comprobar_respaldos.sh`):** se automatizó la Etapa 4 de la rúbrica, auditando `/backups/`, verificando compresión binaria (`gzip -t` / `tar -tzf`), demostrando la condición de base de datos ausente (`wordpress_eval`), restaurando en streaming LAN con medición cronometrada del RTO (3.79s) y validando la paridad al 100% de tablas y registros.
4. **Caídas Controladas (`demo_caida_servicios.sh`):** script interactivo para inyectar fallos de MariaDB (Etapa 3), failover de CMS1 y caída de node_exporter para observar el cambio inmediato a rojo en Grafana.

**Cómo lo comprobamos:** se ejecutó de extremo a extremo `./demo_comprobar_respaldos.sh --clean`, certificando un RTO real de 3.79s con 67 tablas y 6 usuarios idénticos a producción, y se probó la ejecución de k6 alcanzando 100% de éxito en peticiones.
