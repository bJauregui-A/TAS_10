# Qué nombre resuelve a qué IP

## Zona pública (`tas10.local`)

| Nombre | IP |
|---|---|
| `ns1.tas10.local` | 10.33.195.185 |
| `cms.tas10.local` | 10.33.195.206 |

## Zona privada (`private.local`)

| Nombre | IP |
|---|---|
| `ns1.private.local` | 10.33.199.82 |
| `db.private.local` | 10.33.199.85 |
| `cms.private.local` | 10.33.199.83 |

## Algo que hay que corregir

`cms.tas10.local` todavía apunta directo a CMS1 (`10.33.195.206`), **no** al
balanceador de carga (`10.33.195.192`). Esto quiere decir que, si alguien escribe
`cms.tas10.local` en el navegador, hoy le llega directo a CMS1 y se salta el
balanceador por completo — si CMS1 se cae, el sitio no sigue funcionando aunque
CMS2 esté bien, porque nadie está llegando a CMS2.

Hay que cambiar ese registro para que `cms.tas10.local` apunte a
`10.33.195.192` (el balanceador), no a CMS1 directo.
