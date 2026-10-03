# Docker_DBs

Entorno multi-motor de bases de datos sobre Docker Compose o Podman. Diseñado para desarrollo, pruebas y laboratorio en Linux, Windows y macOS. Cada motor es independiente, con configuración explícita, named volumes y límites de recursos definidos.

**Uso**: Los servicios se ejecutan de forma independiente — no todos a la vez — para no consumir recursos innecesarios. Cada usuario levanta solo lo que necesita en cada momento.

## Resumen de cambios recientes

Se ha revisado y consolidado la base del proyecto en varias direcciones:

- Actualización de versiones de referencia: PostgreSQL 18/17 y MongoDB 8.0 con imágenes explícitas y perfiles estables.
- Corrección de la resolución de `DDBS_HOME` para rutas no estándar en Bash, PowerShell y Fish.
- Normalización de aliases y comandos para que el flujo de trabajo sea equivalente en las tres shells compatibles.
- Limpieza de componentes no mantenidos: eliminación del servicio de Oracle y simplificación del stack.
- Fortalecimiento del proyecto con validaciones automáticas (`tests/test_setup.py`) para comprobar perfiles, rutas con espacios, y compatibilidad de comandos.
- Revisión de seguridad y portabilidad: `BIND_ADDRESS` por motor, named volumes, init containers y documentación de recursos.
- Compatibilidad con Podman mediante `podman compose`, relabel SELinux en los bind mounts y aliases equivalentes en Bash, Fish y PowerShell.

Este repositorio mantiene un único README principal, ya que cada motor se gestiona desde su propio subdirectorio con `.env.example` y configuración específica; no hay documentación separada por servicio.

---

## Tabla de contenidos

- [Motores](#motores)
- [Requisitos](#requisitos)
- [Docker o Podman](#docker-o-podman)
- [Instalación rápida](#instalación-rápida)
- [Variable BIND_ADDRESS](#variable-bind_address)
- [Uso de comandos](#uso-de-comandos)
- [Conexión desde clientes externos](#conexión-desde-clientes-externos)
- [Arquitectura interna](#arquitectura-interna)
- [Límites de recursos](#límites-de-recursos)
- [Configuración avanzada](#configuración-avanzada)
- [Gestión de datos](#gestión-de-datos)
- [Nota: SQL Server y collation personalizada](#nota-sql-server-y-collation-personalizada)

---

## Motores

| Servicio | Motor | Imagen | Puerto host | Collation / Charset |
|---|---|---|---|---|
| `mssql2025` | SQL Server 2025 | `mcr.microsoft.com/mssql/server:2025-latest` | `1433` | `Latin1_General_100_CI_AS_SC` |
| `mssql2022` | SQL Server 2022 | `mcr.microsoft.com/mssql/server:2022-latest` | `1434` | `Latin1_General_100_CI_AS_SC` |
| `postgresql` (perfil `postgresql18`) | PostgreSQL 18 | `postgres:18` | `5432` | — |
| `postgresql17` | PostgreSQL 17 | `postgres:17` | `5433` | — |
| `mysql` | MySQL 8.4 LTS | `mysql:8.4` | `3306` | `utf8mb4_unicode_ci` |
| `mariadb` | MariaDB 11.4 LTS | `mariadb:11.4` | `3307` | `utf8mb4_unicode_ci` |
| `mongodb` | MongoDB 8.0 | `mongo:8.0` | `27017` | — |

Las imágenes provienen del fabricante o de Docker Official Images. Las etiquetas flotan dentro de la línea indicada, no hacia otra versión mayor; PostgreSQL usa la variante estándar, no Alpine. Los auxiliares usan `busybox:1`.

Fuentes: [tags de Microsoft](https://mcr.microsoft.com/v2/mssql/server/tags/list), catálogo oficial de [PostgreSQL](https://github.com/docker-library/official-images/blob/master/library/postgres), [MySQL](https://github.com/docker-library/official-images/blob/master/library/mysql), [MariaDB](https://github.com/docker-library/official-images/blob/master/library/mariadb), [MongoDB](https://github.com/docker-library/official-images/blob/master/library/mongo) y [BusyBox](https://github.com/docker-library/official-images/blob/master/library/busybox).

---

## Requisitos

- Git
- Uno de estos runtimes:
  - [Docker Engine](https://docs.docker.com/engine/install/) >= 24 con [Docker Compose](https://docs.docker.com/compose/install/) >= 2.20.
  - [Podman](https://podman.io/docs/installation) con un proveedor Compose compatible; comprobarlo con `podman compose version`.

## Docker o Podman

Los mismos `compose.yaml` funcionan con ambos runtimes. Los mounts de configuración usan `ro,Z`: Docker conserva el modo de solo lectura y Podman además aplica el relabel privado requerido en hosts con SELinux.

`podman compose` es un wrapper que delega en un proveedor externo. Los aliases `pod-*` usan siempre el Compose independiente de cada motor y funcionan con un proveedor que respete perfiles y `depends_on.condition: service_completed_successfully` (por ejemplo, `podman-compose` 1.5+ o Docker Compose v2). El orquestador raíz añade `include` con un `env_file` distinto por proyecto; `podman-compose` 1.5 no acepta ese formato, por lo que el flujo raíz bajo Podman requiere Docker Compose v2 como proveedor. Podman lo selecciona automáticamente si está disponible, o puede fijarse con `PODMAN_COMPOSE_PROVIDER` apuntando al ejecutable correspondiente.

En macOS y Windows, iniciar primero la VM con `podman machine start`. Docker y Podman mantienen almacenes de contenedores y volúmenes separados: un volumen del mismo nombre en ambos runtimes **no contiene los mismos datos**. Elegir un runtime para cada base existente y no cambiar esperando reutilizar sus datos.

---

## Instalación rápida

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio> Docker_DBs
cd Docker_DBs

# 2. Preparar solo el motor elegido, sin sobrescribir un .env existente
test -e postgresql18/.env || cp postgresql18/.env.example postgresql18/.env

# 3. Configurar las credenciales antes del primer arranque
nano postgresql18/.env

# 4a. Docker: usar el Compose independiente de ese motor
docker compose -f postgresql18/compose.yaml --env-file postgresql18/.env --profile postgresql18 up -d

# 4b. Podman: mismo proyecto con el runtime Podman
podman compose -f postgresql18/compose.yaml --env-file postgresql18/.env --profile postgresql18 up -d
```

Elegir `4a` o `4b`, no ambos. Este flujo y los helpers solo necesitan el `.env` del motor elegido. Desde su carpeta también funcionan `docker compose --env-file .env --profile postgresql18 up -d` y su equivalente con `podman compose`. Sin perfil, los servicios quedan desactivados.

**Flujo raíz:** el `compose.yaml` raíz incluye los siete proyectos y carga sus `.env` antes de seleccionar perfiles. Esto requiere un proveedor con soporte de `include`. Para usar comandos raíz con Docker o Podman, preparar **todos** los `.env` (incluido PostgreSQL 17), aunque se arranque un único motor:

```bash
for service in mssql2022 mssql2025 postgresql17 postgresql18 mysql mariadb mongodb; do
  test -e "$service/.env" || cp "$service/.env.example" "$service/.env"
done
```

Configurar sus valores antes del primer arranque. No hay contraseñas de respaldo incrustadas en Compose. Las variables exportadas en la shell tienen precedencia sobre los `.env`; evitar exportar nombres compartidos como `POSTGRES_USER`, `MSSQL_SA_PASSWORD` o `BIND_ADDRESS` si se desean valores diferentes por motor. Véase [Compose include](https://docs.docker.com/reference/compose-file/include/).

No alternar el flujo raíz y el independiente para contenedores ya creados dentro del mismo runtime: tienen distintos proyectos/redes Compose, pero comparten nombres de contenedor y volúmenes. Mantener el flujo con el que se crearon; cualquier transición debe planificarse sin `down -v`.

---

## Variable `BIND_ADDRESS`

Controla en qué interfaz de red se expone el puerto de cada servicio. Todos los `.env.example` ya vienen con `127.0.0.1` como valor por defecto.

### Valores disponibles

| Valor | Uso | Cuándo usarlo |
|---|---|---|
| `127.0.0.1` | Solo acceso local desde esta máquina | **Desarrollo local** (recomendado por defecto) |
| `<IP-de-tu-PC>` | Acceso desde tu red local (LAN) | Cuando otra PC o dispositivo en la misma red necesita conectarse. Ej: `192.168.1.100` |
| `0.0.0.0` | Todas las interfaces | Solo en **VMs (VMware/VirtualBox)** o **VPS** que necesiten acceso remoto |

### Escenarios de uso

**PC o laptop local (recomendado):**
```env
BIND_ADDRESS=127.0.0.1
```
El enlace queda limitado a la máquina local. Esto no configura TLS ni sustituye la autenticación. Si falta `BIND_ADDRESS`, la interpolación vacía puede publicar en todas las interfaces; mantener `127.0.0.1` para el laboratorio local.

**Red local (LAN):**
```env
BIND_ADDRESS=192.168.1.100
```
Usá la IP de tu PC en la red local. Permite que otras máquinas en la misma LAN se conecten.

**VMware / VirtualBox (modo Bridged):**
```env
BIND_ADDRESS=192.168.1.50
```
Si la VM usa modo **Bridged**, el contenedor se ve como un dispositivo más de la red. Usá la IP de la VM.

**VMware / VirtualBox (modo NAT):**
```env
BIND_ADDRESS=0.0.0.0
```
Si la VM usa modo **NAT**, necesitás configurar **port forwarding** del host a la VM en VirtualBox/VMware, o usar `0.0.0.0` para exponer en todas las interfaces de la VM.

**VPS o servidor remoto:**
```env
BIND_ADDRESS=0.0.0.0
```
Si el contenedor corre en un VPS y necesitás acceso remoto. **Importante**: configurá el firewall del SO para filtrar IPs y puertos.

---

## Uso de comandos

### Con aliases

El repositorio incluye helpers para **Bash**, **PowerShell** y **Fish**. Los nombres existentes usan Docker; cada alias tiene una variante Podman con prefijo `pod-` (`pg18-up` → `pod-pg18-up`). Cargar el archivo correspondiente a la shell utilizada:

#### Bash / Zsh (Linux, macOS, WSL2, Git Bash)

```bash
# Añadir estas líneas a ~/.bashrc (o ~/.zshrc), ajustando la ruta
export DDBS_HOME="$HOME/Docker_DBs"
source "$DDBS_HOME/.bash_aliases"
```

Ejecutar esas líneas también en la sesión actual. No sobrescribir un `~/.bash_aliases` existente; su carga automática depende del archivo de inicio de cada shell.

#### PowerShell 7+ (Windows)

```powershell
# Añadir estas líneas a $PROFILE, ajustando la ruta; ejecutarlas también ahora
$env:DDBS_HOME = Join-Path $HOME "Docker_DBs"
. (Join-Path $env:DDBS_HOME "DockerDBs.ps1")
```

Usar `$PROFILE` de la shell actual, no una ruta fija de Windows. Si no existe, crear su carpeta y archivo sin reemplazar un perfil existente. El punto inicial carga las funciones en la sesión; ejecutar el script sin ese punto no las conserva.

#### Fish (Linux)

```fish
# Añadir a ~/.config/fish/config.fish; ejecutar también en la sesión actual
set -gx DDBS_HOME "$HOME/Docker_DBs"
source "$DDBS_HOME/docker_dbs.fish"
```

#### Uso (igual para las 3 shells)

```bash
# Primera vez
sql25-up
pg18-up

# Operación diaria
sql25-stop
sql25-start

# Actualizar mantenimiento dentro de SQL Server 2025 (hacer respaldo primero)
sql25-up --pull always

# Estado global
ddbs-ps
ddbs-help   # cheatsheet completo

# Los equivalentes Podman conservan argumentos y operaciones
pod-sql25-up
pod-pg18-up --pull always
pod-ddbs-ps
pod-ddbs-help
```

> **Nota:** Si clonaste el repo en una ruta diferente a `~/Docker_DBs`, definí
> la variable antes de cargar los aliases:
> ```bash
> # Bash/Zsh
> export DDBS_HOME=/ruta/al/repo/Docker_DBs
>
> # PowerShell
> $env:DDBS_HOME = "C:\ruta\al\repo\Docker_DBs"
>
> # Fish
> set -gx DDBS_HOME /ruta/al/repo/Docker_DBs
> ```

### Con Compose directo (desde la raíz)

Requiere los siete `.env` preparados como se explica en la instalación. Los perfiles no evitan cargar los archivos incluidos. Los ejemplos usan Docker; para Podman, sustituir `docker compose` por `podman compose` y usar un proveedor compatible con `include`.

```bash
# Levantar un servicio
docker compose --profile postgresql18 up -d
docker compose --profile postgresql17 up -d
docker compose --profile mysql up -d
docker compose --profile mariadb up -d
docker compose --profile mongodb up -d
docker compose --profile mssql2025 up -d
docker compose --profile mssql2022 up -d

# Levantar varios servicios a la vez
docker compose --profile postgresql18 --profile mysql up -d

# Levantar todos los servicios (⚠ consume muchos recursos)
docker compose \
  --profile postgresql18 \
  --profile postgresql17 \
  --profile mysql \
  --profile mariadb \
  --profile mongodb \
  --profile mssql2025 \
  --profile mssql2022 \
  up -d
```

### Operaciones de contenedor

| Comando | Cuándo usarlo |
|---|---|
| `up` | Primera vez o tras un `down`. Crea el contenedor y lo arranca. |
| `start` | Uso diario. Reanuda un contenedor parado con `stop`. |
| `stop` | Detiene el contenedor sin eliminarlo; el motor puede escribir datos al cerrarse. |
| `down` | Elimina contenedores y redes del proyecto seleccionado; no recrea ni elimina named volumes sin `-v`. |
| `down -v` | Elimina el contenedor **y sus named volumes** (⚠ borra todos los datos). |
| `pull` | Descarga la nueva imagen sin afectar el contenedor activo. |
| `logs -f` | Muestra los logs en tiempo real. |
| `restart` | Reinicia el contenedor existente; no aplica cambios de imagen, variables ni definición Compose. |

### Estado de los contenedores

```bash
# Ver todos los contenedores del proyecto (activos e inactivos)
docker compose --profile '*' ps -a

# Ver solo los activos
docker compose --profile '*' ps

# Ver estado con health checks
docker ps --format "table {{.Names}}\t{{.Status}}"

# Equivalentes Podman
podman compose --profile '*' ps -a
podman ps --format "table {{.Names}}\t{{.Status}}"
```

---

## Conexión desde clientes externos (SSMS, DBeaver, DataGrip)

| Motor | Host | Puerto | Usuario | Notas |
|---|---|---|---|---|
| SQL Server 2025 | `BIND_ADDRESS` | `1433` | `sa` | Collation: `Latin1_General_100_CI_AS_SC` |
| SQL Server 2022 | `BIND_ADDRESS` | `1434` | `sa` | Puerto 1434 para no colisionar con 2025 |
| PostgreSQL 18 | `BIND_ADDRESS` | `5432` | `POSTGRES_USER` | — |
| PostgreSQL 17 | `BIND_ADDRESS` | `5433` | `POSTGRES_USER` | — |
| MySQL 8 | `BIND_ADDRESS` | `3306` | `MYSQL_USER` / `root` | — |
| MariaDB 11 | `BIND_ADDRESS` | `3307` | `MARIADB_USER` / `root` | Puerto 3307 para no colisionar con MySQL |
| MongoDB 8 | `BIND_ADDRESS` | `27017` | `MONGO_ROOT_USER` | Auth habilitado |

> **SSMS**: Usá el formato `IP,puerto` (ej: `192.168.1.100,1434`).

---

## Arquitectura interna

### Init containers

Todos los servicios usan init containers que preparan el entorno antes de que arranque el motor:

| Motor | Init containers | Función |
|---|---|---|
| SQL Server / PostgreSQL / MySQL / MariaDB / MongoDB | `<servicio>_init` (busybox) | Crea directorios en los named volumes y aplica `chown` al UID del motor |

Los auxiliares de permisos usan root. Los entrypoints oficiales pueden comenzar como root y cambiar al usuario del motor; omitir `user: "0"` no demuestra por sí solo que todo el arranque sea sin privilegios.

### UIDs de proceso

| Motor | UID |
|---|---|
| SQL Server | `10001` (usuario `mssql`) |
| PostgreSQL / MySQL / MariaDB / MongoDB | `999` |

### Named Volumes (portabilidad cross-platform)

Los datos se almacenan en named volumes del runtime elegido, lo que permite:
- Funcionamiento correcto en Docker Desktop, Podman, Linux nativo y VMs
- Sin problemas de permisos I/O entre el host y el contenedor
- Gestión nativa a través de `docker volume` o `podman volume`

```
<servicio>/
└── config/    ← archivos de configuración (montados :ro,Z como bind mounts)
```

Los named volumes se crean automáticamente al hacer `compose up`. `compose down -v` los elimina en el runtime activo.

---

## Límites de recursos

Todos los servicios tienen `deploy.resources` configurado. Los servicios se ejecutan de forma independiente, no todos a la vez. La distribución de recursos está diseñada para un mínimo de **8 GB de RAM y 4 cores**, permitiendo ejecutar hasta 2 motores simultáneamente.

### Container limits

| Motor | RAM límite | RAM reservada | CPU límite |
|---|---|---|---|
| SQL Server 2025 | 2.0 GB | 256 MB | 1.5 |
| SQL Server 2022 | 2.0 GB | 256 MB | 1.5 |
| PostgreSQL 18 | 1.5 GB | 256 MB | 1.5 |
| PostgreSQL 17 | 1.5 GB | 256 MB | 1.5 |
| MySQL 8.4 | 1.5 GB | 256 MB | 1.5 |
| MariaDB 11.4 | 1.5 GB | 256 MB | 1.5 |
| MongoDB 8.0 | 1.0 GB | 256 MB | 1.0 |

### Configuración interna de memoria

| Motor | Parámetro | Valor | Descripción |
|---|---|---|---|
| SQL Server (ambos) | `memorylimitmb` | 1500 MB | Límite interno del motor (~75% del container limit) |
| PostgreSQL (ambos) | `shared_buffers` | 375 MB | ~25% de 1.5 GB (cache de datos compartidos) |
| PostgreSQL (ambos) | `effective_cache_size` | 1100 MB | ~75% de 1.5 GB (pista al planner) |
| MySQL 8.4 | `innodb_buffer_pool_size` | 256 MB | ~17% de 1.5 GB |
| MariaDB 11.4 | `innodb_buffer_pool_size` | 256 MB | ~17% de 1.5 GB |
| MongoDB 8.0 | `cacheSizeGB` | 0.5 GB | ~50% de 1.0 GB (WiredTiger cache) |

### Reglas para ajustar memoria

Si cambiás el límite de RAM del contenedor, ajustá la configuración interna según estas reglas:

| Motor | Parámetro | Fórmula |
|---|---|---|
| PostgreSQL | `shared_buffers` | ~25% de la RAM del contenedor |
| PostgreSQL | `effective_cache_size` | ~75% de la RAM del contenedor |
| SQL Server | `memorylimitmb` | ~80-85% del container limit (dejar ~200MB para OS) |
| MySQL / MariaDB | `innodb_buffer_pool_size` | ~25% de la RAM del contenedor |
| MongoDB | `cacheSizeGB` | ~50% de la RAM del contenedor |

---

## Configuración avanzada

Los archivos de configuración de cada motor se encuentran en `<servicio>/config/` y se montan como volúmenes de solo lectura (`:ro,Z`) dentro del contenedor. `Z` permite el acceso con SELinux bajo Podman y no elimina el modo de solo lectura:

| Motor | Archivo | Parámetros clave |
|---|---|---|
| SQL Server | `mssql.conf` | `memorylimitmb`, `tlsprotocols`, `forceencryption` |
| PostgreSQL | `postgresql.conf` | `shared_buffers`, `effective_cache_size`, `max_connections`, autovacuum |
| PostgreSQL | `pg_hba.conf` | Reglas de autenticación por host |
| MySQL | `my.cnf` | `innodb_buffer_pool_size`, `max_connections`, binary log |
| MariaDB | `my.cnf` | Igual a MySQL + parámetros Aria |
| MongoDB | `mongod.conf` | `wiredTiger.cacheSizeGB`, `net.tls`, `operationProfiling` |

### Aplicar cambios de configuración

Un reinicio puede recargar archivos bind-mounted si el motor los lee al arrancar. Para cambios en Compose, variables o imágenes, usar `up -d` para recrear cuando corresponda; no basta con `restart`.

```bash
# Después de editar el archivo de config correspondiente
docker compose --profile postgresql18 restart
docker compose --profile mysql restart
docker compose --profile mssql2025 restart

# Con Podman, usar los aliases o sustituir el runtime
pod-pg18-restart
```

---

## Gestión de datos

Los datos de cada motor se almacenan en named volumes de Docker o Podman, creados automáticamente por el init container al primer arranque. Los almacenes de ambos runtimes son independientes.

Los volúmenes `*_backup` son solo almacenamiento: **no hay respaldos automáticos**. Crear y comprobar respaldos con las herramientas del motor antes de actualizar. No se cambian los nombres de volúmenes, bases predeterminadas ni puntos de montaje con estas etiquetas.

PostgreSQL 18 conserva el volumen en `/var/lib/postgresql`, con `PGDATA=/var/lib/postgresql/18/docker`; PostgreSQL 17 conserva `/var/lib/postgresql/data`. No mover datos ni conectar un volumen de otra versión mayor sin migración. Las etiquetas flotantes pueden cambiar la distribución base y las bibliotecas de collation: comprobar compatibilidad e índices al actualizar. Véase la [documentación oficial de la imagen](https://github.com/docker-library/docs/blob/master/postgres/README.md#pgdata).

```bash
# Ver el espacio usado por los datos de un servicio
docker system df -v | grep postgresql18
podman system df -v | grep postgresql18
```

**Borrado:** `down -v` elimina volúmenes nombrados del modelo Compose; no asumir que un perfil limita el borrado a ese motor en el archivo raíz. No usarlo para actualizar imágenes ni cambiar entre flujos. Los respaldos guardados en `*_backup` también pueden eliminarse.

### Actualizar una imagen

```bash
# 1. Crear y verificar un respaldo; revisar las notas de mantenimiento del motor

# 2. Descargar la nueva imagen
docker compose --profile postgresql18 pull

# 3. Recrear el contenedor con la nueva imagen
docker compose --profile postgresql18 up -d

# Con Podman, sustituir `docker` por `podman` en los pasos 2 y 3.
```

---

## Política de reinicio

Todos los servicios tienen `restart: "no"` — **no arrancan automáticamente** al iniciar Docker, Podman o el host. Así decidís vos qué servicios levantar en cada momento.

Para cambiar el comportamiento de un servicio, edita su `compose.yaml`:

| Valor | Comportamiento |
|---|---|
| `no` | No se reinicia nunca de forma automática (default) |
| `unless-stopped` | Se reinicia al arrancar el runtime/host, excepto si fue detenido manualmente |
| `always` | Se reinicia siempre, incluso si fue detenido manualmente |
| `on-failure` | Solo se reinicia si el proceso termina con error |

---

## Nota: SQL Server y collation personalizada

SQL Server 2022 con `Latin1_General_100_CI_AS_SC` (distinto al default) realiza un restart interno al primer arranque. El `start_period` del health check está fijado en **300s** para evitar falsos negativos. SQL Server 2025 tiene `start_period: 60s`.

### SQL Server y permisos de directorio

SQL Server 2022 y 2025 corren por defecto como el usuario `mssql` (UID `10001`). Este repo usa un **init container** (`mssql2025_init` / `mssql2022_init`) que prepara los named volumes con `chown 10001:0` antes de que arranque el motor. Por eso el proveedor Compose de Podman debe respetar `service_completed_successfully`. SQL Server arranca directamente como `mssql` sin necesidad de `user: "0"`.

---

## Estructura del repositorio

```
Docker_DBs/
├── compose.yaml              ← orquestador raíz (include de todos los servicios)
├── .bash_aliases             ← aliases para Bash/Zsh
├── DockerDBs.ps1             ← aliases para PowerShell 7+
├── docker_dbs.fish           ← aliases para Fish
├── mssql2025/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── mssql.conf
├── mssql2022/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── mssql.conf
├── postgresql18/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       ├── postgresql.conf
│       └── pg_hba.conf
├── postgresql17/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       ├── postgresql.conf
│       └── pg_hba.conf
├── mysql/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── my.cnf
├── mariadb/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── my.cnf
└── mongodb/
    ├── compose.yaml
    ├── .env.example
    └── config/
        └── mongod.conf
```

> **Nota**: Los datos, backups y logs se almacenan en named volumes (no en el repositorio). Usá `docker volume ls` o `podman volume ls` según el runtime.

## Validación sin iniciar bases de datos

```bash
bash -n .bash_aliases
fish --no-config --no-execute docker_dbs.fish
python3 tests/test_setup.py
git diff --check
```

Las pruebas simulan Docker y Podman para los helpers y ejecutan `compose config` y `podman compose --dry-run ... up` sobre copias temporales con valores ficticios. No leen los `.env` reales ni arrancan servicios. Comprueban ambos grupos de aliases, perfiles, aislamiento, rutas con espacios, argumentos, relabel SELinux y conservación de identidades persistentes frente a `HEAD`. La validación real de Podman se omite si falta `podman`; PowerShell se omite si falta `pwsh`. Revisar los tests omitidos antes de afirmar compatibilidad completa. Estas verificaciones **no demuestran** que los motores arranquen, acepten conexiones o sean compatibles con los datos existentes.
