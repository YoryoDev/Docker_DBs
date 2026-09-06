# ─── Docker DBs — PowerShell Aliases ─────────────────────────────────────────
# Load with dot-sourcing in the current session and in $PROFILE:
#   $env:DDBS_HOME = Join-Path $HOME "Docker_DBs"
#   . (Join-Path $env:DDBS_HOME "DockerDBs.ps1")
# Preserve any existing profile content; see README for setup.
#
# Requisito: el repo debe estar en ~/Docker_DBs (convención por defecto).
# Si lo clonaste en otra ruta, definí antes de cargar el script:
#   $env:DDBS_HOME = "C:\ruta\al\repo\Docker_DBs"
# ──────────────────────────────────────────────────────────────────────────────

$script:DDBS = if ($env:DDBS_HOME) { $env:DDBS_HOME } else { "$HOME\Docker_DBs" }

function Invoke-DDBSProject {
    param(
        [string]$ProjectDir,
        [string]$Profile
    )
    $fullDir = Join-Path $script:DDBS $ProjectDir
    docker compose -f (Join-Path $fullDir "compose.yaml") `
        --project-directory $fullDir `
        --env-file (Join-Path $fullDir ".env") `
        --profile $Profile @args
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAL
# ══════════════════════════════════════════════════════════════════════════════

function Show-DDBSContainers {
    docker ps -a `
        --filter 'name=mariadb' --filter 'name=mongodb8' `
        --filter 'name=sqlserver22' --filter 'name=sqlserver25' `
        --filter 'name=mysql8' --filter 'name=oracle19c' `
        --filter 'name=postgresql17' --filter 'name=postgresql18' `
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}
Set-Alias ddbs-ps Show-DDBSContainers

function Show-DDBSImages {
    docker images | Select-String "mariadb|mongo|mssql|mysql|oracle|postgres"
}
Set-Alias ddbs-images Show-DDBSImages

function Show-DDBSHelp {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗"
    Write-Host "  ║              Docker DBs — Aliases disponibles                   ║"
    Write-Host "  ╠══════════════╦═══════════════════════════════════════════════════╣"
    Write-Host "  ║   GENERAL    ║  ddbs-ps         Estado de todos los contenedores ║"
    Write-Host "  ║              ║  ddbs-images     Listar imágenes de DBs           ║"
    Write-Host "  ║              ║  ddbs-help       Mostrar esta ayuda               ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  MARIADB     ║  mdb-up/down/stop/start/restart                  ║"
    Write-Host "  ║  11.4:3307   ║  mdb-logs  mdb-shell  mdb-client  mdb-status     ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  MONGODB     ║  mongo-up/down/stop/start/restart                ║"
    Write-Host "  ║  8.0:27017   ║  mongo-logs  mongo-shell  mongo-cli  mongo-status ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  MSSQL 2022  ║  sql22-up/down/stop/start/restart                ║"
    Write-Host "  ║  :1434       ║  sql22-logs  sql22-shell  sql22-client  sql22-status ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  MSSQL 2025  ║  sql25-up/down/stop/start/restart                ║"
    Write-Host "  ║  :1433       ║  sql25-logs  sql25-shell  sql25-client  sql25-status ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  MYSQL 8.4   ║  mysql-up/down/stop/start/restart                ║"
    Write-Host "  ║  :3306       ║  mysql-logs  mysql-shell  mysql-client  mysql-status ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  ORACLE 19c  ║  ora-up/down/stop/start/restart                  ║"
    Write-Host "  ║  :1521/:5500 ║  ora-logs  ora-shell  ora-sysdba  ora-status     ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  POSTGRES 17 ║  pg17-up/down/stop/start/restart                 ║"
    Write-Host "  ║  :5433       ║  pg17-logs  pg17-shell  pg17-psql  pg17-status   ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  POSTGRES 18 ║  pg18-up/down/stop/start/restart                 ║"
    Write-Host "  ║  :5432       ║  pg18-logs  pg18-shell  pg18-psql  pg18-status   ║"
    Write-Host "  ╚══════════════╩═══════════════════════════════════════════════════╝"
    Write-Host ""
}
Set-Alias ddbs-help Show-DDBSHelp

# ══════════════════════════════════════════════════════════════════════════════
# MARIADB 11.4  |  container: mariadb  |  puerto: 3307
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-MdbUp   { Invoke-DDBSProject mariadb mariadb up -d @args }
function Invoke-MdbDown { Invoke-DDBSProject mariadb mariadb down @args }
Set-Alias mdb-up       Invoke-MdbUp
Set-Alias mdb-down     Invoke-MdbDown
function mdb-stop     { docker stop mariadb @args }
function mdb-start    { docker start mariadb @args }
function mdb-restart  { docker restart mariadb @args }
function mdb-logs     { docker logs -f mariadb @args }
function mdb-shell    { docker exec -it mariadb bash @args }
function mdb-client   { docker exec -it mariadb mariadb -u root -p @args }
function mdb-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mariadb @args }

# ══════════════════════════════════════════════════════════════════════════════
# MONGODB 8.0  |  container: mongodb8  |  puerto: 27017
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-MongoUp   { Invoke-DDBSProject mongodb mongodb up -d @args }
function Invoke-MongoDown { Invoke-DDBSProject mongodb mongodb down @args }
Set-Alias mongo-up       Invoke-MongoUp
Set-Alias mongo-down     Invoke-MongoDown
function mongo-stop     { docker stop mongodb8 @args }
function mongo-start    { docker start mongodb8 @args }
function mongo-restart  { docker restart mongodb8 @args }
function mongo-logs     { docker logs -f mongodb8 @args }
function mongo-shell    { docker exec -it mongodb8 bash @args }
function mongo-cli      { docker exec -it mongodb8 mongosh @args }
function mongo-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mongodb8 @args }

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2022  |  container: sqlserver22  |  puerto: 1434
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Sql22Up   { Invoke-DDBSProject mssql2022 mssql2022 up -d @args }
function Invoke-Sql22Down { Invoke-DDBSProject mssql2022 mssql2022 down @args }
Set-Alias sql22-up       Invoke-Sql22Up
Set-Alias sql22-down     Invoke-Sql22Down
function sql22-stop     { docker stop sqlserver22 @args }
function sql22-start    { docker start sqlserver22 @args }
function sql22-restart  { docker restart sqlserver22 @args }
function sql22-logs     { docker logs -f sqlserver22 @args }
function sql22-shell    { docker exec -it sqlserver22 bash @args }
function sql22-client   { docker exec -it sqlserver22 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No @args }
function sql22-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22 @args }

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Sql25Up   { Invoke-DDBSProject mssql2025 mssql2025 up -d @args }
function Invoke-Sql25Down { Invoke-DDBSProject mssql2025 mssql2025 down @args }
Set-Alias sql25-up       Invoke-Sql25Up
Set-Alias sql25-down     Invoke-Sql25Down
function sql25-stop     { docker stop sqlserver25 @args }
function sql25-start    { docker start sqlserver25 @args }
function sql25-restart  { docker restart sqlserver25 @args }
function sql25-logs     { docker logs -f sqlserver25 @args }
function sql25-shell    { docker exec -it sqlserver25 bash @args }
function sql25-client   { docker exec -it sqlserver25 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No @args }
function sql25-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25 @args }

# ══════════════════════════════════════════════════════════════════════════════
# MYSQL 8.4  |  container: mysql8  |  puerto: 3306
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-MySQLUp   { Invoke-DDBSProject mysql mysql up -d @args }
function Invoke-MySQLDown { Invoke-DDBSProject mysql mysql down @args }
Set-Alias mysql-up       Invoke-MySQLUp
Set-Alias mysql-down     Invoke-MySQLDown
function mysql-stop     { docker stop mysql8 @args }
function mysql-start    { docker start mysql8 @args }
function mysql-restart  { docker restart mysql8 @args }
function mysql-logs     { docker logs -f mysql8 @args }
function mysql-shell    { docker exec -it mysql8 bash @args }
function mysql-client   { docker exec -it mysql8 mysql -u root -p @args }
function mysql-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mysql8 @args }

# ══════════════════════════════════════════════════════════════════════════════
# ORACLE 19c  |  container: oracle19c  |  puertos: 1521 (SQL), 5500 (EM)
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-OraUp   { Invoke-DDBSProject oracle19c oracle19c up -d @args }
function Invoke-OraDown { Invoke-DDBSProject oracle19c oracle19c down @args }
Set-Alias ora-up       Invoke-OraUp
Set-Alias ora-down     Invoke-OraDown
function ora-stop     { docker stop oracle19c @args }
function ora-start    { docker start oracle19c @args }
function ora-restart  { docker restart oracle19c @args }
function ora-logs     { docker logs -f oracle19c @args }
function ora-shell    { docker exec -it oracle19c bash @args }
function ora-sysdba   { docker exec -it oracle19c sqlplus / as sysdba @args }
function ora-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" oracle19c @args }

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 17  |  container: postgresql17  |  puerto: 5433
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Pg17Up   { Invoke-DDBSProject postgresql17 postgresql17 up -d @args }
function Invoke-Pg17Down { Invoke-DDBSProject postgresql17 postgresql17 down @args }
Set-Alias pg17-up       Invoke-Pg17Up
Set-Alias pg17-down     Invoke-Pg17Down
function pg17-stop     { docker stop postgresql17 @args }
function pg17-start    { docker start postgresql17 @args }
function pg17-restart  { docker restart postgresql17 @args }
function pg17-logs     { docker logs -f postgresql17 @args }
function pg17-shell    { docker exec -it postgresql17 bash @args }
function pg17-psql     { docker exec -it postgresql17 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
function pg17-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql17 @args }

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 18  |  container: postgresql18  |  puerto: 5432
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Pg18Up   { Invoke-DDBSProject postgresql18 postgresql18 up -d @args }
function Invoke-Pg18Down { Invoke-DDBSProject postgresql18 postgresql18 down @args }
Set-Alias pg18-up       Invoke-Pg18Up
Set-Alias pg18-down     Invoke-Pg18Down
function pg18-stop     { docker stop postgresql18 @args }
function pg18-start    { docker start postgresql18 @args }
function pg18-restart  { docker restart postgresql18 @args }
function pg18-logs     { docker logs -f postgresql18 @args }
function pg18-shell    { docker exec -it postgresql18 bash @args }
function pg18-psql     { docker exec -it postgresql18 sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
function pg18-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18 @args }
