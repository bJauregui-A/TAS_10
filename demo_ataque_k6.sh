#!/usr/bin/env bash
# ==============================================================================
# DEMOSTRACIÓN EN VIVO: ATAQUE DE SATURACIÓN Y RESISTENCIA CON k6
# Proyecto Integrador Nodo Sur - TAS 2026 (Grupo 10)
# ==============================================================================
set -euo pipefail

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K6_SCRIPT="$SCRIPT_DIR/config/pruebas/k6-ataque-saturacion.js"

echo -e "${CIAN}${BOLD}================================================================================${NC}"
echo -e "${CIAN}${BOLD}       DEMOSTRACIÓN DE RESILIENCIA Y ATAQUE CON k6 - NODO SUR (GRUPO 10)       ${NC}"
echo -e "${CIAN}${BOLD}================================================================================${NC}"
echo -e "${AMARILLO}Objetivo:${NC} Clúster HAProxy + CMS1/CMS2 + MariaDB (${BOLD}https://10.33.195.185${NC})"
echo -e "${AMARILLO}Monitoreo en Vivo:${NC}"
echo -e "  * ${VERDE}Grafana:${NC}        ${BOLD}http://10.33.195.185:3000/${NC} (admin / tas10_grafana)"
echo -e "  * ${VERDE}HAProxy Stats:${NC}  ${BOLD}http://10.33.195.185:8404/${NC}"
echo -e "${CIAN}--------------------------------------------------------------------------------${NC}"

# Detectar k6
K6_BIN=""
if command -v k6 &>/dev/null; then
  K6_BIN="k6"
elif [ -x "$HOME/.local/bin/k6" ]; then
  K6_BIN="$HOME/.local/bin/k6"
elif [ -x "/usr/local/bin/k6" ]; then
  K6_BIN="/usr/local/bin/k6"
fi

if [ -z "$K6_BIN" ]; then
  echo -e "${ROJO}[ERROR] No se encontró el binario k6.${NC}"
  echo -e "Instálalo o ejecuta: docker run --rm -i grafana/k6 run - < $K6_SCRIPT"
  exit 1
fi

echo -e "${VERDE}[OK]${NC} Binario k6 detectado: $($K6_BIN version)"

# Consultar estado de Rate Limiting
ESTADO_RL="DESACTIVADO"
if grep -qE '^\s*http-request deny deny_status 429' "$SCRIPT_DIR/config/ns1-docker/haproxy/haproxy.cfg"; then
  ESTADO_RL="ACTIVADO"
fi

if [ "$ESTADO_RL" = "ACTIVADO" ]; then
  echo -e "${AMARILLO}[AVISO DE SEGURIDAD] Bloqueo por IP en HAProxy:${NC} ${VERDE}${BOLD}[ACTIVADO]${NC}"
  echo -e "${AMARILLO}  * Las peticiones que superen 120 req/10s serán frenadas en el borde con HTTP 429.${NC}"
  echo -e "${AMARILLO}  * Para probar saturación directa de CMS y BD, desactívalo antes con: ${BOLD}./toggle_rate_limiting.sh off${NC}"
else
  echo -e "${AMARILLO}[AVISO DE SEGURIDAD] Bloqueo por IP en HAProxy:${NC} ${AMARILLO}${BOLD}[DESACTIVADO / PERMISIVO]${NC}"
  echo -e "${AMARILLO}  * Todo el tráfico pasará directamente a los workers PHP y MariaDB sin límite.${NC}"
fi

# Selección de Modo
MODO="${1:-}"
if [ -z "$MODO" ]; then
  echo -e ""
  echo -e "${BOLD}Selecciona el escenario de ataque para la demostración:${NC}"
  echo -e "  ${CIAN}1)${NC} ${BOLD}Ataque Rápido para Defensa en Vivo${NC} (60s, hasta 120 VUs - ideal para mostrar frente al profesor)"
  echo -e "  ${CIAN}2)${NC} ${BOLD}Ataque Estándar de Saturación${NC} (105s, hasta 200 VUs)"
  echo -e "  ${CIAN}3)${NC} ${BOLD}Ataque Extremo / Búsqueda de Punto de Quiebre${NC} (145s, hasta 300 VUs)"
  echo ""
  read -rp "Ingresa una opción [1-3] (por defecto 1): " OPCION
  case "$OPCION" in
    2) MODO="estandar" ;;
    3) MODO="extremo" ;;
    *) MODO="rapido" ;;
  esac
else
  case "$MODO" in
    --estandar|estandar) MODO="estandar" ;;
    --extremo|extremo) MODO="extremo" ;;
    *) MODO="rapido" ;;
  esac
fi

echo ""
echo -e "${AZUL}${BOLD}>>> Iniciando ataque en modo: ${MODO^^} <<<${NC}"
echo -e "${AMARILLO}[CONSEJO] Observa en Grafana el panel 'Trafico HAProxy' y 'Uso de CPU' en tiempo real.${NC}"
echo ""

# Ejecución de k6
export MODO="$MODO"
export TARGET_URL="https://10.33.195.185"
export HOST_HEADER="cms.tas10.local"

"$K6_BIN" run "$K6_SCRIPT"
