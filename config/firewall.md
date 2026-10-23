# Reglas de firewall del proyecto

A continuación se muestra el estado real y limpio de `ufw status numbered` verificado en las 5 máquinas del proyecto tras eliminar reglas redundantes o heredadas.

---

## 1. Borde / DNS / HAProxy / Bastión (10.33.195.185 / 10.33.199.82)

Es la única máquina con exposición hacia el laboratorio/internet:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 53                         ALLOW IN    Anywhere                  (DNS BIND9)
[ 2] 22/tcp                     ALLOW IN    10.30.248.0/24            (Admin USM)
[ 3] 22/tcp                     ALLOW IN    10.33.195.128/25          (Admin USM)
[ 4] 22/tcp                     ALLOW IN    10.33.21.0/24             (Admin USM)
[ 5] 22/tcp                     ALLOW IN    10.33.112.0/24            (Admin USM)
[ 6] 22                         ALLOW IN    10.33.96.0/19             (Admin USM)
[ 7] 80/tcp                     ALLOW IN    Anywhere                  (HTTP hacia balanceador)
[ 8] 8404/tcp                   ALLOW IN    10.30.248.0/24            (Panel stats HAProxy)
[ 9] 443/tcp                    ALLOW IN    Anywhere                  (HTTPS seguro)
[10] 22/tcp                     ALLOW IN    10.33.199.80/29           (Red privada del proyecto)
[11] 53 (v6)                    ALLOW IN    Anywhere (v6)
[12] 80/tcp (v6)                ALLOW IN    Anywhere (v6)
[13] 443/tcp (v6)               ALLOW IN    Anywhere (v6)
```

---

## 2. Servidor CMS 1 (10.33.199.83)

Nodo web principal:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 80/tcp                     ALLOW IN    10.33.199.82              (Solo desde el balanceador)
[ 2] 22/tcp                     ALLOW IN    10.30.248.0/24            (Admin USM)
[ 3] 22/tcp                     ALLOW IN    10.33.195.128/25          (Admin USM)
[ 4] 22/tcp                     ALLOW IN    10.33.21.0/24             (Admin USM)
[ 5] 22/tcp                     ALLOW IN    10.33.112.0/24            (Admin USM)
[ 6] 22/tcp                     ALLOW IN    10.33.96.0/19             (Admin USM)
[ 7] 22/tcp                     ALLOW IN    10.33.199.80/29           (Red privada del proyecto)
```

---

## 3. Servidor CMS 2 (10.33.199.86)

Réplica de WordPress:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    10.30.248.0/24            (Admin USM)
[ 2] 22/tcp                     ALLOW IN    10.33.195.128/25          (Admin USM)
[ 3] 22/tcp                     ALLOW IN    10.33.21.0/24             (Admin USM)
[ 4] 22/tcp                     ALLOW IN    10.33.112.0/24            (Admin USM)
[ 5] 22/tcp                     ALLOW IN    10.33.199.80/29           (Red privada del proyecto)
[ 6] 80/tcp                     ALLOW IN    10.33.199.82              (Solo desde el balanceador)
[ 7] 22/tcp                     ALLOW IN    10.33.96.0/19             (Admin USM)
```

---

## 4. Base de datos MariaDB (10.33.199.85)

Corre en la red privada sin salida a internet:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    10.33.199.80/29           (SSH desde la red privada)
[ 2] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.83              (CMS1)
[ 3] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.82              (Borde / ns1)
[ 4] 10.33.199.85 7033/tcp      ALLOW IN    10.33.199.86              (CMS2)
[ 5] 7033/tcp                   ALLOW IN    10.33.199.84              (Servidor de respaldos)
```

---

## 5. Servidor de Almacenamiento y Respaldos (10.33.199.84)

Aloja el servidor NFS de imágenes y los scripts de backup:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    10.33.199.80/29           (SSH desde la red privada)
[ 2] 2049/tcp                   ALLOW IN    10.33.199.83              (NFS imágenes CMS1)
[ 3] 2049/tcp                   ALLOW IN    10.33.199.86              (NFS imágenes CMS2)
```
