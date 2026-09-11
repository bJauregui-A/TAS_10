# Bitácora de incidentes

## El sitio mezclaba HTTP y HTTPS (errores CORS en la consola)

**Qué pasó:** después de poner el certificado HTTPS en el balanceador, la página
cargaba bien, pero el navegador tiraba errores de "Mixed Content" y CORS: algunas
imágenes, estilos y scripts se pedían por `http://` en vez de `https://`.

**Por qué pasaba:** el balanceador recibe la visita por HTTPS, pero le habla a
WordPress por HTTP normal (así está pensado). WordPress no tenía forma de saber
que, para el visitante, la conexión sí era segura, así que seguía generando
enlaces con `http://`.

**Cómo lo arreglamos:** le agregamos a WordPress una regla que revisa un aviso que
manda el balanceador (`X-Forwarded-Proto: https`) y, si lo ve, WordPress asume que
la visita es segura y genera todos los enlaces con `https://`.

**Cómo lo comprobamos:** volvimos a cargar el sitio y ya no quedó ninguna
referencia a `http://` en la página.

## Después de arreglar lo anterior, el balanceador marcó los dos CMS como caídos

**Qué pasó:** justo después del arreglo de arriba, el balanceador empezó a decir
que ambos servidores CMS estaban caídos, aunque el sitio funcionaba bien si uno
entraba directo.

**Por qué pasaba:** el balanceador revisa cada cierto tiempo si el CMS sigue vivo,
pero esa revisión no llevaba el mismo aviso (`X-Forwarded-Proto`) que sí lleva una
visita real. WordPress, al no ver ese aviso, redirigía la revisión hacia
`https://`, y el balanceador esperaba una respuesta directa, no una redirección —
por eso lo marcaba como caído.

**Cómo lo arreglamos:** hicimos que la revisión del balanceador también mande ese
mismo aviso, igual que una visita real.

**Cómo lo comprobamos:** el balanceador volvió a marcar los dos CMS como
funcionando, y el sitio siguió respondiendo bien.

