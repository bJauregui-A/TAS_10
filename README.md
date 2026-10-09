# Nodo Sur · TAS 2026 · Grupo #10

Integrantes: 
  Marcelo Carrasco
  Benjamín Jáuregui
  Benjamín Reyes
Docente: José Antonio Arellano V.

## Estructura elegida para el proyecto

El proyecto se arma con cuatro piezas:

- **Un balanceador de carga** (HAProxy) que recibe todo el tráfico desde internet.
- **Dos servidores CMS idénticos** (CMS1 y CMS2), cada uno corriendo el mismo
  WordPress. El balanceador reparte las visitas entre ambos, y si uno se cae, el
  otro sigue atendiendo solo.
- **Una base de datos**, usada por los dos CMS a la vez, para que ambos muestren
  siempre la misma información.

Solo el balanceador es visible desde internet; el resto de las máquinas (los dos
CMS y la base de datos) solo se pueden alcanzar desde dentro de la red privada del
proyecto.

## WordPress

Ambos CMS corren WordPress + WooCommerce en modo Multisitio, con el mismo
`wp-config.php` (mismas claves y la misma base de datos), para que da lo mismo a
cuál de los dos llegue una visita: se ve exactamente el mismo sitio.

## SSH

El acceso administrativo a las máquinas es solo por llave (sin contraseña) y solo
desde las redes de administración autorizadas.

## Firewall

Cada máquina tiene su firewall configurado según su rol:

- El balanceador es el único con los puertos 80 y 443 abiertos a cualquiera.
- Los dos CMS solo aceptan tráfico en el puerto 80 si viene del balanceador.
- La base de datos solo acepta conexiones desde los dos CMS.
- El acceso SSH, en todas las máquinas, está restringido a las redes de
  administración.

## Estructura del repositorio

```
/
├── README.md
├── DECISIONES.md    # por qué elegimos cada cosa
├── bitacora.md       # problemas que encontramos y cómo los resolvimos
└── config/
    └── haproxy.cfg   # configuración real del balanceador (sin contraseñas)
```
