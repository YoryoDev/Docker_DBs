# ─── Docker/Podman DBs — Fish Aliases ────────────────────────────────────────
# INSTALACIÓN:
#   1. Copiar este archivo:
#        cp docker_dbs.fish ~/.config/fish/conf.d/
#
#   2. Recargar la shell:
#        source ~/.config/fish/conf.d/docker_dbs.fish
#      O simplemente abrir una nueva terminal.
#
# Por defecto se busca primero en ~/Workspace/Docker_DBs y luego en ~/Docker_DBs.
# Si lo clonaste en otra ruta, definí antes:
#   set -gx DDBS_HOME /ruta/al/repo/Docker_DBs
# ──────────────────────────────────────────────────────────────────────────────

set -l _DDBS "$HOME/Docker_DBs"
if set -q DDBS_HOME; and test -n "$DDBS_HOME"
    set _DDBS "$DDBS_HOME"
else if test -d "$HOME/Workspace/Docker_DBs"
    set _DDBS "$HOME/Workspace/Docker_DBs"
end

function _ddbs_project --inherit-variable _DDBS
    set -l project_dir "$_DDBS/$argv[1]"
    set -l profile $argv[2]
    set -l rest $argv[3..-1]
    docker compose -f "$project_dir/compose.yaml" \
        --project-directory "$project_dir" \
        --env-file "$project_dir/.env" \
        --profile $profile $rest
end

# Variante Podman. `podman compose` requiere un proveedor Compose compatible.
function _pddbs_project --inherit-variable _DDBS
    set -l project_dir "$_DDBS/$argv[1]"
    set -l profile $argv[2]
    set -l rest $argv[3..-1]
    podman compose -f "$project_dir/compose.yaml" \
        --env-file "$project_dir/.env" \
        --profile $profile $rest
end

# ══════════════════════════════════════════════════════════════════════════════
# GENERAL
# ══════════════════════════════════════════════════════════════════════════════

function _ddbs_ps
    docker ps -a \
        --filter 'name=mariadb' --filter 'name=mongodb8' \
        --filter 'name=sqlserver22' --filter 'name=sqlserver25' \
        --filter 'name=mysql8' \
        --filter 'name=postgresql17' --filter 'name=postgresql18' \
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
end
alias ddbs-ps=_ddbs_ps

function _pddbs_ps
    podman ps -a \
        --filter 'name=mariadb' --filter 'name=mongodb8' \
        --filter 'name=sqlserver22' --filter 'name=sqlserver25' \
        --filter 'name=mysql8' \
        --filter 'name=postgresql17' --filter 'name=postgresql18' \
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
end
alias pod-ddbs-ps=_pddbs_ps

function _ddbs_images
    docker images | grep -E "mariadb|mongo|mssql|mysql|postgres"
end
alias ddbs-images=_ddbs_images

function _pddbs_images
    podman images | grep -E "mariadb|mongo|mssql|mysql|postgres"
end
alias pod-ddbs-images=_pddbs_images

function _ddbs_help
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
    echo "  ║  POSTGRES 17 ║  pg17-up/down/stop/start/restart                 ║"
    echo "  ║  :5433       ║  pg17-logs  pg17-shell  pg17-psql  pg17-status   ║"
    echo "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    echo "  ║  POSTGRES 18 ║  pg18-up/down/stop/start/restart                 ║"
    echo "  ║  :5432       ║  pg18-logs  pg18-shell  pg18-psql  pg18-status   ║"
    echo "  ╚══════════════╩═══════════════════════════════════════════════════╝"
    echo "  Podman: anteponé pod- a cada alias (ej.: pod-pg18-up)."
    echo ""
end
alias ddbs-help=_ddbs_help
alias pod-ddbs-help=_ddbs_help

# ══════════════════════════════════════════════════════════════════════════════
# MARIADB 11.4  |  container: mariadb  |  puerto: 3307
# ══════════════════════════════════════════════════════════════════════════════
alias mdb-up      '_ddbs_project mariadb mariadb up -d'
alias mdb-down    '_ddbs_project mariadb mariadb down'
alias mdb-stop    'docker stop mariadb'
alias mdb-start   'docker start mariadb'
alias mdb-restart 'docker restart mariadb'
alias mdb-logs    'docker logs -f mariadb'
alias mdb-shell   'docker exec -it mariadb bash'
alias mdb-client  'docker exec -it mariadb mariadb -u root -p'
alias mdb-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" mariadb'

# ══════════════════════════════════════════════════════════════════════════════
# MONGODB 8.0  |  container: mongodb8  |  puerto: 27017
# ══════════════════════════════════════════════════════════════════════════════
alias mongo-up      '_ddbs_project mongodb mongodb up -d'
alias mongo-down    '_ddbs_project mongodb mongodb down'
alias mongo-stop    'docker stop mongodb8'
alias mongo-start   'docker start mongodb8'
alias mongo-restart 'docker restart mongodb8'
alias mongo-logs    'docker logs -f mongodb8'
alias mongo-shell   'docker exec -it mongodb8 bash'
alias mongo-cli     'docker exec -it mongodb8 mongosh'
alias mongo-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" mongodb8'

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2022  |  container: sqlserver22  |  puerto: 1434
# ══════════════════════════════════════════════════════════════════════════════
alias sql22-up      '_ddbs_project mssql2022 mssql2022 up -d'
alias sql22-down    '_ddbs_project mssql2022 mssql2022 down'
alias sql22-stop    'docker stop sqlserver22'
alias sql22-start   'docker start sqlserver22'
alias sql22-restart 'docker restart sqlserver22'
alias sql22-logs    'docker logs -f sqlserver22'
alias sql22-shell   'docker exec -it sqlserver22 bash'
alias sql22-client  'docker exec -it sqlserver22 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias sql22-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22'

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
alias sql25-up      '_ddbs_project mssql2025 mssql2025 up -d'
alias sql25-down    '_ddbs_project mssql2025 mssql2025 down'
alias sql25-stop    'docker stop sqlserver25'
alias sql25-start   'docker start sqlserver25'
alias sql25-restart 'docker restart sqlserver25'
alias sql25-logs    'docker logs -f sqlserver25'
alias sql25-shell   'docker exec -it sqlserver25 bash'
alias sql25-client  'docker exec -it sqlserver25 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias sql25-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25'

# ══════════════════════════════════════════════════════════════════════════════
# MYSQL 8.4  |  container: mysql8  |  puerto: 3306
# ══════════════════════════════════════════════════════════════════════════════
alias mysql-up      '_ddbs_project mysql mysql up -d'
alias mysql-down    '_ddbs_project mysql mysql down'
alias mysql-stop    'docker stop mysql8'
alias mysql-start   'docker start mysql8'
alias mysql-restart 'docker restart mysql8'
alias mysql-logs    'docker logs -f mysql8'
alias mysql-shell   'docker exec -it mysql8 bash'
alias mysql-client  'docker exec -it mysql8 mysql -u root -p'
alias mysql-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" mysql8'

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 17  |  container: postgresql17  |  puerto: 5433
# ══════════════════════════════════════════════════════════════════════════════
alias pg17-up      '_ddbs_project postgresql17 postgresql17 up -d'
alias pg17-down    '_ddbs_project postgresql17 postgresql17 down'
alias pg17-stop    'docker stop postgresql17'
alias pg17-start   'docker start postgresql17'
alias pg17-restart 'docker restart postgresql17'
alias pg17-logs    'docker logs -f postgresql17'
alias pg17-shell   'docker exec -it postgresql17 bash'
function pg17-psql
    docker exec -it postgresql17 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pg17-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql17'

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 18  |  container: postgresql18  |  puerto: 5432
# ══════════════════════════════════════════════════════════════════════════════
alias pg18-up      '_ddbs_project postgresql18 postgresql18 up -d'
alias pg18-down    '_ddbs_project postgresql18 postgresql18 down'
alias pg18-stop    'docker stop postgresql18'
alias pg18-start   'docker start postgresql18'
alias pg18-restart 'docker restart postgresql18'
alias pg18-logs    'docker logs -f postgresql18'
alias pg18-shell   'docker exec -it postgresql18 bash'
function pg18-psql
    docker exec -it postgresql18 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pg18-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18'

# ══════════════════════════════════════════════════════════════════════════════
# PODMAN — mismos comandos con prefijo pod-
# ══════════════════════════════════════════════════════════════════════════════

alias pod-mdb-up      '_pddbs_project mariadb mariadb up -d'
alias pod-mdb-down    '_pddbs_project mariadb mariadb down'
alias pod-mdb-stop    'podman stop mariadb'
alias pod-mdb-start   'podman start mariadb'
alias pod-mdb-restart 'podman restart mariadb'
alias pod-mdb-logs    'podman logs -f mariadb'
alias pod-mdb-shell   'podman exec -it mariadb bash'
alias pod-mdb-client  'podman exec -it mariadb mariadb -u root -p'
alias pod-mdb-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" mariadb'

alias pod-mongo-up      '_pddbs_project mongodb mongodb up -d'
alias pod-mongo-down    '_pddbs_project mongodb mongodb down'
alias pod-mongo-stop    'podman stop mongodb8'
alias pod-mongo-start   'podman start mongodb8'
alias pod-mongo-restart 'podman restart mongodb8'
alias pod-mongo-logs    'podman logs -f mongodb8'
alias pod-mongo-shell   'podman exec -it mongodb8 bash'
alias pod-mongo-cli     'podman exec -it mongodb8 mongosh'
alias pod-mongo-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" mongodb8'

alias pod-sql22-up      '_pddbs_project mssql2022 mssql2022 up -d'
alias pod-sql22-down    '_pddbs_project mssql2022 mssql2022 down'
alias pod-sql22-stop    'podman stop sqlserver22'
alias pod-sql22-start   'podman start sqlserver22'
alias pod-sql22-restart 'podman restart sqlserver22'
alias pod-sql22-logs    'podman logs -f sqlserver22'
alias pod-sql22-shell   'podman exec -it sqlserver22 bash'
alias pod-sql22-client  'podman exec -it sqlserver22 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias pod-sql22-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22'

alias pod-sql25-up      '_pddbs_project mssql2025 mssql2025 up -d'
alias pod-sql25-down    '_pddbs_project mssql2025 mssql2025 down'
alias pod-sql25-stop    'podman stop sqlserver25'
alias pod-sql25-start   'podman start sqlserver25'
alias pod-sql25-restart 'podman restart sqlserver25'
alias pod-sql25-logs    'podman logs -f sqlserver25'
alias pod-sql25-shell   'podman exec -it sqlserver25 bash'
alias pod-sql25-client  'podman exec -it sqlserver25 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No'
alias pod-sql25-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25'

alias pod-mysql-up      '_pddbs_project mysql mysql up -d'
alias pod-mysql-down    '_pddbs_project mysql mysql down'
alias pod-mysql-stop    'podman stop mysql8'
alias pod-mysql-start   'podman start mysql8'
alias pod-mysql-restart 'podman restart mysql8'
alias pod-mysql-logs    'podman logs -f mysql8'
alias pod-mysql-shell   'podman exec -it mysql8 bash'
alias pod-mysql-client  'podman exec -it mysql8 mysql -u root -p'
alias pod-mysql-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" mysql8'

alias pod-pg17-up      '_pddbs_project postgresql17 postgresql17 up -d'
alias pod-pg17-down    '_pddbs_project postgresql17 postgresql17 down'
alias pod-pg17-stop    'podman stop postgresql17'
alias pod-pg17-start   'podman start postgresql17'
alias pod-pg17-restart 'podman restart postgresql17'
alias pod-pg17-logs    'podman logs -f postgresql17'
alias pod-pg17-shell   'podman exec -it postgresql17 bash'
function pod-pg17-psql
    podman exec -it postgresql17 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pod-pg17-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" postgresql17'

alias pod-pg18-up      '_pddbs_project postgresql18 postgresql18 up -d'
alias pod-pg18-down    '_pddbs_project postgresql18 postgresql18 down'
alias pod-pg18-stop    'podman stop postgresql18'
alias pod-pg18-start   'podman start postgresql18'
alias pod-pg18-restart 'podman restart postgresql18'
alias pod-pg18-logs    'podman logs -f postgresql18'
alias pod-pg18-shell   'podman exec -it postgresql18 bash'
function pod-pg18-psql
    podman exec -it postgresql18 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pod-pg18-status  'podman inspect --format "{{.Name}}: {{.State.Status}}" postgresql18'
