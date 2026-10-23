# Nodo Sur · TAS 2026 · Grupo #10

## Integrantes: 
  - **Marcelo Carrasco**
  - **Benjamín Jáuregui**
  - **Benjamín Reyes**

**Docente: José Antonio Arellano V.**

## Estructura elegida para el proyecto

El proyecto se compone de cinco piezas organizadas por funciones:

- **Un borde de red (Proxy + DNS + Bastión SSH)**: Una sola máquina que da la cara hacia internet/laboratorio. Recibe todo el tráfico web con HAProxy (puertos 80 y 443 con HTTPS), responde las consultas de nombres con BIND9 (puerto 53) y sirve de puerta de entrada segura por SSH para administrar el resto de los equipos.
- **Dos servidores CMS idénticos (CMS1 y CMS2)**: Cada uno corre el mismo WordPress. El balanceador reparte las visitas entre ambos de forma alternada (50% y 50%). Si uno de ellos se apaga o falla, el otro sigue respondiendo sin que el usuario lo note.
- **Un servidor de almacenamiento y respaldos (NFS + Backup)**: Guarda en un solo lugar todas las fotos y archivos que suben los usuarios (vía NFS), para que ambos CMS muestren siempre las mismas imágenes. Además, tiene un script automático que todos los días a las 02:00 AM saca copia de seguridad de la base de datos y de las imágenes.
- **Una base de datos (MariaDB)**: Corre en su propia máquina aislada, protegida de internet. Atiende a los dos CMS al mismo tiempo para que los catálogos, carritos y pedidos sean exactamente los mismos.

Solo la máquina de borde es visible desde la red del laboratorio; el resto de las máquinas (los dos CMS, el servidor NFS/backups y la base de datos) viven dentro de la red privada del proyecto.

## WordPress y Almacenamiento

- Ambos CMS corren WordPress + WooCommerce en modo Multisitio con la misma base de datos.
- La carpeta `wp-content/uploads` de ambos servidores está montada en red contra el servidor NFS, de modo que cualquier imagen que suba una tienda aparece al instante en ambos nodos.

## SSH y Seguridad

- El acceso administrativo a todas las máquinas es únicamente mediante llaves criptográficas (las contraseñas por SSH están completamente deshabilitadas).
- Se configuró una llave dedicada para la revisión docente (`profesor_tas10.pem`), permitiendo acceso y privilegios de administración al usuario `profesor`.
- Para entrar a las máquinas privadas se salta a través del bastión con `ssh -J`.

## Firewall

Cada máquina tiene su firewall (`ufw`) cerrado al mínimo necesario:

- El borde es el único con los puertos 53 (DNS), 80 (HTTP) y 443 (HTTPS) abiertos a la red.
- Los dos CMS solo aceptan visitas en el puerto 80 si vienen de la IP del balanceador.
- El servidor NFS solo permite compartir archivos en el puerto 2049 a los dos CMS.
- La base de datos solo acepta conexiones en su puerto a los dos CMS y al servidor de backups.
- El acceso SSH está limitado a las redes de administración autorizadas.

## Estructura del repositorio

```
/
├── README.md
├── INVENTARIO.md          # lista de máquinas virtuales, IPs y funciones
├── DECISIONES.md          # por qué elegimos cada solución
├── bitacora.md             # problemas encontrados y cómo los resolvimos
├── CONTRIBUCIONES.md       # quién hizo cada parte
├── ia-uso.md               # registro de uso responsable de IA
└── config/
    ├── haproxy.cfg         # configuración del balanceador de carga
    ├── backup.sh           # script automatizado de respaldos
    ├── firewall.md         # reglas de firewall de todas las máquinas
    ├── zonas-dns.md        # nombres y direcciones IP
    ├── bind9.conf          # configuración del servidor de nombres
    └── mariadb.md          # configuración de la base de datos
```
