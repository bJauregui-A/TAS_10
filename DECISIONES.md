# Decisiones del proyecto

## Qué CMS usar

Comparamos tres opciones:

- **WordPress**: fácil de administrar, no necesita conocimientos técnicos avanzados, tiene el plugin WooCommerce ya hecho para vender productos, y "Multisitio" para que varios integrantes de Nodo Sur manejen su propio catálogo bajo un mismo dominio.
- **Drupal**: más potente y flexible, pero mucho más difícil de administrar para alguien sin experiencia técnica. No tiene un modo "multisitio" tan simple.
- **PrestaShop**: pensado solo para tiendas, no sirve bien para reservas ni para que varios integrantes tengan su propio "sub-sitio".

**Elegimos WordPress + WooCommerce** porque es lo más simple de operar para personas sin conocimientos técnicos, y porque cubre todo lo que pide el caso de negocio (catálogo, ventas, reservas, administración delegada por integrante).

## Cómo repartir los servidores

Comparamos dos formas de armar la arquitectura:

- **Todo en una sola máquina**: más simple de armar, pero si esa máquina se cae, se cae todo el negocio. No cumple con "mantener el servicio si falla un nodo".
- **Separar en varias máquinas** (borde con balanceador y DNS, dos CMS, base de datos, y servidor de respaldos): más trabajo de configurar, pero si un CMS se cae, el otro sigue funcionando, las imágenes quedan a salvo en el almacenamiento compartido y la base de datos queda protegida en su propia máquina.

**Elegimos separar en varias máquinas**, con dos CMS idénticos detrás de un balanceador de carga, porque es lo que pide el caso de negocio: que el sitio siga funcionando aunque falle un nodo.

## Qué máquinas quedan visibles desde internet

Comparamos dos formas de exponer los servicios:

- **Exponer cada máquina directamente**: más fácil de entender, pero cada máquina extra con IP pública es un punto más por donde alguien podría intentar entrar.
- **Exponer solo una máquina de borde (DNS + Balanceador + Bastión SSH)**: los dos CMS, la base de datos y el servidor de archivos quedan escondidos en una red privada, solo alcanzables desde adentro.

**Elegimos exponer solo la máquina de borde**, porque reduce la cantidad de máquinas atacables desde internet a una sola, facilitando su vigilancia y protección.

## Cómo sincronizar las imágenes entre los dos CMS

Comparamos dos formas de manejar las fotos subidas a WordPress:

- **Copiar archivos a mano o con tareas programadas**: si alguien sube un producto en el servidor 1, el servidor 2 tarda en tener la foto o pueden quedar desfasados.
- **Almacenamiento compartido por red (NFS)**: ambos servidores leen y escriben sobre la misma carpeta de red en tiempo real.

**Elegimos un servidor NFS compartido** para la carpeta `wp-content/uploads`, porque garantiza que cualquier imagen que suba una tienda aparezca de inmediato en ambos nodos sin desfase.

## Dónde ubicar los respaldos (Backups)

Comparamos dos opciones:

- **Guardar los respaldos en la misma máquina de la base de datos o en el balanceador**: si esa máquina falla o es vulnerada, se pierden los datos y los respaldos al mismo tiempo.
- **Servidor interno dedicado de almacenamiento y copias de seguridad**: una máquina aislada en la red privada que saca copias automáticas y guarda la retención.

**Elegimos una máquina dedicada en la red privada** para los respaldos y el NFS, protegiendo las copias de seguridad de cualquier acceso directo desde el exterior.

## Seguridad del acceso administrativo (SSH)

Comparamos dos formas de autenticación:

- **Contraseñas tradicionales**: vulnerables a ataques de fuerza bruta o filtraciones.
- **Llaves criptográficas (claves privadas/públicas) sin contraseña**: el servidor solo acepta conexiones que presenten una clave autorizada.

**Elegimos autenticación estricta por llaves**, deshabilitando por completo el inicio de sesión por contraseña en todo el proyecto.

## Estrategia de contenerización del borde (HAProxy y BIND9 en Docker)

Para la evolución a contenedores requerida en la Entrega 3:

- **Modo puente (`bridge`) con mapeo de puertos**: Docker crea su propia subred y reglas `iptables` de NAT. Esto tiene el riesgo de ocultar la IP de origen del cliente (dificultando auditorías y logs de acceso) y en Linux puede saltarse las políticas predeterminadas de `ufw`.
- **Modo red de host (`network_mode: host`)**: los contenedores de HAProxy y BIND9 se enlazan directamente a las interfaces de red de la máquina (WAN y LAN privada).

**Elegimos `network_mode: host`** para los servicios de borde porque preserva la IP real de los clientes en los logs de acceso web y DNS, permite que BIND9 escuche selectivamente en las interfaces requeridas y mantiene a `ufw` en total control del tráfico entrante. Además, **el bastión SSH se mantuvo en el sistema operativo host** para garantizar que la administración remota de la plataforma nunca dependa del estado del motor Docker.

## Por qué MariaDB y NFS se mantienen nativos

Comparamos dos opciones para la base de datos (`ubuntudb`) y el servidor de archivos/respaldos (`marcelovers`):

- **Migrar MariaDB y NFS a contenedores Docker**: unifica el formato de despliegue, pero exige instalar Docker en máquinas sin salida a internet, agrega capas extra de red/volúmenes sobre datos críticos y eleva el riesgo operativo durante la migración.
- **Mantener MariaDB y NFS nativos en sus propias VMs aisladas**: ambos servicios ya corren dedicados, sin interfaz WAN, con reglas mínimas de `ufw`, discos LVM directos y respaldos verificados.

**Elegimos mantener MariaDB y NFS nativos** porque ya cuentan con aislamiento completo a nivel de VM y red privada, priorizando estabilidad, simplicidad de respaldo/restauración y control estricto del firewall, mientras el borde (`ns1`) y la capa web (`CMS1` y `CMS2`) sí operan en contenedores reproducibles.

## Disponibilidad: balanceo, tolerancia a fallos, alta disponibilidad y SPOF

Es importante distinguir tres conceptos que la arquitectura cubre de forma distinta:

- **Balanceo de carga:** HAProxy reparte las visitas 50/50 (`roundrobin`) entre `CMS1` y `CMS2`.
- **Tolerancia a fallos en la capa web:** si uno de los dos servidores CMS cae o entra en mantenimiento, HAProxy lo retira automáticamente mediante health checks (`L7OK`) y el otro nodo mantiene el sitio operativo sin interrumpir al usuario.
- **Alta disponibilidad (HA) total:** implica que **ningún** componente crítico sea punto único de falla. Nuestra plataforma todavía no es HA completa porque mantiene tres puntos únicos de falla (SPOF) conocidos y aceptados dentro del alcance del curso:
  1. **El borde (`ns1`):** si cae la VM 244, se interrumpen HAProxy y DNS. *Evolución futura:* segundo nodo de borde con Keepalived (VIP flotante) y DNS secundario.
  2. **La base de datos (`ubuntudb`):** una sola instancia MariaDB atiende a ambos CMS. *Evolución futura:* replicación primario-réplica o clúster Galera; hoy el riesgo se mitiga con backups diarios automatizados y restauración probada (RTO ~4 s).
  3. **El servidor NFS (`marcelovers`):** un solo nodo sirve `wp-content/uploads`. *Evolución futura:* almacenamiento replicado (GlusterFS/Ceph u object storage S3).

## Observabilidad y sincronización horaria (NTP)

- **Monitoreo en stack separado en `ns1`:** desplegamos Prometheus, Grafana, Alertmanager, `blackbox_exporter` y `mysqld_exporter` en `/opt/nodo-sur-monitoreo/` (independiente del borde `/opt/nodo-sur-borde/`) para poder detener o actualizar la observabilidad sin afectar el tráfico web ni DNS. Las 5 VMs exponen métricas de sistema vía `node_exporter` (puerto `9100/tcp` abierto solo para `10.33.199.82`).
- **NTP interno en la red privada:** como `marcelovers` y `ubuntudb` no tienen salida a internet, se instaló `chrony` en `ns1` (restringido a `10.33.199.80/29` en `ufw`) para sincronizar la hora de todas las máquinas y asegurar correlación exacta de logs y alertas.

