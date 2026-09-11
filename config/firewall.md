# Reglas de firewall — mis componentes (Base de datos y DNS)

Cada máquina usa `ufw` y solo deja pasar tráfico desde las máquinas que
realmente lo necesitan, nada abierto a cualquiera salvo lo estrictamente
necesario.

## Base de datos (10.33.199.85)

```
[ 1] 22/tcp                     ALLOW IN    10.33.199.80/29
[ 2] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.83   (CMS1)
[ 3] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.82   (ns1)
[ 4] 10.33.199.85 873/tcp       ALLOW IN    10.33.199.82   (ns1, respaldo/rsync)
[ 5] 10.33.199.85 873/tcp       ALLOW IN    10.33.199.83   (CMS1, respaldo/rsync)
[ 6] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.86   (CMS2)
```

- El puerto de MariaDB no es el estándar (no es el 3306), y solo lo pueden usar
  los dos servidores CMS.
- SSH solo se acepta desde la red privada del proyecto.
- El puerto 873 es para copias de respaldo (rsync) desde/hacia `ns1` y CMS1.

## DNS / bastión (ns1, 10.33.195.185)

```
[ 1] 53                         ALLOW IN    Anywhere
[ 2] 22/tcp                     ALLOW IN    10.30.248.0/24
[ 3] 22/tcp                     ALLOW IN    10.33.195.128/25
[ 4] 22/tcp                     ALLOW IN    10.33.199.0/29
[ 5] 22/tcp                     ALLOW IN    10.33.21.0/24
[ 6] 22/tcp                     ALLOW IN    10.33.112.0/24
[ 7] 53 (v6)                    ALLOW IN    Anywhere (v6)
```

- El puerto 53 (DNS) queda abierto a cualquiera: es el servidor de nombres del
  proyecto y debe poder responder consultas de cualquier cliente.
- El puerto 22 (SSH) originalmente estaba abierto a cualquiera; se corrigió para
  que solo se acepte desde las redes de administración, igual que en el resto de
  las máquinas del proyecto.
