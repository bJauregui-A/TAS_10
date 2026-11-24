#!/usr/bin/env bash
# ==============================================================================
# DEMOSTRACIÓN EN VIVO: CAÍDAS CONTROLADAS Y RESILIENCIA VISIBLE EN GRAFANA
# Proyecto Integrador Nodo Sur - TAS 2026 (Grupo 10)
# ==============================================================================
# Cumple con la Etapa 3 de la rúbrica docente:
# "Observabilidad y caída controlada de BD / servicios, verificación de alertas
# y visualización del historial de caídas en el Timeline de Grafana"
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
DB_IP="10.33.199.85"
CMS1_IP="10.33.199.83"
CMS2_IP="10.33.199.86"

if [ ! -f "$SSH_KEY" ]; then
  echo -e "${ROJO}[ERROR] No se encontró la llave SSH: $SSH_KEY${NC}"
  exit 1
fi
chmod 600 "$SSH_KEY"

run_node() {
  local NODE_IP="$1"
  local CMD="$2"
  ssh -F /dev/null -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -F /dev/null -i $SSH_KEY -o StrictHostKeyChecking=no -W %h:%p profesor@$BASTION_IP" -i "$SSH_KEY" profesor@"$NODE_IP" "$CMD"
}

echo -e "${CIAN}${BOLD}================================================================================${NC}"
echo -e "${CIAN}${BOLD}     DEMOSTRACIÓN DE CAÍDAS CONTROLADAS Y RESILIENCIA - NODO SUR (GRUPO 10)     ${NC}"
echo -e "${CIAN}${BOLD}================================================================================${NC}"
echo -e "${AMARILLO}Abre Grafana en tu navegador para ver el State Timeline en tiempo real:${NC}"
echo -e "  * URL: ${BOLD}http://10.33.195.185:3000/${NC} (admin / tas10_grafana)"
echo -e "  * Panel 12: ${BOLD}Historial de Disponibilidad y Caídas por Máquina${NC}"
echo -e "  * Panel 13: ${BOLD}Historial de Estado de Servicios Críticos${NC}"
echo -e "${CIAN}--------------------------------------------------------------------------------${NC}"

echo -e "\n${BOLD}Selecciona la prueba de resiliencia a ejecutar:${NC}"
echo -e "  ${CIAN}1)${NC} ${BOLD}Caída controlada de MariaDB${NC} (Etapa 3 de la Rúbrica)"
echo -e "  ${CIAN}2)${NC} ${BOLD}Caída y Failover de Backend CMS1${NC} (Demuestra balanceo HAProxy sin corte)"
echo -e "  ${CIAN}3)${NC} ${BOLD}Caída de Host/Máquina Virtual${NC} (Demuestra detección en State Timeline)"
echo -e "  ${CIAN}4)${NC} ${BOLD}Activar / Desactivar Bloqueo por IP${NC} (Toggle Rate Limiting en HAProxy)"
echo -e "  ${CIAN}5)${NC} Salir"
echo ""

read -rp "Selecciona una opción [1-5]: " OPCION

case "$OPCION" in
  1)
    echo -e "\n${AZUL}${BOLD}>>> ETAPA 3: CAÍDA CONTROLADA DE MARIADB (10.33.199.85) <<<${NC}"
    echo -e "${AMARILLO}1. Deteniendo servicio mariadb en ubuntudb...${NC}"
    run_node "$DB_IP" "echo tas_10 | sudo -S systemctl stop mariadb"
    echo -e "${ROJO}${BOLD}[SERVICIO DETENIDO]${NC} MariaDB está fuera de línea."
    echo -e "${CIAN}>>> Observa en Grafana cómo el panel de MariaDB y el Timeline cambian a ROJO <<<${NC}"
    echo -e "${CIAN}>>> La tienda responderá con 'Error establishing a database connection' <<<${NC}"
    echo ""
    read -rp "Presiona [ENTER] para RESTAURAR el servicio MariaDB..."
    echo -e "${AMARILLO}2. Iniciando servicio mariadb...${NC}"
    run_node "$DB_IP" "echo tas_10 | sudo -S systemctl start mariadb"
    sleep 2
    ESTADO=$(run_node "$DB_IP" "systemctl is-active mariadb")
    if [ "$ESTADO" = "active" ]; then
      echo -e "${VERDE}${BOLD}[RECUPERACIÓN CONFIRMADA] MariaDB está ACTIVA y operativa nuevamente.${NC}"
      echo -e "${VERDE}El Timeline de Grafana volverá a pintar el bloque en VERDE.${NC}"
    else
      echo -e "${ROJO}[ERROR] No se pudo iniciar MariaDB.${NC}"
    fi
    ;;

  2)
    echo -e "\n${AZUL}${BOLD}>>> PRUEBA DE FAILOVER: CAÍDA DE CMS1 (10.33.199.83) <<<${NC}"
    echo -e "${AMARILLO}1. Deteniendo contenedor cms_backend en CMS1...${NC}"
    run_node "$CMS1_IP" "echo tas_10 | sudo -S docker stop cms_backend"
    echo -e "${ROJO}${BOLD}[CMS1 DETENIDO]${NC}"
    echo -e "${CIAN}>>> HAProxy detecta el nodo DOWN y deriva el 100% del tráfico a CMS2 sin interrumpir el sitio web. <<<${NC}"
    echo -e "${CIAN}>>> Verifica navegando a https://cms.tas10.local/ o mirando http://10.33.195.185:8404/ <<<${NC}"
    echo ""
    read -rp "Presiona [ENTER] para REINICIAR CMS1..."
    echo -e "${AMARILLO}2. Reiniciando contenedor en CMS1...${NC}"
    run_node "$CMS1_IP" "echo tas_10 | sudo -S docker start cms_backend"
    sleep 3
    echo -e "${VERDE}${BOLD}[CMS1 RESTAURADO] El clúster recuperó la redundancia activa.${NC}"
    ;;

  3)
    echo -e "\n${AZUL}${BOLD}>>> PRUEBA DE HOST DOWN: SIMULACIÓN DE MÁQUINA CAÍDA (CMS2 10.33.199.86) <<<${NC}"
    echo -e "${AMARILLO}1. Deteniendo node_exporter en CMS2...${NC}"
    run_node "$CMS2_IP" "echo tas_10 | sudo -S systemctl stop node_exporter"
    echo -e "${ROJO}${BOLD}[HOST DESCONECTADO] node_exporter detenido en CMS2.${NC}"
    echo -e "${CIAN}>>> En 30-45 segundos, Grafana mostrará la fila 'cms2' en ROJO en el State Timeline y 'Hosts Activos' bajará a 4. <<<${NC}"
    echo ""
    read -rp "Presiona [ENTER] para RESTAURAR el monitoreo de CMS2..."
    run_node "$CMS2_IP" "echo tas_10 | sudo -S systemctl start node_exporter"
    sleep 2
    echo -e "${VERDE}${BOLD}[HOST RESTAURADO] Monitoreo reactivado. El Timeline volverá a VERDE.${NC}"
    ;;

  4)
    "$SCRIPT_DIR/toggle_rate_limiting.sh"
    ;;

  *)
    echo -e "${AMARILLO}Operación cancelada.${NC}"
    ;;
esac
