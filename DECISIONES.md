# Decisiones del proyecto

## Qué CMS usar

Comparamos tres opciones:

- **WordPress**: fácil de administrar, no necesita conocimientos técnicos avanzados,
  tiene el plugin WooCommerce ya hecho para vender productos, y "Multisitio" para
  que varios integrantes de Nodo Sur manejen su propio catálogo bajo un mismo
  dominio.
- **Drupal**: más potente y flexible, pero mucho más difícil de administrar para
  alguien sin experiencia técnica. No tiene un modo "multisitio" tan simple.
- **PrestaShop**: pensado solo para tiendas, no sirve bien para reservas ni para
  que varios integrantes tengan su propio "sub-sitio".

**Elegimos WordPress + WooCommerce** porque es lo más simple de operar para
personas sin conocimientos técnicos, y porque cubre todo lo que pide el caso de
negocio (catálogo, ventas, reservas, administración delegada por integrante).

## Cómo repartir los servidores

Comparamos dos formas de armar la arquitectura:

- **Todo en una sola máquina**: más simple de armar, pero si esa máquina se cae,
  se cae todo el negocio. No cumple con "mantener el servicio si falla un nodo".
- **Separar en varias máquinas** (balanceador, dos CMS, base de datos): más
  trabajo de configurar, pero si un CMS se cae, el otro sigue funcionando, y la
  base de datos queda protegida en su propia máquina.

**Elegimos separar en varias máquinas**, con dos CMS idénticos detrás de un
balanceador de carga, porque es lo que pide el caso de negocio: que el sitio siga
funcionando aunque falle un nodo.

## Qué máquinas quedan visibles desde internet

Comparamos dos formas de exponer los servicios:

- **Exponer cada máquina directamente**: más fácil de entender, pero cada máquina
  extra es un punto más por donde alguien podría intentar entrar.
- **Exponer solo el balanceador**: los dos CMS y la base de datos quedan
  escondidos en una red privada, solo alcanzables desde adentro.

**Elegimos exponer solo el balanceador**, porque reduce la cantidad de máquinas
atacables desde internet a una sola, y esa es la que mejor podemos vigilar y
proteger.
