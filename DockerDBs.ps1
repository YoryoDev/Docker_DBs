# ─── Docker DBs — PowerShell Aliases ─────────────────────────────────────────
# INSTALACIÓN:
#   1. Copiar este archivo:
#        Copy-Item .\DockerDBs.ps1 "$HOME\Documents\PowerShell\"
#
#   2. Cargar en la sesión actual:
#        . "$HOME\Documents\PowerShell\DockerDBs.ps1"
#
#   3. Para que cargue automáticamente, agregá la línea anterior a:
#        ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#
# Requisito: el repo debe estar en ~/Docker_DBs (convención por defecto).
# Si lo clonaste en otra ruta, definí antes de cargar el script:
#   $env:DDBS_HOME = "C:\ruta\al\repo\Docker_DBs"
# ──────────────────────────────────────────────────────────────────────────────

$script:DDBS = if ($env:DDBS_HOME) { $env:DDBS_HOME } else { "$HOME\Docker_DBs" }

function Invoke-DDBSProject {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$Profile,
        [Parameter(ValueFromRemainingArguments)][string[]]$ComposeArgs
    )
    $fullDir = Join-Path $script:DDBS $ProjectDir
    docker compose (Join-Path $fullDir "compose.yaml") `
        --project-directory $fullDir `
        --profile $Profile @ComposeArgs
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
        --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}'
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
function Invoke-MdbUp   { Invoke-DDBSProject mariadb mariadb up -d }
function Invoke-MdbDown { Invoke-DDBSProject mariadb mariadb down }
Set-Alias mdb-up       Invoke-MdbUp
Set-Alias mdb-down     Invoke-MdbDown
Set-Alias mdb-stop     { docker stop mariadb }
Set-Alias mdb-start    { docker start mariadb }
Set-Alias mdb-restart  { docker restart mariadb }
Set-Alias mdb-logs     { docker logs -f mariadb }
Set-Alias mdb-shell    { docker exec -it mariadb bash }
Set-Alias mdb-client   { docker exec -it mariadb mariadb -u root -p }
Set-Alias mdb-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mariadb }

# ══════════════════════════════════════════════════════════════════════════════
# MONGODB 8.0  |  container: mongodb8  |  puerto: 27017
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-MongoUp   { Invoke-DDBSProject mongodb mongodb up -d }
function Invoke-MongoDown { Invoke-DDBSProject mongodb mongodb down }
Set-Alias mongo-up       Invoke-MongoUp
Set-Alias mongo-down     Invoke-MongoDown
Set-Alias mongo-stop     { docker stop mongodb8 }
Set-Alias mongo-start    { docker start mongodb8 }
Set-Alias mongo-restart  { docker restart mongodb8 }
Set-Alias mongo-logs     { docker logs -f mongodb8 }
Set-Alias mongo-shell    { docker exec -it mongodb8 bash }
Set-Alias mongo-cli      { docker exec -it mongodb8 mongosh }
Set-Alias mongo-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mongodb8 }

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2022  |  container: sqlserver22  |  puerto: 1434
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Sql22Up   { Invoke-DDBSProject mssql2022 mssql2022 up -d }
function Invoke-Sql22Down { Invoke-DDBSProject mssql2022 mssql2022 down }
Set-Alias sql22-up       Invoke-Sql22Up
Set-Alias sql22-down     Invoke-Sql22Down
Set-Alias sql22-stop     { docker stop sqlserver22 }
Set-Alias sql22-start    { docker start sqlserver22 }
Set-Alias sql22-restart  { docker restart sqlserver22 }
Set-Alias sql22-logs     { docker logs -f sqlserver22 }
Set-Alias sql22-shell    { docker exec -it sqlserver22 bash }
Set-Alias sql22-client   { docker exec -it sqlserver22 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No }
Set-Alias sql22-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22 }

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Sql25Up   { Invoke-DDBSProject mssql2025 mssql2025 up -d }
function Invoke-Sql25Down { Invoke-DDBSProject mssql2025 mssql2025 down }
Set-Alias sql25-up       Invoke-Sql25Up
Set-Alias sql25-down     Invoke-Sql25Down
Set-Alias sql25-stop     { docker stop sqlserver25 }
Set-Alias sql25-start    { docker start sqlserver25 }
Set-Alias sql25-restart  { docker restart sqlserver25 }
Set-Alias sql25-logs     { docker logs -f sqlserver25 }
Set-Alias sql25-shell    { docker exec -it sqlserver25 bash }
Set-Alias sql25-client   { docker exec -it sqlserver25 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No }
Set-Alias sql25-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25 }

# ══════════════════════════════════════════════════════════════════════════════
# MYSQL 8.4  |  container: mysql8  |  puerto: 3306
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-MySQLUp   { Invoke-DDBSProject mysql mysql up -d }
function Invoke-MySQLDown { Invoke-DDBSProject mysql mysql down }
Set-Alias mysql-up       Invoke-MySQLUp
Set-Alias mysql-down     Invoke-MySQLDown
Set-Alias mysql-stop     { docker stop mysql8 }
Set-Alias mysql-start    { docker start mysql8 }
Set-Alias mysql-restart  { docker restart mysql8 }
Set-Alias mysql-logs     { docker logs -f mysql8 }
Set-Alias mysql-shell    { docker exec -it mysql8 bash }
Set-Alias mysql-client   { docker exec -it mysql8 mysql -u root -p }
Set-Alias mysql-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mysql8 }

# ══════════════════════════════════════════════════════════════════════════════
# ORACLE 19c  |  container: oracle19c  |  puertos: 1521 (SQL), 5500 (EM)
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-OraUp   { Invoke-DDBSProject oracle19c oracle19c up -d }
function Invoke-OraDown { Invoke-DDBSProject oracle19c oracle19c down }
Set-Alias ora-up       Invoke-OraUp
Set-Alias ora-down     Invoke-OraDown
Set-Alias ora-stop     { docker stop oracle19c }
Set-Alias ora-start    { docker start oracle19c }
Set-Alias ora-restart  { docker restart oracle19c }
Set-Alias ora-logs     { docker logs -f oracle19c }
Set-Alias ora-shell    { docker exec -it oracle19c bash }
Set-Alias ora-sysdba   { docker exec -it oracle19c sqlplus / as sysdba }
Set-Alias ora-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" oracle19c }

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 17  |  container: postgresql17  |  puerto: 5433
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Pg17Up   { Invoke-DDBSProject postgresql17 postgresql17 up -d }
function Invoke-Pg17Down { Invoke-DDBSProject postgresql17 postgresql17 down }
Set-Alias pg17-up       Invoke-Pg17Up
Set-Alias pg17-down     Invoke-Pg17Down
Set-Alias pg17-stop     { docker stop postgresql17 }
Set-Alias pg17-start    { docker start postgresql17 }
Set-Alias pg17-restart  { docker restart postgresql17 }
Set-Alias pg17-logs     { docker logs -f postgresql17 }
Set-Alias pg17-shell    { docker exec -it postgresql17 bash }
Set-Alias pg17-psql     { docker exec -it postgresql17 psql -U postgres }
Set-Alias pg17-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql17 }

# ══════════════════════════════════════════════════════════════════════════════
# POSTGRESQL 18  |  container: postgresql18  |  puerto: 5432
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Pg18Up   { Invoke-DDBSProject postgresql18 postgresql18 up -d }
function Invoke-Pg18Down { Invoke-DDBSProject postgresql18 postgresql18 down }
Set-Alias pg18-up       Invoke-Pg18Up
Set-Alias pg18-down     Invoke-Pg18Down
Set-Alias pg18-stop     { docker stop postgresql18 }
Set-Alias pg18-start    { docker start postgresql18 }
Set-Alias pg18-restart  { docker restart postgresql18 }
Set-Alias pg18-logs     { docker logs -f postgresql18 }
Set-Alias pg18-shell    { docker exec -it postgresql18 bash }
Set-Alias pg18-psql     { docker exec -it postgresql18 psql -U postgres }
Set-Alias pg18-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18 }
