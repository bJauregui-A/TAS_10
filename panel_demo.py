#!/usr/bin/env python3
"""
Panel Interactivo de Pruebas y Demostración en Vivo · Nodo Sur (Grupo 10)
Solo usa la biblioteca estándar de Python 3.
"""

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
SSH_KEY = BASE_DIR / "profesor_tas10.pem"
K6_SCRIPT = BASE_DIR / "config" / "pruebas" / "k6-ataque-saturacion.js"
BACKUP_SCRIPT = BASE_DIR / "demo_comprobar_respaldos.sh"

BASTION_IP = "10.33.195.185"
SUDO_PASS = "tas_10"

NODES = {
    "ns1": {"name": "ns1 (Borde / HAProxy / DNS / Monitoreo)", "ip": "10.33.195.185", "jump": False},
    "cms1": {"name": "CMS 1 (benserver · cms_backend)", "ip": "10.33.199.83", "jump": True},
    "cms2": {"name": "CMS 2 (tascms2 · nodo_cms2)", "ip": "10.33.199.86", "jump": True},
    "nfs": {"name": "NFS y Respaldos (marcelovers)", "ip": "10.33.199.84", "jump": True},
    "db": {"name": "Base de Datos MariaDB (ubuntudb)", "ip": "10.33.199.85", "jump": True},
}

# Colores ANSI
R = "\033[0;31m"
G = "\033[0;32m"
Y = "\033[1;33m"
B = "\033[0;34m"
C = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"


def banner(titulo: str) -> None:
    print(f"\n{C}{BOLD}{'=' * 76}{NC}")
    print(f"{C}{BOLD}  {titulo}{NC}")
    print(f"{C}{BOLD}{'=' * 76}{NC}")


def pause() -> None:
    input(f"\n{DIM}Presiona Enter para volver al menú...{NC}")


def ensure_key() -> None:
    if not SSH_KEY.exists():
        print(f"{R}[ERROR] No se encontró la llave SSH: {SSH_KEY}{NC}")
        sys.exit(1)
    os.chmod(SSH_KEY, 0o600)


def ssh_cmd(node_key: str, remote_cmd: str | None = None) -> list[str]:
    node = NODES[node_key]
    cmd = [
        "ssh",
        "-F", "/dev/null",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=6",
        "-i", str(SSH_KEY),
    ]
    if node["jump"]:
        proxy = (
            f"ssh -F /dev/null -i {SSH_KEY} "
            f"-o StrictHostKeyChecking=no -W %h:%p profesor@{BASTION_IP}"
        )
        cmd += ["-o", f"ProxyCommand={proxy}"]
    cmd.append(f"profesor@{node['ip']}")
    if remote_cmd is not None:
        cmd.append(remote_cmd)
    return cmd


def run_remote(node_key: str, remote_cmd: str, capture: bool = False) -> subprocess.CompletedProcess:
    cmd = ssh_cmd(node_key, remote_cmd)
    if capture:
        return subprocess.run(cmd, text=True, capture_output=True)
    return subprocess.run(cmd)


def sudo_wrap(cmd: str) -> str:
    return f"echo {SUDO_PASS} | sudo -S bash -c {subprocess.list2cmdline([cmd])}"


def get_rate_limit_status() -> str:
    res = run_remote(
        "ns1",
        sudo_wrap("docker exec edge_haproxy grep -E '^\\s*http-request deny deny_status 429' /usr/local/etc/haproxy/haproxy.cfg || true"),
        capture=True,
    )
    if res.returncode != 0:
        return "DESCONOCIDO"
    return "ACTIVADO" if res.stdout.strip() else "DESACTIVADO"


def find_k6() -> str | None:
    for candidate in (shutil.which("k6"), str(Path.home() / ".local/bin/k6"), "/usr/local/bin/k6"):
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


# ==============================================================================
# ACCIONES DEL MENÚ
# ==============================================================================

def action_rate_limiting() -> None:
    while True:
        estado = get_rate_limit_status()
        color = G if estado == "ACTIVADO" else Y
        banner(f"1. BLOQUEO POR IP EN HAPROXY (Actual: {estado})")
        print(f"  Estado en edge_haproxy: {color}{BOLD}{estado}{NC}\n")
        print(f"  {C}1){NC} {G}ACTIVAR{NC} bloqueo por IP (>120 req/10s -> HTTP 429)")
        print(f"  {C}2){NC} {Y}DESACTIVAR{NC} bloqueo por IP (modo permisivo para atacar CMS/BD)")
        print(f"  {C}3){NC} Ver regla actual dentro de edge_haproxy")
        print(f"  {C}0){NC} Volver")
        op = input("\nElige una opción: ").strip()

        if op == "1":
            run_remote(
                "ns1",
                sudo_wrap(
                    "sed -i 's/^\\s*#\\s*\\(http-request deny deny_status 429.*\\)/    \\1/' /opt/nodo-sur-borde/haproxy/haproxy.cfg "
                    "&& docker restart edge_haproxy"
                ),
            )
            print(f"{G}[OK] Bloqueo por IP ACTIVADO y edge_haproxy reiniciado.{NC}")
            pause()
        elif op == "2":
            run_remote(
                "ns1",
                sudo_wrap(
                    "sed -i 's/^\\s*\\(http-request deny deny_status 429.*\\)/# \\1/' /opt/nodo-sur-borde/haproxy/haproxy.cfg "
                    "&& docker restart edge_haproxy"
                ),
            )
            print(f"{Y}[OK] Bloqueo por IP DESACTIVADO y edge_haproxy reiniciado.{NC}")
            pause()
        elif op == "3":
            run_remote("ns1", sudo_wrap("docker exec edge_haproxy grep 'deny_status 429' /usr/local/etc/haproxy/haproxy.cfg"))
            pause()
        elif op == "0":
            return


def action_ataque_k6() -> None:
    k6_bin = find_k6()
    if not k6_bin:
        print(f"{R}[ERROR] No se encontró k6 instalado en este equipo.{NC}")
        pause()
        return

    while True:
        rl = get_rate_limit_status()
        color_rl = G if rl == "ACTIVADO" else Y
        banner("2. ATAQUE DE SATURACIÓN CON k6")
        print(f"  Bloqueo por IP en HAProxy: {color_rl}{BOLD}{rl}{NC}")
        print(f"  Grafana: {BOLD}http://10.33.195.185:3000/{NC} (admin / tas10_grafana)\n")
        print(f"  {C}1){NC} Ataque Rápido   (60s, hasta 120 VUs)")
        print(f"  {C}2){NC} Ataque Estándar (105s, hasta 200 VUs)")
        print(f"  {C}3){NC} Ataque Extremo  (145s, hasta 300 VUs · punto de quiebre)")
        print(f"  {C}0){NC} Volver")
        op = input("\nElige una opción: ").strip()

        modos = {"1": "rapido", "2": "estandar", "3": "extremo"}
        if op in modos:
            env = os.environ.copy()
            env["MODO"] = modos[op]
            env["TARGET_URL"] = f"https://{BASTION_IP}"
            env["HOST_HEADER"] = "cms.tas10.local"
            print(f"\n{B}{BOLD}>>> Ejecutando k6 en modo {modos[op].upper()}...{NC}\n")
            subprocess.run([k6_bin, "run", str(K6_SCRIPT)], env=env)
            pause()
        elif op == "0":
            return


def action_auto_levantamiento() -> None:
    while True:
        banner("3. TEST DE AUTO-LEVANTAMIENTO (CRASH RECOVERY)")
        print(f"  {C}1){NC} Crash MariaDB en ubuntudb (pkill -9 mariadbd -> systemd levanta en ~5s)")
        print(f"  {C}2){NC} Crash CMS 1 (kill -9 al PID de apache -> Docker unless-stopped levanta solo)")
        print(f"  {C}3){NC} Crash CMS 2 (kill -9 al PID de apache -> Docker unless-stopped levanta solo)")
        print(f"  {C}0){NC} Volver")
        op = input("\nElige una opción: ").strip()

        if op == "1":
            print(f"\n{Y}>>> Matando proceso mariadbd con SIGKILL (-9)...{NC}")
            run_remote("db", sudo_wrap("pkill -9 mariadbd || true"))
            for i in range(1, 13):
                res = run_remote("db", "systemctl is-active mariadb || true", capture=True)
                st = res.stdout.strip()
                color = G if st == "active" else R
                print(f"  t+{i:02d}s -> mariadb: {color}{BOLD}{st}{NC}")
                if st == "active" and i >= 2:
                    break
                time.sleep(1)
            pause()
        elif op == "2":
            print(f"\n{Y}>>> Matando el proceso principal (PID) de cms_backend con kill -9...{NC}")
            run_remote("cms1", sudo_wrap("PID=$(docker inspect -f '{{.State.Pid}}' cms_backend) && [ \"$PID\" -gt 0 ] && kill -9 \"$PID\""))
            for i in range(1, 11):
                res = run_remote("cms1", sudo_wrap("docker ps --filter name=cms_backend --format '{{.Status}}'"), capture=True)
                st = res.stdout.strip() or "detenido"
                color = G if st.startswith("Up") else R
                print(f"  t+{i:02d}s -> cms_backend: {color}{BOLD}{st}{NC}")
                if st.startswith("Up") and i >= 2:
                    break
                time.sleep(1)
            pause()
        elif op == "3":
            print(f"\n{Y}>>> Matando el proceso principal (PID) de nodo_cms2 con kill -9...{NC}")
            run_remote("cms2", sudo_wrap("PID=$(docker inspect -f '{{.State.Pid}}' nodo_cms2) && [ \"$PID\" -gt 0 ] && kill -9 \"$PID\""))
            for i in range(1, 11):
                res = run_remote("cms2", sudo_wrap("docker ps --filter name=nodo_cms2 --format '{{.Status}}'"), capture=True)
                st = res.stdout.strip() or "detenido"
                color = G if st.startswith("Up") else R
                print(f"  t+{i:02d}s -> nodo_cms2: {color}{BOLD}{st}{NC}")
                if st.startswith("Up") and i >= 2:
                    break
                time.sleep(1)
            pause()
        elif op == "0":
            return


def action_caidas_controladas() -> None:
    while True:
        banner("4. CAÍDAS CONTROLADAS (ALERTAS GRAFANA / FAILOVER)")
        print(f"  {C}1){NC} {R}Detener{NC} MariaDB (dispara MariaDBCaida + SitioWebCaido)")
        print(f"  {C}2){NC} {G}Iniciar{NC} MariaDB")
        print(f"  {C}3){NC} {R}Detener{NC} CMS 1 (failover 100% a CMS 2 sin corte)")
        print(f"  {C}4){NC} {G}Iniciar{NC} CMS 1")
        print(f"  {C}5){NC} {R}Detener{NC} CMS 2 (failover 100% a CMS 1 sin corte)")
        print(f"  {C}6){NC} {G}Iniciar{NC} CMS 2")
        print(f"  {C}7){NC} Ver estado actual de HAProxy + MariaDB")
        print(f"  {C}0){NC} Volver")
        op = input("\nElige una opción: ").strip()

        if op == "1":
            run_remote("db", sudo_wrap("date -u +'%Y-%m-%dT%H:%M:%SZ' && systemctl stop mariadb && systemctl is-active mariadb || true"))
            pause()
        elif op == "2":
            run_remote("db", sudo_wrap("systemctl start mariadb && systemctl is-active mariadb"))
            pause()
        elif op == "3":
            run_remote("cms1", sudo_wrap("docker stop cms_backend"))
            print(f"{Y}[OK] CMS 1 detenido. HAProxy deriva el 100% a CMS 2.{NC}")
            pause()
        elif op == "4":
            run_remote("cms1", sudo_wrap("docker start cms_backend"))
            print(f"{G}[OK] CMS 1 iniciado.{NC}")
            pause()
        elif op == "5":
            run_remote("cms2", sudo_wrap("docker stop nodo_cms2"))
            print(f"{Y}[OK] CMS 2 detenido. HAProxy deriva el 100% a CMS 1.{NC}")
            pause()
        elif op == "6":
            run_remote("cms2", sudo_wrap("docker start nodo_cms2"))
            print(f"{G}[OK] CMS 2 iniciado.{NC}")
            pause()
        elif op == "7":
            run_remote("ns1", "curl -s 'http://127.0.0.1:8404/;csv' | grep cms_backend | cut -d, -f1,2,18,37")
            run_remote("db", "echo -n 'mariadb: '; systemctl is-active mariadb || true")
            pause()
        elif op == "0":
            return


def action_respaldos() -> None:
    while True:
        banner("5. RESPALDOS Y RESTAURACIÓN (ETAPA 4)")
        print(f"  {C}1){NC} Listar respaldos vigentes en marcelovers (/backups/db y /backups/wp_files)")
        print(f"  {C}2){NC} Generar un respaldo nuevo ahora (hacer_backup.sh en marcelovers)")
        print(f"  {C}3){NC} {Y}Borrar un producto de producción (wordpress){NC} para verlo desaparecer en la web")
        print(f"  {C}4){NC} {R}{BOLD}BORRAR TODA la BD wordpress (DROP DATABASE){NC} (simular desastre total)")
        print(f"  {C}5){NC} {G}Restaurar último respaldo en producción (wordpress){NC} y medir RTO")
        print(f"  {C}6){NC} Prueba automatizada en BD temporal wordpress_eval (demo_comprobar_respaldos.sh)")
        print(f"  {C}0){NC} Volver")
        op = input("\nElige una opción: ").strip()

        if op == "1":
            run_remote("nfs", sudo_wrap("ls -lh /backups/db/ /backups/wp_files/"))
            pause()
        elif op == "2":
            print(f"\n{B}>>> Ejecutando /backups/scripts/hacer_backup.sh en marcelovers...{NC}")
            run_remote("nfs", sudo_wrap("/backups/scripts/hacer_backup.sh"))
            print(f"{G}[OK] Respaldo generado.{NC}")
            pause()
        elif op == "3":
            print(f"\n{B}>>> Productos actuales en producción (wordpress):{NC}")
            run_remote(
                "nfs",
                "mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e "
                "\"SELECT ID, post_title, post_status FROM wordpress.wp_posts WHERE post_type='product';\"",
            )
            prod_id = input(f"\n{Y}Ingresa el ID del producto a borrar (Enter para cancelar): {NC}").strip()
            if prod_id.isdigit():
                conf = input(f"{R}¿Confirmas borrar el producto ID {prod_id} de 'wordpress'? [s/N]: {NC}").strip().lower()
                if conf == "s":
                    run_remote(
                        "nfs",
                        f"mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e "
                        f"\"DELETE FROM wordpress.wp_posts WHERE ID={prod_id} AND post_type='product';\"",
                    )
                    print(f"\n{Y}[OK] Producto ID {prod_id} borrado. Productos restantes en BD:{NC}")
                    run_remote(
                        "nfs",
                        "mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e "
                        "\"SELECT ID, post_title, post_status FROM wordpress.wp_posts WHERE post_type='product';\"",
                    )
                    print(f"\n{C}Recarga https://cms.tas10.local/shop/ en el navegador para ver que desapareció.{NC}")
                else:
                    print("Cancelado.")
            pause()
        elif op == "4":
            print(f"\n{R}{BOLD}[ATENCIÓN] Esto ejecutará DROP DATABASE wordpress; en MariaDB (10.33.199.85:7033).{NC}")
            conf = input(f"{R}Escribe BORRAR para confirmar: {NC}").strip()
            if conf == "BORRAR":
                run_remote(
                    "nfs",
                    "mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e "
                    "\"DROP DATABASE IF EXISTS wordpress; SHOW DATABASES;\"",
                )
                print(f"\n{R}[OK] Base 'wordpress' eliminada por completo.{NC}")
                print(f"{C}Abre https://cms.tas10.local/ para ver la caída, luego usa la opción 5 para restaurar.{NC}")
            else:
                print("Cancelado.")
            pause()
        elif op == "5":
            res = run_remote("nfs", "ls -1t /backups/db/ | head -n1", capture=True)
            ultimo = res.stdout.strip()
            if not ultimo:
                print(f"{R}[ERROR] No se encontraron respaldos en /backups/db/{NC}")
                pause()
                continue
            print(f"\n{Y}Respaldo más reciente:{NC} {BOLD}/backups/db/{ultimo}{NC}")
            conf = input(f"{G}¿Crear (si falta) y restaurar este respaldo sobre 'wordpress'? [s/N]: {NC}").strip().lower()
            if conf == "s":
                print(f"\n{B}>>> Restaurando /backups/db/{ultimo} -> wordpress (10.33.199.85:7033)...{NC}")
                t0 = time.monotonic()
                r = run_remote(
                    "nfs",
                    f"mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e 'CREATE DATABASE IF NOT EXISTS wordpress;' "
                    f"&& gunzip -c /backups/db/{ultimo} | mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 wordpress",
                )
                rto = time.monotonic() - t0
                if r.returncode == 0:
                    print(f"\n{G}{BOLD}[OK] Restauración completada en {rto:.2f} segundos (RTO real).{NC}")
                    print(f"\n{B}>>> Tablas y productos recuperados en producción (wordpress):{NC}")
                    run_remote(
                        "nfs",
                        "mariadb -h 10.33.199.85 -P 7033 -u tas_cms -ptas_10 -e "
                        "\"SELECT COUNT(*) AS tablas_recuperadas FROM information_schema.tables WHERE table_schema='wordpress'; "
                        "SELECT ID, post_title, post_status FROM wordpress.wp_posts WHERE post_type='product';\"",
                    )
                    print(f"\n{C}Recarga https://cms.tas10.local/shop/ para comprobar que la tienda volvió al 100%.{NC}")
                else:
                    print(f"{R}[ERROR] La restauración falló (código {r.returncode}).{NC}")
            else:
                print("Cancelado.")
            pause()
        elif op == "6":
            if BACKUP_SCRIPT.exists():
                subprocess.run([str(BACKUP_SCRIPT)])
            else:
                print(f"{R}[ERROR] No se encontró {BACKUP_SCRIPT}{NC}")
            pause()
        elif op == "0":
            return


def main() -> None:
    ensure_key()
    while True:
        banner("PANEL DE PRUEBAS Y DEMO EN VIVO · NODO SUR (GRUPO 10)")
        print(f"  {DIM}Web: https://cms.tas10.local | Grafana: http://10.33.195.185:3000/ | HAProxy: :8404{NC}\n")
        print(f"  {C}1){NC} Bloqueo por IP en HAProxy (Activar / Desactivar HTTP 429)")
        print(f"  {C}2){NC} Ataque de saturación con k6 (Rápido / Estándar / Extremo)")
        print(f"  {C}3){NC} Test de auto-levantamiento (pkill -9 MariaDB / docker kill CMS)")
        print(f"  {C}4){NC} Caídas controladas (Alertas Grafana / Failover CMS1-CMS2)")
        print(f"  {C}5){NC} Respaldos y restauración (Etapa 4)")
        print(f"  {C}0){NC} Salir")

        op = input("\nSelecciona una opción [0-5]: ").strip()
        actions = {
            "1": action_rate_limiting,
            "2": action_ataque_k6,
            "3": action_auto_levantamiento,
            "4": action_caidas_controladas,
            "5": action_respaldos,
        }
        if op == "0":
            print("\nSaliendo del panel. ¡Éxito en la defensa!")
            break
        fn = actions.get(op)
        if fn:
            try:
                fn()
            except KeyboardInterrupt:
                print(f"\n{Y}[Interrumpido] Volviendo al menú...{NC}")
        else:
            print(f"{R}Opción no válida.{NC}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nSaliendo...")
