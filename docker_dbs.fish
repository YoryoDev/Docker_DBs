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

function _pddbs_podman --inherit-variable _DDBS
    if type -q slirp4netns
        set -fx CONTAINERS_CONF "$_DDBS/podman-containers.conf"
    end
    podman $argv
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
    _pddbs_podman compose -f "$project_dir/compose.yaml" \
        --env-file "$project_dir/.env" \
        --profile $profile $rest
end

function _pddbs_up
    set -l project $argv[1]
    set -l profile $argv[2]
    set -l init_service $argv[3]
    set -l main_service $argv[4]
    set -l rest $argv[5..-1]
    set -l provider_output (_pddbs_podman compose version 2>&1 | string collect)

    if not string match -q '*podman-compose*' -- $provider_output
        _pddbs_project $project $profile up -d $rest
        return $status
    end

    _pddbs_project $project $profile up -d $rest $init_service; or return
    set -l init_id (_pddbs_podman ps -aq \
        --filter "label=io.podman.compose.project=$project" \
        --filter "label=io.podman.compose.service=$init_service" | head -n 1)
    if test -z "$init_id"
        echo "No se encontró el init container de $project." >&2
        return 1
    end
    _pddbs_podman wait $init_id >/dev/null; or return
    set -l init_exit (_pddbs_podman inspect --format '{{.State.ExitCode}}' $init_id); or return
    if test "$init_exit" -ne 0
        echo "El init container de $project terminó con código $init_exit." >&2
        return $init_exit
    end
    _pddbs_project $project $profile up -d --no-deps $rest $main_service
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
    _pddbs_podman ps -a \
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
    _pddbs_podman images | grep -E "mariadb|mongo|mssql|mysql|postgres"
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
function mdb-client
    docker exec -it mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -u root "$@"' sh $argv
end
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
alias sql22-stop    'docker stop --time 60 sqlserver22'
alias sql22-start   'docker start sqlserver22'
alias sql22-restart 'docker restart --time 60 sqlserver22'
alias sql22-logs    'docker logs -f sqlserver22'
alias sql22-shell   'docker exec -it sqlserver22 bash'
function sql22-client
    docker exec -it sqlserver22 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh $argv
end
alias sql22-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22'

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
alias sql25-up      '_ddbs_project mssql2025 mssql2025 up -d'
alias sql25-down    '_ddbs_project mssql2025 mssql2025 down'
alias sql25-stop    'docker stop --time 60 sqlserver25'
alias sql25-start   'docker start sqlserver25'
alias sql25-restart 'docker restart --time 60 sqlserver25'
alias sql25-logs    'docker logs -f sqlserver25'
alias sql25-shell   'docker exec -it sqlserver25 bash'
function sql25-client
    docker exec -it sqlserver25 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh $argv
end
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
function mysql-client
    docker exec -it mysql8 sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root "$@"' sh $argv
end
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
    docker exec -it postgresql17 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
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
    docker exec -it postgresql18 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pg18-status  'docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18'

# ══════════════════════════════════════════════════════════════════════════════
# PODMAN — mismos comandos con prefijo pod-
# ══════════════════════════════════════════════════════════════════════════════

alias pod-mdb-up      '_pddbs_up mariadb mariadb mariadb_init mariadb'
alias pod-mdb-down    '_pddbs_project mariadb mariadb down'
alias pod-mdb-stop    '_pddbs_podman stop mariadb'
alias pod-mdb-start   '_pddbs_podman start mariadb'
alias pod-mdb-restart '_pddbs_podman restart mariadb'
alias pod-mdb-logs    '_pddbs_podman logs -f mariadb'
alias pod-mdb-shell   '_pddbs_podman exec -it mariadb bash'
function pod-mdb-client
    _pddbs_podman exec -it mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -u root "$@"' sh $argv
end
alias pod-mdb-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" mariadb'

alias pod-mongo-up      '_pddbs_up mongodb mongodb mongodb_init mongodb'
alias pod-mongo-down    '_pddbs_project mongodb mongodb down'
alias pod-mongo-stop    '_pddbs_podman stop mongodb8'
alias pod-mongo-start   '_pddbs_podman start mongodb8'
alias pod-mongo-restart '_pddbs_podman restart mongodb8'
alias pod-mongo-logs    '_pddbs_podman logs -f mongodb8'
alias pod-mongo-shell   '_pddbs_podman exec -it mongodb8 bash'
alias pod-mongo-cli     '_pddbs_podman exec -it mongodb8 mongosh'
alias pod-mongo-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" mongodb8'

alias pod-sql22-up      '_pddbs_up mssql2022 mssql2022 mssql2022_init mssql2022'
alias pod-sql22-down    '_pddbs_project mssql2022 mssql2022 down'
alias pod-sql22-stop    '_pddbs_podman stop --time 60 sqlserver22'
alias pod-sql22-start   '_pddbs_podman start sqlserver22'
alias pod-sql22-restart '_pddbs_podman restart --time 60 sqlserver22'
alias pod-sql22-logs    '_pddbs_podman logs -f sqlserver22'
alias pod-sql22-shell   '_pddbs_podman exec -it sqlserver22 bash'
function pod-sql22-client
    _pddbs_podman exec -it sqlserver22 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh $argv
end
alias pod-sql22-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22'

alias pod-sql25-up      '_pddbs_up mssql2025 mssql2025 mssql2025_init mssql2025'
alias pod-sql25-down    '_pddbs_project mssql2025 mssql2025 down'
alias pod-sql25-stop    '_pddbs_podman stop --time 60 sqlserver25'
alias pod-sql25-start   '_pddbs_podman start sqlserver25'
alias pod-sql25-restart '_pddbs_podman restart --time 60 sqlserver25'
alias pod-sql25-logs    '_pddbs_podman logs -f sqlserver25'
alias pod-sql25-shell   '_pddbs_podman exec -it sqlserver25 bash'
function pod-sql25-client
    _pddbs_podman exec -it sqlserver25 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh $argv
end
alias pod-sql25-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25'

alias pod-mysql-up      '_pddbs_up mysql mysql mysql_init mysql'
alias pod-mysql-down    '_pddbs_project mysql mysql down'
alias pod-mysql-stop    '_pddbs_podman stop mysql8'
alias pod-mysql-start   '_pddbs_podman start mysql8'
alias pod-mysql-restart '_pddbs_podman restart mysql8'
alias pod-mysql-logs    '_pddbs_podman logs -f mysql8'
alias pod-mysql-shell   '_pddbs_podman exec -it mysql8 bash'
function pod-mysql-client
    _pddbs_podman exec -it mysql8 sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root "$@"' sh $argv
end
alias pod-mysql-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" mysql8'

alias pod-pg17-up      '_pddbs_up postgresql17 postgresql17 postgresql17_init postgresql17'
alias pod-pg17-down    '_pddbs_project postgresql17 postgresql17 down'
alias pod-pg17-stop    '_pddbs_podman stop postgresql17'
alias pod-pg17-start   '_pddbs_podman start postgresql17'
alias pod-pg17-restart '_pddbs_podman restart postgresql17'
alias pod-pg17-logs    '_pddbs_podman logs -f postgresql17'
alias pod-pg17-shell   '_pddbs_podman exec -it postgresql17 bash'
function pod-pg17-psql
    _pddbs_podman exec -it postgresql17 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pod-pg17-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" postgresql17'

alias pod-pg18-up      '_pddbs_up postgresql18 postgresql18 postgresql18_init postgresql'
alias pod-pg18-down    '_pddbs_project postgresql18 postgresql18 down'
alias pod-pg18-stop    '_pddbs_podman stop postgresql18'
alias pod-pg18-start   '_pddbs_podman start postgresql18'
alias pod-pg18-restart '_pddbs_podman restart postgresql18'
alias pod-pg18-logs    '_pddbs_podman logs -f postgresql18'
alias pod-pg18-shell   '_pddbs_podman exec -it postgresql18 bash'
function pod-pg18-psql
    _pddbs_podman exec -it postgresql18 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh $argv
end
alias pod-pg18-status  '_pddbs_podman inspect --format "{{.Name}}: {{.State.Status}}" postgresql18'
