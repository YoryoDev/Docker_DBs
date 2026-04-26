# ─── Docker DBs — Bash Aliases ────────────────────────────────────────────────
# Tras clonar el repo, añade esta línea a tu ~/.bashrc o ~/.bash_profile:
#
#   source /ruta/al/repo/Docker_DBs/.bash-aliases
#
# El archivo debe permanecer en el repo para que las rutas se resuelvan
# correctamente sin importar el usuario o la máquina.
# ──────────────────────────────────────────────────────────────────────────────

# Directorio raíz del repo (se resuelve en el momento del source, sin rutas hardcodeadas)
_DDBS=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Helper interno: ejecuta docker compose en el subdirectorio de cada proyecto
# Cada proyecto usa su propio compose.yaml y .env — sin depender del compose.yaml raíz
# Uso: _ddbs_project <subdir> <profile> <comando...>
_ddbs_project() {
  local project_dir="$_DDBS/$1"
  local profile="$2"
  shift 2
  docker compose -f "${project_dir}/compose.yaml" \
    --project-directory "${project_dir}" \
    --profile "${profile}" \
    "$@"
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAL
# ══════════════════════════════════════════════════════════════════════════════

# Estado de todos los contenedores del proyecto
ddbs-ps() {
  docker ps -a \
    --filter 'name=mariadb' \
    --filter 'name=mongodb8' \
    --filter 'name=sqlserver22' \
    --filter 'name=sqlserver25' \
    --filter 'name=mysql8' \
    --filter 'name=oracle19c' \
    --filter 'name=postgresql17' \
    --filter 'name=postgresql18' \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

# Listar imágenes de bases de datos
alias ddbs-images='docker images | grep -E "mariadb|mongo|mssql|mysql|oracle|postgres"'

# Ayuda: muestra todos los aliases disponibles
ddbs-help() {
  echo ""
  echo "  ╔══════════════════════════════════════════════════════════════════╗"
  echo "  ║              Docker DBs — Aliases disponibles                   ║"
  echo "  ╠══════════════╦═══════════════════════════════════════════════════╣"
  echo "  ║   GENERAL    ║  ddbs-ps         Estado de todos los contenedores ║"
  echo "  ║              ║  ddbs-images     Listar imágenes de DBs           ║"
  echo "  ║              ║  ddbs-help       Mostrar esta ayuda               ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  MARIADB     ║  mdb-up/down/stop/start/restart                  ║"
  echo "  ║  11.4:3307   ║  mdb-logs  mdb-shell  mdb-client  mdb-status     ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  MONGODB     ║  mongo-up/down/stop/start/restart                ║"
  echo "  ║  8.0:27017   ║  mongo-logs  mongo-shell  mongo-cli  mongo-status ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  MSSQL 2022  ║  sql22-up/down/stop/start/restart                ║"
  echo "  ║  :1434       ║  sql22-logs  sql22-shell  sql22-client  sql22-status ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  MSSQL 2025  ║  sql25-up/down/stop/start/restart                ║"
  echo "  ║  :1433       ║  sql25-logs  sql25-shell  sql25-client  sql25-status ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  MYSQL 8.4   ║  mysql-up/down/stop/start/restart                ║"
  echo "  ║  :3306       ║  mysql-logs  mysql-shell  mysql-client  mysql-status ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  ORACLE 19c  ║  ora-up/down/stop/start/restart                  ║"
  echo "  ║  :1521/:5500 ║  ora-logs  ora-shell  ora-sysdba  ora-status     ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  POSTGRES 17 ║  pg17-up/down/stop/start/restart                 ║"
  echo "  ║  :5433       ║  pg17-logs  pg17-shell  pg17-psql  pg17-status   ║"
  echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
  echo "  ║  POSTGRES 18 ║  pg18-up/down/stop/start/restart                 ║"
  echo "  ║  :5432       ║  pg18-logs  pg18-shell  pg18-psql  pg18-status   ║"
  echo "  ╚══════════════╩═══════════════════════════════════════════════════╝"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MARIADB 11.4  |  container: mariadb  |  puerto: 3307
# ══════════════════════════════════════════════════════════════════════════════
alias mdb-up='_ddbs_project mariadb mariadb up -d'
alias mdb-down='_ddbs_project mariadb mariadb down'
alias mdb-stop='docker stop mariadb'
alias mdb-start='docker start mariadb'
alias mdb-restart='docker restart mariadb'
alias mdb-logs='docker logs -f mariadb'
alias mdb-shell='docker exec -it mariadb bash'
alias mdb-client='docker exec -it mariadb mariadb -u root -p'
alias mdb-status='docker inspect --format "{{.Name}}: {{.State.Status}}" mariadb'

# ══════════════════════════════════════════════════════════════════════════════
# MONGODB 8.0  |  container: mongodb8  |  puerto: 27017
# ══════════════════════════════════════════════════════════════════════════════
alias mongo-up='_ddbs_project mongodb mongodb up -d'
alias mongo-down='_ddbs_project mongodb mongodb down'
alias mongo-stop='docker stop mongodb8'
alias mongo-start='docker start mongodb8'
alias mongo-restart='docker restart mongodb8'
alias mongo-logs='docker logs -f mongodb8'
alias mongo-shell='docker exec -it mongodb8 bash'
alias mongo-cli='docker exec -it mongodb8 mongosh'
alias mongo-status='docker inspect --format "{{.Name}}: {{.State.Status}}" mongodb8'

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2022  |  container: sqlserver22  |  puerto: 1434
# ══════════════════════════════════════════════════════════════════════════════
alias sql22-up='_ddbs_project mssql2022 mssql2022 up -d'
alias sql22-down='_ddbs_project mssql2022 mssql2022 down'
alias sql22-stop='docker stop sqlserver22'
alias sql22-start='docker start sqlserver22'
alias sql22-restart='docker restart sqlserver22'
alias sql22-logs='docker logs -f sqlserver22'
alias sql22-shell='docker exec -it sqlserver22 bash'
alias sql22-client='docker exec -it sqlserver22 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias sql22-status='docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22'

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
alias sql25-up='_ddbs_project mssql2025 mssql2025 up -d'
alias sql25-down='_ddbs_project mssql2025 mssql2025 down'
alias sql25-stop='docker stop sqlserver25'
alias sql25-start='docker start sqlserver25'
alias sql25-restart='docker restart sqlserver25'
alias sql25-logs='docker logs -f sqlserver25'
alias sql25-shell='docker exec -it sqlserver25 bash'
alias sql25-client='docker exec -it sqlserver25 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias sql25-status='docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25'

# ══════════════════════════════════════════════════════════════════════════════
# MYSQL 8.4  |  container: mysql8  |  puerto: 3306
# ══════════════════════════════════════════════════════════════════════════════
alias mysql-up='_ddbs_project mysql mysql up -d'
alias mysql-down='_ddbs_project mysql mysql down'
alias mysql-stop='docker stop mysql8'
alias mysql-start='docker start mysql8'
alias mysql-restart='docker restart mysql8'
alias mysql-logs='docker logs -f mysql8'
alias mysql-shell='docker exec -it mysql8 bash'
alias mysql-client='docker exec -it mysql8 mysql -u root -p'
alias mysql-status='docker inspect --format "{{.Name}}: {{.State.Status}}" mysql8'

# ══════════════════════════════════════════════════════════════════════════════
# ORACLE 19c  |  container: oracle19c  |  puertos: 1521 (SQL), 5500 (EM)
# ══════════════════════════════════════════════════════════════════════════════
alias ora-up='_ddbs_project oracle19c oracle19c up -d'
alias ora-down='_ddbs_project oracle19c oracle19c down'
alias ora-stop='docker stop oracle19c'
alias ora-start='docker start oracle19c'
alias ora-restart='docker restart oracle19c'
alias ora-logs='docker logs -f oracle19c'
alias ora-shell='docker exec -it oracle19c bash'
alias ora-sysdba='docker exec -it oracle19c sqlplus / as sysdba'
alias ora-status='docker inspect --format "{{.Name}}: {{.State.Status}}" oracle19c'

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 17  |  container: postgresql17  |  puerto: 5433
# ══════════════════════════════════════════════════════════════════════════════
alias pg17-up='_ddbs_project postgresql17 postgresql17 up -d'
alias pg17-down='_ddbs_project postgresql17 postgresql17 down'
alias pg17-stop='docker stop postgresql17'
alias pg17-start='docker start postgresql17'
alias pg17-restart='docker restart postgresql17'
alias pg17-logs='docker logs -f postgresql17'
alias pg17-shell='docker exec -it postgresql17 bash'
alias pg17-psql='docker exec -it postgresql17 psql -U postgres'
alias pg17-status='docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql17'

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 18  |  container: postgresql18  |  puerto: 5432
# ══════════════════════════════════════════════════════════════════════════════
alias pg18-up='_ddbs_project postgresql18 postgresql18 up -d'
alias pg18-down='_ddbs_project postgresql18 postgresql18 down'
alias pg18-stop='docker stop postgresql18'
alias pg18-start='docker start postgresql18'
alias pg18-restart='docker restart postgresql18'
alias pg18-logs='docker logs -f postgresql18'
alias pg18-shell='docker exec -it postgresql18 bash'
alias pg18-psql='docker exec -it postgresql18 psql -U postgres'
alias pg18-status='docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18'
