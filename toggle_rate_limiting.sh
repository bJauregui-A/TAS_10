#!/usr/bin/env bash
# ==============================================================================
# INTERRUPTOR (TOGGLE) DE RATE LIMITING Y BLOQUEO POR IP EN HAPROXY
# Proyecto Integrador Nodo Sur - TAS 2026 (Grupo 10)
# ==============================================================================
# Permite activar o desactivar en caliente (0.2s, sin caída) el bloqueo por IP:
#   * ACTIVADO:  Bloquea con HTTP 429 a cualquier IP que supere 120 req/10s.
#   * DESACTIVADO: Modo permisivo para permitir que pruebas de estrés con k6
#                  lleguen directamente a los CMS y a MariaDB.
# ==============================================================================
set -euo pipefail

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_KEY="$SCRIPT_DIR/profesor_tas10.pem"
BASTION_IP="10.33.195.185"

if [ ! -f "$SSH_KEY" ]; then
  echo -e "${ROJO}[ERROR] No se encontró la llave SSH: $SSH_KEY${NC}"
  exit 1
fi
chmod 600 "$SSH_KEY"

run_borde() {
  local CMD="$1"
  ssh -F /dev/null -o StrictHostKeyChecking=no -i "$SSH_KEY" profesor@"$BASTION_IP" "$CMD"
}

get_status() {
  local RES
  RES=$(run_borde "grep -E '^\s*http-request deny deny_status 429' /opt/nodo-sur-borde/haproxy/haproxy.cfg || true")
  if [ -n "$RES" ]; then
    echo "ACTIVADO"
  else
    echo "DESACTIVADO"
  fi
}

ESTADO_ACTUAL=$(get_status)

echo -e "${CIAN}${BOLD}================================================================================${NC}"
echo -e "${CIAN}${BOLD}      INTERRUPTOR DE BLOQUEO POR IP (RATE LIMITING) - NODO SUR GRUPO 10        ${NC}"
echo -e "${CIAN}${BOLD}================================================================================${NC}"
if [ "$ESTADO_ACTUAL" = "ACTIVADO" ]; then
  echo -e "Estado Actual: ${VERDE}${BOLD}[ACTIVADO]${NC} (Protección perimetral activa: >120 req/10s $\to$ HTTP 429)"
else
  echo -e "Estado Actual: ${AMARILLO}${BOLD}[DESACTIVADO / PERMISIVO]${NC} (El tráfico pasa directo a los CMS)"
fi
echo -e "${CIAN}--------------------------------------------------------------------------------${NC}"

ACCION="${1:-}"

if [ -z "$ACCION" ]; then
  echo -e "\n${BOLD}Selecciona una opción:${NC}"
  echo -e "  ${CIAN}1)${NC} ${VERDE}${BOLD}ACTIVAR${NC} Bloqueo por IP (Protección anti-DDoS / Rate Limiting)"
  echo -e "  ${CIAN}2)${NC} ${AMARILLO}${BOLD}DESACTIVAR${NC} Bloqueo por IP (Modo permisivo para pruebas de saturación de CMS/BD)"
  echo -e "  ${CIAN}3)${NC} Consultar estadísticas de la tabla de IPs en HAProxy"
  echo -e "  ${CIAN}4)${NC} Salir"
  echo ""
  read -rp "Selecciona una opción [1-4]: " OPCION
  case "$OPCION" in
    1) ACCION="on" ;;
    2) ACCION="off" ;;
    3) ACCION="status" ;;
    *) echo "Operación cancelada."; exit 0 ;;
  esac
fi

case "$ACCION" in
  on|activar|enable)
    echo -e "\n${AZUL}${BOLD}>>> ACTIVANDO PROTECCIÓN POR RATE LIMITING EN HAPROXY... <<<${NC}"
    run_borde "echo tas_10 | sudo -S sed -i 's/^\s*#\s*\(http-request deny deny_status 429.*\)/\    \1/' /opt/nodo-sur-borde/haproxy/haproxy.cfg && docker kill -s HUP edge_haproxy"
    # Sincronizar local
    sed -i 's/^\s*#\s*\(http-request deny deny_status 429.*\)/\    \1/' "$SCRIPT_DIR/config/ns1-docker/haproxy/haproxy.cfg"
    sleep 1
    echo -e "${VERDE}${BOLD}[PROTECCIÓN ACTIVADA]${NC} HAProxy bloqueará con HTTP 429 cualquier IP que supere 120 req/10s."
    ;;

  off|desactivar|disable)
    echo -e "\n${AMARILLO}${BOLD}>>> DESACTIVANDO BLOQUEO POR IP (MODO PERMISIVO)... <<<${NC}"
    run_borde "echo tas_10 | sudo -S sed -i 's/^\s*\(http-request deny deny_status 429.*\)/# \1/' /opt/nodo-sur-borde/haproxy/haproxy.cfg && docker kill -s HUP edge_haproxy"
    # Sincronizar local
    sed -i 's/^\s*\(http-request deny deny_status 429.*\)/# \1/' "$SCRIPT_DIR/config/ns1-docker/haproxy/haproxy.cfg"
    sleep 1
    echo -e "${AMARILLO}${BOLD}[MODO PERMISIVO ACTIVADO]${NC} Todo el tráfico pasará sin límite de tasa a CMS1 y CMS2."
    ;;

  status|tabla)
    echo -e "\n${AZUL}${BOLD}>>> ESTADO Y TABLA DE IPs EN HAPROXY (STICK-TABLE): <<<${NC}"
    run_borde "curl -s http://127.0.0.1:8404/ | grep -A 5 'stick-table' || true"
    echo -e "\n${VERDE}Estado de regla:${NC} $(get_status)"
    ;;

  *)
    echo "Uso: $0 [on|off|status]"
    exit 1
    ;;
esac
