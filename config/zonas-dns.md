# Resolución de nombres de dominio (DNS)

El proyecto cuenta con un servidor de nombres BIND9 autoritativo corriendo en la máquina de borde (`10.33.195.185`).

## Zona pública (`tas10.local`)

Es la zona que resuelven los clientes del laboratorio:

| Nombre FQDN | Dirección IP | Función |
|---|---|---|
| `ns1.tas10.local` | 10.33.195.185 | Servidor de nombres autoritativo |
| `cms.tas10.local` | 10.33.195.185 | Punto de entrada web (balanceador HAProxy con HTTPS) |

## Zona privada (`private.local`)

Es la zona interna utilizada entre las máquinas dentro de la red privada (`10.33.199.80/29`):

| Nombre FQDN | Dirección IP | Función |
|---|---|---|
| `ns1.private.local` | 10.33.199.82 | Interfaz privada del bastión / DNS |
| `cms.private.local` | 10.33.199.83 | Servidor CMS 1 |
| `db.private.local` | 10.33.199.85 | Servidor de base de datos MariaDB |
| `storage.private.local` | 10.33.199.84 | Servidor de almacenamiento NFS y respaldos |

## Funcionamiento del acceso

Al escribir `https://cms.tas10.local` en el navegador, el servidor DNS responde directamente con la IP del balanceador de carga (`10.33.195.185`), el cual recibe la petición por HTTPS en el puerto 443 y la despacha de forma transparente hacia uno de los dos CMS en la red privada.
