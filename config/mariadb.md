# Configuración real de la base de datos

- **Puerto:** `7033` (no el 3306 normal de MariaDB, para que sea menos obvio de
  encontrar).
- **Escucha solo en:** `10.33.199.85` (la IP privada, no acepta conexiones desde
  otra dirección).
- **Quién se puede conectar:** solo el usuario de la aplicación, y solo desde las
  IP de CMS1 y CMS2 (cada IP tiene su propio permiso guardado, no es un permiso
  general).

**En palabras simples:** la base de datos no tiene ninguna forma de ser
alcanzada desde internet. Solo los dos servidores CMS pueden hablarle, y solo con
un usuario que tiene permiso limitado (no puede tocar otras bases de datos).
