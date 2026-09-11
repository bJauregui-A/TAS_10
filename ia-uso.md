# Uso de IA en el proyecto

Se usó Claude (Anthropic, vía Claude Code) principalmente para entender **por qué**
pasaban errores que no sabíamos explicar, no para que resolviera el proyecto solo.
Cada uso real quedó registrado abajo: herramienta, para qué se usó, qué mostraba el
error, qué se comprobó y qué cambio se terminó aplicando.

## 1. Errores de Mixed Content / CORS en la consola del navegador

- **Herramienta:** Claude (Claude Code).
- **Propósito:** no sabíamos por qué el sitio, ya con HTTPS en el balanceador,
  tiraba errores de CORS y "Mixed Content" en la consola.
- **Fragmento relevante:** `Access to script at 'http://cms.tas10.local/...' from
  origin 'https://cms.tas10.local' has been blocked by CORS policy` y varios
  `Mixed Content: ... was loaded over HTTPS, but requested an insecure ...`.
- **Validación realizada:** se revisó el `wp-config.php` y se confirmó que
  WordPress no tenía forma de saber que la visita llegaba por HTTPS (el
  balanceador le habla por HTTP simple hacia adentro).
- **Cambio aplicado:** se agregó a `wp-config.php` una detección del header
  `X-Forwarded-Proto` que manda el balanceador, y se actualizó la URL del sitio en
  la base de datos de `http://` a `https://`.

## 2. El balanceador marcó los dos servidores como caídos

- **Herramienta:** Claude (Claude Code).
- **Propósito:** justo después del cambio anterior, el balanceador empezó a decir
  que ambos CMS estaban caídos, sin haber tocado nada de eso directamente.
- **Fragmento relevante:** estado `DOWN` en las estadísticas de HAProxy con
  `L7STS/302` (se esperaba `200`).
- **Validación realizada:** se probó a mano la misma revisión que hace el
  balanceador y se vio que WordPress la redirigía a `https://` en vez de
  responder directo.
- **Cambio aplicado:** se configuró la revisión del balanceador para que mande el
  mismo aviso (`X-Forwarded-Proto`) que manda una visita real.

## 3. La base de datos rechazaba la conexión desde el segundo servidor

- **Herramienta:** Claude (Claude Code).
- **Propósito:** al conectar el segundo CMS a la base de datos compartida, la
  conexión se rechazaba y no sabíamos por qué si las credenciales eran las mismas.
- **Fragmento relevante:** `Host '...' is not allowed to connect to this MariaDB
  server`.
- **Validación realizada:** se revisó el usuario de la base de datos y se vio que
  solo tenía permiso para conectarse desde la IP del primer servidor.
- **Cambio aplicado:** se agregó permiso para el mismo usuario desde la IP del
  segundo servidor, con la misma contraseña.

## Nota

Ningún comando ni configuración se aplicó sin revisar antes qué hacía. Las
credenciales y contraseñas nunca se compartieron con la IA como parte del
diagnóstico; solo se describieron los síntomas y errores.
