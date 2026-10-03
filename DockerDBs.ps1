# ─── Docker/Podman DBs — PowerShell Aliases ──────────────────────────────────
# Load with dot-sourcing in the current session and in $PROFILE:
#   $env:DDBS_HOME = Join-Path $HOME "Workspace\Docker_DBs"
#   . (Join-Path $env:DDBS_HOME "DockerDBs.ps1")
# Preserve any existing profile content; see README for setup.
#
# DDBS_HOME es opcional. Por defecto se busca primero en ~/Workspace/Docker_DBs
# y luego en ~/Docker_DBs. Si lo clonaste en otra ruta, definí antes:
#   $env:DDBS_HOME = "C:\ruta\al\repo\Docker_DBs"
# ──────────────────────────────────────────────────────────────────────────────

$script:DDBS = if ($env:DDBS_HOME) {
    $env:DDBS_HOME
} elseif (Test-Path -LiteralPath (Join-Path $HOME "Workspace\Docker_DBs") -PathType Container) {
    Join-Path $HOME "Workspace\Docker_DBs"
} else {
    Join-Path $HOME "Docker_DBs"
}

function Invoke-DDBSPodman {
    $previousConfig = [Environment]::GetEnvironmentVariable("CONTAINERS_CONF", "Process")
    $useFallback = $null -ne (Get-Command slirp4netns -ErrorAction SilentlyContinue)
    try {
        if ($useFallback) {
            $env:CONTAINERS_CONF = Join-Path $script:DDBS "podman-containers.conf"
        }
        podman @args
    } finally {
        if ($useFallback) {
            if ($null -eq $previousConfig) {
                Remove-Item Env:CONTAINERS_CONF -ErrorAction SilentlyContinue
            } else {
                $env:CONTAINERS_CONF = $previousConfig
            }
        }
    }
}

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

# Variante Podman. `podman compose` requiere un proveedor Compose compatible.
function Invoke-PDDBSProject {
    param(
        [string]$ProjectDir,
        [string]$Profile
    )
    $fullDir = Join-Path $script:DDBS $ProjectDir
    Invoke-DDBSPodman compose -f (Join-Path $fullDir "compose.yaml") `
        --env-file (Join-Path $fullDir ".env") `
        --profile $Profile @args
}

function Invoke-PDDBSUp {
    param(
        [string]$ProjectDir,
        [string]$Profile,
        [string]$InitService,
        [string]$MainService
    )
    $providerOutput = (Invoke-DDBSPodman compose version 2>&1 | Out-String)
    if ($providerOutput -notmatch "podman-compose") {
        Invoke-PDDBSProject $ProjectDir $Profile up -d @args
        return
    }

    $initArgs = @("up", "-d") + $args + @($InitService)
    Invoke-PDDBSProject $ProjectDir $Profile @initArgs
    if ($LASTEXITCODE -ne 0) { return }

    $initId = Invoke-DDBSPodman ps -aq `
        --filter "label=io.podman.compose.project=$ProjectDir" `
        --filter "label=io.podman.compose.service=$InitService" |
        Select-Object -First 1
    if (-not $initId) {
        Write-Error "No se encontró el init container de $ProjectDir."
        return
    }

    Invoke-DDBSPodman wait $initId | Out-Null
    if ($LASTEXITCODE -ne 0) { return }
    $initExit = Invoke-DDBSPodman inspect --format '{{.State.ExitCode}}' $initId
    if ($LASTEXITCODE -ne 0) { return }
    if ([int]$initExit -ne 0) {
        Write-Error "El init container de $ProjectDir terminó con código $initExit."
        return
    }

    $mainArgs = @("up", "-d", "--no-deps") + $args + @($MainService)
    Invoke-PDDBSProject $ProjectDir $Profile @mainArgs
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAL
# ══════════════════════════════════════════════════════════════════════════════

function Show-DDBSContainers {
    docker ps -a `
        --filter 'name=mariadb' --filter 'name=mongodb8' `
        --filter 'name=sqlserver22' --filter 'name=sqlserver25' `
        --filter 'name=mysql8' `
        --filter 'name=postgresql17' --filter 'name=postgresql18' `
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}
Set-Alias ddbs-ps Show-DDBSContainers

function Show-PDDBSContainers {
    Invoke-DDBSPodman ps -a `
        --filter 'name=mariadb' --filter 'name=mongodb8' `
        --filter 'name=sqlserver22' --filter 'name=sqlserver25' `
        --filter 'name=mysql8' `
        --filter 'name=postgresql17' --filter 'name=postgresql18' `
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}
Set-Alias pod-ddbs-ps Show-PDDBSContainers

function Show-DDBSImages {
    docker images | Select-String "mariadb|mongo|mssql|mysql|postgres"
}
Set-Alias ddbs-images Show-DDBSImages

function Show-PDDBSImages {
    Invoke-DDBSPodman images | Select-String "mariadb|mongo|mssql|mysql|postgres"
}
Set-Alias pod-ddbs-images Show-PDDBSImages

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
    Write-Host "  ║  POSTGRES 17 ║  pg17-up/down/stop/start/restart                 ║"
    Write-Host "  ║  :5433       ║  pg17-logs  pg17-shell  pg17-psql  pg17-status   ║"
    Write-Host "  ╠══════════════╬═══════════════════════════════════════════════════╣"
    Write-Host "  ║  POSTGRES 18 ║  pg18-up/down/stop/start/restart                 ║"
    Write-Host "  ║  :5432       ║  pg18-logs  pg18-shell  pg18-psql  pg18-status   ║"
    Write-Host "  ╚══════════════╩═══════════════════════════════════════════════════╝"
    Write-Host "  Podman: anteponé pod- a cada alias (ej.: pod-pg18-up)."
    Write-Host ""
}
Set-Alias ddbs-help Show-DDBSHelp
Set-Alias pod-ddbs-help Show-DDBSHelp

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
function mdb-client   { docker exec -it mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -u root "$@"' sh @args }
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
function sql22-stop     { docker stop --time 60 sqlserver22 @args }
function sql22-start    { docker start sqlserver22 @args }
function sql22-restart  { docker restart --time 60 sqlserver22 @args }
function sql22-logs     { docker logs -f sqlserver22 @args }
function sql22-shell    { docker exec -it sqlserver22 bash @args }
function sql22-client   { docker exec -it sqlserver22 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh @args }
function sql22-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22 @args }

# ══════════════════════════════════════════════════════════════════════════════
# SQL SERVER 2025  |  container: sqlserver25  |  puerto: 1433
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Sql25Up   { Invoke-DDBSProject mssql2025 mssql2025 up -d @args }
function Invoke-Sql25Down { Invoke-DDBSProject mssql2025 mssql2025 down @args }
Set-Alias sql25-up       Invoke-Sql25Up
Set-Alias sql25-down     Invoke-Sql25Down
function sql25-stop     { docker stop --time 60 sqlserver25 @args }
function sql25-start    { docker start sqlserver25 @args }
function sql25-restart  { docker restart --time 60 sqlserver25 @args }
function sql25-logs     { docker logs -f sqlserver25 @args }
function sql25-shell    { docker exec -it sqlserver25 bash @args }
function sql25-client   { docker exec -it sqlserver25 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh @args }
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
function mysql-client   { docker exec -it mysql8 sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root "$@"' sh @args }
function mysql-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" mysql8 @args }

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
function pg17-psql     { docker exec -it postgresql17 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
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
function pg18-psql     { docker exec -it postgresql18 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
function pg18-status   { docker inspect --format "{{.Name}}: {{.State.Status}}" postgresql18 @args }

# ══════════════════════════════════════════════════════════════════════════════
# PODMAN — mismos comandos con prefijo pod-
# ══════════════════════════════════════════════════════════════════════════════

function Invoke-PodMdbUp   { Invoke-PDDBSUp mariadb mariadb mariadb_init mariadb @args }
function Invoke-PodMdbDown { Invoke-PDDBSProject mariadb mariadb down @args }
Set-Alias pod-mdb-up       Invoke-PodMdbUp
Set-Alias pod-mdb-down     Invoke-PodMdbDown
function pod-mdb-stop     { Invoke-DDBSPodman stop mariadb @args }
function pod-mdb-start    { Invoke-DDBSPodman start mariadb @args }
function pod-mdb-restart  { Invoke-DDBSPodman restart mariadb @args }
function pod-mdb-logs     { Invoke-DDBSPodman logs -f mariadb @args }
function pod-mdb-shell    { Invoke-DDBSPodman exec -it mariadb bash @args }
function pod-mdb-client   { Invoke-DDBSPodman exec -it mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -u root "$@"' sh @args }
function pod-mdb-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" mariadb @args }

function Invoke-PodMongoUp   { Invoke-PDDBSUp mongodb mongodb mongodb_init mongodb @args }
function Invoke-PodMongoDown { Invoke-PDDBSProject mongodb mongodb down @args }
Set-Alias pod-mongo-up       Invoke-PodMongoUp
Set-Alias pod-mongo-down     Invoke-PodMongoDown
function pod-mongo-stop     { Invoke-DDBSPodman stop mongodb8 @args }
function pod-mongo-start    { Invoke-DDBSPodman start mongodb8 @args }
function pod-mongo-restart  { Invoke-DDBSPodman restart mongodb8 @args }
function pod-mongo-logs     { Invoke-DDBSPodman logs -f mongodb8 @args }
function pod-mongo-shell    { Invoke-DDBSPodman exec -it mongodb8 bash @args }
function pod-mongo-cli      { Invoke-DDBSPodman exec -it mongodb8 mongosh @args }
function pod-mongo-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" mongodb8 @args }

function Invoke-PodSql22Up   { Invoke-PDDBSUp mssql2022 mssql2022 mssql2022_init mssql2022 @args }
function Invoke-PodSql22Down { Invoke-PDDBSProject mssql2022 mssql2022 down @args }
Set-Alias pod-sql22-up       Invoke-PodSql22Up
Set-Alias pod-sql22-down     Invoke-PodSql22Down
function pod-sql22-stop     { Invoke-DDBSPodman stop --time 60 sqlserver22 @args }
function pod-sql22-start    { Invoke-DDBSPodman start sqlserver22 @args }
function pod-sql22-restart  { Invoke-DDBSPodman restart --time 60 sqlserver22 @args }
function pod-sql22-logs     { Invoke-DDBSPodman logs -f sqlserver22 @args }
function pod-sql22-shell    { Invoke-DDBSPodman exec -it sqlserver22 bash @args }
function pod-sql22-client   { Invoke-DDBSPodman exec -it sqlserver22 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh @args }
function pod-sql22-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver22 @args }

function Invoke-PodSql25Up   { Invoke-PDDBSUp mssql2025 mssql2025 mssql2025_init mssql2025 @args }
function Invoke-PodSql25Down { Invoke-PDDBSProject mssql2025 mssql2025 down @args }
Set-Alias pod-sql25-up       Invoke-PodSql25Up
Set-Alias pod-sql25-down     Invoke-PodSql25Down
function pod-sql25-stop     { Invoke-DDBSPodman stop --time 60 sqlserver25 @args }
function pod-sql25-start    { Invoke-DDBSPodman start sqlserver25 @args }
function pod-sql25-restart  { Invoke-DDBSPodman restart --time 60 sqlserver25 @args }
function pod-sql25-logs     { Invoke-DDBSPodman logs -f sqlserver25 @args }
function pod-sql25-shell    { Invoke-DDBSPodman exec -it sqlserver25 bash @args }
function pod-sql25-client   { Invoke-DDBSPodman exec -it sqlserver25 sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -No "$@"' sh @args }
function pod-sql25-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" sqlserver25 @args }

function Invoke-PodMySQLUp   { Invoke-PDDBSUp mysql mysql mysql_init mysql @args }
function Invoke-PodMySQLDown { Invoke-PDDBSProject mysql mysql down @args }
Set-Alias pod-mysql-up       Invoke-PodMySQLUp
Set-Alias pod-mysql-down     Invoke-PodMySQLDown
function pod-mysql-stop     { Invoke-DDBSPodman stop mysql8 @args }
function pod-mysql-start    { Invoke-DDBSPodman start mysql8 @args }
function pod-mysql-restart  { Invoke-DDBSPodman restart mysql8 @args }
function pod-mysql-logs     { Invoke-DDBSPodman logs -f mysql8 @args }
function pod-mysql-shell    { Invoke-DDBSPodman exec -it mysql8 bash @args }
function pod-mysql-client   { Invoke-DDBSPodman exec -it mysql8 sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -u root "$@"' sh @args }
function pod-mysql-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" mysql8 @args }

function Invoke-PodPg17Up   { Invoke-PDDBSUp postgresql17 postgresql17 postgresql17_init postgresql17 @args }
function Invoke-PodPg17Down { Invoke-PDDBSProject postgresql17 postgresql17 down @args }
Set-Alias pod-pg17-up       Invoke-PodPg17Up
Set-Alias pod-pg17-down     Invoke-PodPg17Down
function pod-pg17-stop     { Invoke-DDBSPodman stop postgresql17 @args }
function pod-pg17-start    { Invoke-DDBSPodman start postgresql17 @args }
function pod-pg17-restart  { Invoke-DDBSPodman restart postgresql17 @args }
function pod-pg17-logs     { Invoke-DDBSPodman logs -f postgresql17 @args }
function pod-pg17-shell    { Invoke-DDBSPodman exec -it postgresql17 bash @args }
function pod-pg17-psql     { Invoke-DDBSPodman exec -it postgresql17 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
function pod-pg17-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" postgresql17 @args }

function Invoke-PodPg18Up   { Invoke-PDDBSUp postgresql18 postgresql18 postgresql18_init postgresql @args }
function Invoke-PodPg18Down { Invoke-PDDBSProject postgresql18 postgresql18 down @args }
Set-Alias pod-pg18-up       Invoke-PodPg18Up
Set-Alias pod-pg18-down     Invoke-PodPg18Down
function pod-pg18-stop     { Invoke-DDBSPodman stop postgresql18 @args }
function pod-pg18-start    { Invoke-DDBSPodman start postgresql18 @args }
function pod-pg18-restart  { Invoke-DDBSPodman restart postgresql18 @args }
function pod-pg18-logs     { Invoke-DDBSPodman logs -f postgresql18 @args }
function pod-pg18-shell    { Invoke-DDBSPodman exec -it postgresql18 bash @args }
function pod-pg18-psql     { Invoke-DDBSPodman exec -it postgresql18 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh @args }
function pod-pg18-status   { Invoke-DDBSPodman inspect --format "{{.Name}}: {{.State.Status}}" postgresql18 @args }
