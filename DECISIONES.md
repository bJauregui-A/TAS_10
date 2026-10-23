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
