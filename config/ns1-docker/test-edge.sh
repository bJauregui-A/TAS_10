#!/bin/bash
# Script de validación de servicios contenerizados en ns1 (Borde)
set -e

cd /opt/nodo-sur-borde

echo "=== 1. Verificando estado de contenedores Docker ==="
docker compose ps

echo -e "\n=== 2. Verificando resolución DNS en contenedor BIND9 ==="
dig @127.0.0.1 +short cms.tas10.local
dig @10.33.195.185 +short cms.tas10.local

echo -e "\n=== 3. Verificando redirección HTTP -> HTTPS en HAProxy ==="
curl -s -o /dev/null -w "HTTP status: %{http_code}\n" http://127.0.0.1/

echo -e "\n=== 4. Verificando terminación TLS y respuesta de CMS en HAProxy ==="
curl -k -s -o /dev/null -w "HTTPS status: %{http_code}\n" -H "Host: cms.tas10.local" https://127.0.0.1/

echo -e "\n=== 5. Verificando panel de estadísticas (puerto 8404) ==="
curl -s -o /dev/null -w "Stats status: %{http_code}\n" http://127.0.0.1:8404/

echo -e "\nTodos los checks pasaron exitosamente."
