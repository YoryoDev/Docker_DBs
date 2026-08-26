# Docker_DBs

Entorno multi-motor de bases de datos sobre Docker Compose. Diseñado para desarrollo, pruebas y laboratorio en cualquier plataforma (Windows con Docker Desktop, Linux nativo con Docker, VMs con Debian/Ubuntu/Arch, etc.). Cada motor es independiente, con configuración explícita, named volumes y límites de recursos definidos.

**Uso**: Los servicios se ejecutan de forma independiente — no todos a la vez — para no consumir recursos innecesarios. Cada usuario levanta solo lo que necesita en cada momento.

---

## Tabla de contenidos

- [Motores](#motores)
- [Requisitos](#requisitos)
- [Instalación rápida](#instalación-rápida)
- [Variable BIND_ADDRESS](#variable-bind_address)
- [Uso de comandos](#uso-de-comandos)
- [Conexión desde clientes externos](#conexión-desde-clientes-externos)
- [Arquitectura interna](#arquitectura-interna)
- [Límites de recursos](#límites-de-recursos)
- [Configuración avanzada](#configuración-avanzada)
- [Gestión de datos](#gestión-de-datos)
- [Nota: SQL Server y collation personalizada](#nota-sql-server-y-collation-personalizada)
- [Nota: Oracle 19c Enterprise Edition](#nota-oracle-19c-enterprise-edition)

---

## Motores

| Servicio | Motor | Imagen | Puerto host | Collation / Charset |
|---|---|---|---|---|
| `mssql2025` | SQL Server 2025 | `mssql/server:2025-CU3-ubuntu-22.04` | `1433` | `Latin1_General_100_CI_AS_SC` |
| `mssql2022` | SQL Server 2022 | `mssql/server:2022-CU23-ubuntu-22.04` | `1434` | `Latin1_General_100_CI_AS_SC` |
| `postgresql18` | PostgreSQL 18.2 | `postgres:18.2` | `5432` | — |
| `postgresql17` | PostgreSQL 17.4 LTS | `postgres:17.4` | `5433` | — |
| `mysql` | MySQL 8.4.8 LTS | `mysql:8.4.8` | `3306` | `utf8mb4_unicode_ci` |
| `mariadb` | MariaDB 11.4.10 LTS | `mariadb:11.4.10` | `3307` | `utf8mb4_unicode_ci` |
| `mongodb` | MongoDB 8.0.20 | `mongo:8.0.20` | `27017` | — |
| `oracle19c` | Oracle 19c EE | `enterprise:19.3.0.0` | `1521` / `5500` | `AL32UTF8` |

---

## Requisitos

- [Docker Engine](https://docs.docker.com/engine/install/) >= 24
- [Docker Compose](https://docs.docker.com/compose/install/) >= 2.20 (incluido en Docker Desktop)
- Git

---

## Instalación rápida

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio> Docker_DBs
cd Docker_DBs

# 2. Copiar los .env.example a .env (solo los servicios que vayas a usar)
cp postgresql18/.env.example postgresql18/.env
cp mysql/.env.example        mysql/.env
cp mariadb/.env.example      mariadb/.env
cp mongodb/.env.example      mongodb/.env
cp mssql2025/.env.example    mssql2025/.env
cp mssql2022/.env.example    mssql2022/.env
cp oracle19c/.env.example    oracle19c/.env

# 3. Editar credenciales en cada .env (opcional, los defaults funcionan)
nano postgresql18/.env

# 4. Levantar el servicio que necesites
docker compose --profile postgresql18 up -d
```

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
Los servicios solo son accesibles desde la misma máquina. Seguro por defecto.

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

El repo incluye aliases para **Bash**, **PowerShell** y **Fish**. Elegí el que uses:

#### Bash / Zsh (Linux, macOS, WSL2, Git Bash)

```bash
# Copiar aliases al home (se carga automáticamente en cada sesión)
cp .bash_aliases ~/
```

#### PowerShell 7+ (Windows)

```powershell
# Crear directorio de módulos si no existe
New-Item -ItemType Directory -Force -Path "$HOME\Documents\PowerShell\Modules\DockerDBs"

# Copiar el módulo
Copy-Item .\DockerDBs.psm1 "$HOME\Documents\PowerShell\Modules\DockerDBs\"

# Importar en la sesión actual
Import-Module DockerDBs

# Para que cargue automáticamente, agregar a tu profile.ps1:
#   notepad "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
# Agregar: Import-Module DockerDBs
```

#### Fish (Linux)

```fish
# Copiar aliases a conf.d (se carga automáticamente)
cp docker_dbs.fish ~/.config/fish/conf.d/

# Recargar la sesión actual
source ~/.config/fish/conf.d/docker_dbs.fish
```

#### Uso (igual para las 3 shells)

```bash
# Primera vez
mssql25-up
pg18-up

# Operación diaria
mssql25-stop
mssql25-start

# Actualizar versión
mssql25-stop
mssql25-down
mssql25-up

# Estado global
ddbs-ps
ddbs-help   # cheatsheet completo
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

### Con Docker Compose directo (desde la raíz)

```bash
# Levantar un servicio
docker compose --profile postgresql18 up -d
docker compose --profile mysql up -d
docker compose --profile mariadb up -d
docker compose --profile mongodb up -d
docker compose --profile mssql2025 up -d
docker compose --profile mssql2022 up -d
docker compose --profile oracle19c up -d

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
  --profile oracle19c \
  up -d
```

### Operaciones de contenedor

| Comando | Cuándo usarlo |
|---|---|
| `up` | Primera vez o tras un `down`. Crea el contenedor y lo arranca. |
| `start` | Uso diario. Reanuda un contenedor parado con `stop`. |
| `stop` | Uso diario. Pausa el contenedor sin eliminarlo ni tocar datos. |
| `down` | Recrea el contenedor (cambio de config, nueva imagen). Elimina el contenedor pero **no los datos**. |
| `down -v` | Elimina el contenedor **y sus named volumes** (⚠ borra todos los datos). |
| `pull` | Descarga la nueva imagen sin afectar el contenedor activo. |
| `logs -f` | Muestra los logs en tiempo real. |
| `restart` | Reinicia el contenedor (aplica cambios de configuración). |

### Estado de los contenedores

```bash
# Ver todos los contenedores del proyecto (activos e inactivos)
docker compose ps -a

# Ver solo los activos
docker compose ps

# Ver estado con health checks
docker ps --format "table {{.Names}}\t{{.Status}}"
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
| Oracle 19c | `BIND_ADDRESS` | `1521` | `sys` / `system` / `pdbadmin` | SID: `ORCLCDB`, PDB: `ORCLPDB1` |

> **SSMS**: Usá el formato `IP,puerto` (ej: `192.168.1.100,1434`).

> **Oracle OEM Express**: `https://BIND_ADDRESS:5500/em`

---

## Arquitectura interna

### Init containers

Todos los servicios usan init containers que preparan el entorno antes de que arranque el motor:

| Motor | Init containers | Función |
|---|---|---|
| SQL Server / PostgreSQL / MySQL / MariaDB / MongoDB | `<servicio>_init` (busybox) | Crea directorios en los named volumes y aplica `chown` al UID del motor |
| Oracle 19c | `oracle19c_login` → `oracle19c_init` | Login en Oracle Container Registry, luego crea directorios y aplica `chown` |

El motor arranca **sin** `user: "0"` — nunca corre como root.

### UIDs de proceso

| Motor | UID |
|---|---|
| SQL Server | `10001` (usuario `mssql`) |
| PostgreSQL / MySQL / MariaDB / MongoDB | `999` |
| Oracle 19c | `54321` (usuario `oracle`) |

### Named Volumes (portabilidad cross-platform)

Los datos se almacenan en Docker named volumes, lo que permite:
- Funcionamiento correcto en Docker Desktop (Windows/Mac), Linux nativo y VMs
- Sin problemas de permisos I/O entre el host y el contenedor
- Gestión nativa de datos a través de `docker volume`

```
<servicio>/
└── config/    ← archivos de configuración (montados :ro como bind mounts)
```

Los named volumes se crean automáticamente al hacer `docker compose up` y se eliminan con `docker compose down -v`.

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
| Oracle 19c | 2.0 GB | 512 MB | 2.0 |

### Configuración interna de memoria

| Motor | Parámetro | Valor | Descripción |
|---|---|---|---|
| SQL Server (ambos) | `memorylimitmb` | 1500 MB | Límite interno del motor (~75% del container limit) |
| PostgreSQL (ambos) | `shared_buffers` | 375 MB | ~25% de 1.5 GB (cache de datos compartidos) |
| PostgreSQL (ambos) | `effective_cache_size` | 1100 MB | ~75% de 1.5 GB (pista al planner) |
| MySQL 8.4 | `innodb_buffer_pool_size` | 256 MB | ~17% de 1.5 GB |
| MariaDB 11.4 | `innodb_buffer_pool_size` | 256 MB | ~17% de 1.5 GB |
| MongoDB 8.0 | `cacheSizeGB` | 0.5 GB | ~50% de 1.0 GB (WiredTiger cache) |
| Oracle 19c | `INIT_SGA_SIZE` | 768 MB | SGA del motor |
| Oracle 19c | `INIT_PGA_SIZE` | 256 MB | PGA del motor |
| Oracle 19c | **Total engine** | 1024 MB | ~50% de 2.0 GB |

### Reglas para ajustar memoria

Si cambiás el límite de RAM del contenedor, ajustá la configuración interna según estas reglas:

| Motor | Parámetro | Fórmula |
|---|---|---|
| PostgreSQL | `shared_buffers` | ~25% de la RAM del contenedor |
| PostgreSQL | `effective_cache_size` | ~75% de la RAM del contenedor |
| SQL Server | `memorylimitmb` | ~80-85% del container limit (dejar ~200MB para OS) |
| MySQL / MariaDB | `innodb_buffer_pool_size` | ~25% de la RAM del contenedor |
| MongoDB | `cacheSizeGB` | ~50% de la RAM del contenedor |
| Oracle | `INIT_SGA_SIZE` + `INIT_PGA_SIZE` | ~50% de la RAM del contenedor |

---

## Configuración avanzada

Los archivos de configuración de cada motor se encuentran en `<servicio>/config/` y se montan como volúmenes de solo lectura (`:ro`) dentro del contenedor:

| Motor | Archivo | Parámetros clave |
|---|---|---|
| SQL Server | `mssql.conf` | `memorylimitmb`, `tlsprotocols`, `forceencryption` |
| PostgreSQL | `postgresql.conf` | `shared_buffers`, `effective_cache_size`, `max_connections`, autovacuum |
| PostgreSQL | `pg_hba.conf` | Reglas de autenticación por host |
| MySQL | `my.cnf` | `innodb_buffer_pool_size`, `max_connections`, binary log |
| MariaDB | `my.cnf` | Igual a MySQL + parámetros Aria |
| MongoDB | `mongod.conf` | `wiredTiger.cacheSizeGB`, `net.tls`, `operationProfiling` |
| Oracle 19c | `config/setup/*.sql` | Scripts post-creación (una sola vez) |
| Oracle 19c | `config/startup/*.sql` | Scripts post-arranque (cada inicio) |

### Aplicar cambios de configuración

```bash
# Después de editar el archivo de config correspondiente
docker compose --profile postgresql18 restart
docker compose --profile mysql restart
docker compose --profile mssql2025 restart
```

---

## Gestión de datos

Los datos de cada motor se almacenan en Docker named volumes, creados automáticamente por el init container al primer arranque.

```bash
# Ver el espacio usado por los datos de un servicio
docker system df -v | grep postgresql18

# Eliminar los datos de un servicio (⚠ borra todo)
docker compose --profile postgresql18 down -v
docker compose --profile postgresql18 up -d
```

### Actualizar una imagen

```bash
# 1. Actualizar el tag de la imagen en compose.yaml (control explícito de versión)

# 2. Descargar la nueva imagen
docker compose --profile postgresql18 pull

# 3. Recrear el contenedor con la nueva imagen
docker compose --profile postgresql18 up -d
```

---

## Política de reinicio

Todos los servicios tienen `restart: no` — **no arrancan automáticamente** al iniciar Docker o el host. Así decidís vos qué servicios levantar en cada momento.

Para cambiar el comportamiento de un servicio, edita su `compose.yaml`:

| Valor | Comportamiento |
|---|---|
| `no` | No se reinicia nunca de forma automática (default) |
| `unless-stopped` | Se reinicia al arrancar Docker/host, excepto si fue detenido manualmente |
| `always` | Se reinicia siempre, incluso si fue detenido manualmente |
| `on-failure` | Solo se reinicia si el proceso termina con error |

---

## Nota: SQL Server y collation personalizada

SQL Server 2022 con `Latin1_General_100_CI_AS_SC` (distinto al default) realiza un restart interno al primer arranque. El `start_period` del health check está fijado en **300s** para evitar falsos negativos. SQL Server 2025 tiene `start_period: 60s`.

### SQL Server y permisos de directorio

SQL Server 2022 y 2025 corren por defecto como el usuario `mssql` (UID `10001`). Este repo usa un **init container** (`mssql2025_init` / `mssql2022_init`) que prepara los Docker named volumes con `chown 10001:0` antes de que arranque el motor. SQL Server arranca directamente como `mssql` sin necesidad de `user: "0"`.

---

## Nota: Oracle 19c Enterprise Edition

### Requisito previo (solo la primera vez)

La imagen de Oracle está en un registry privado que requiere aceptar la licencia OTN y autenticarse. El **login se realiza automáticamente** cada vez que haces `up` — solo tenés que configurar las credenciales en el `.env` del servicio.

1. Crea o inicia sesión en [container-registry.oracle.com](https://container-registry.oracle.com).
2. Navega a **Database → enterprise** y acepta la licencia OTN.
3. En el portal ve a tu perfil → **"Auth Token"** → genera una secret key.
   > Usa la **secret key** como contraseña, **no** la contraseña de tu cuenta SSO.
4. Rellena estas variables en `oracle19c/.env`:

```env
ORACLE_REGISTRY_USER=tu-correo@ejemplo.com
ORACLE_REGISTRY_PASS="tu-secret-key"   # entre comillas si contiene caracteres especiales
```

5. Ya podés levantar el servicio normalmente:

```bash
docker compose --profile oracle19c up -d
```

El init container `oracle19c_login` ejecuta `docker login` antes de que arranquen los demás servicios. Si las credenciales son incorrectas, el `up` fallará antes de intentar descargar la imagen.

### Primer arranque (~15-20 minutos)

La primera vez que levantes el contenedor, Oracle creará la base de datos desde cero. El health check tiene `start_period: 900s` para acomodar este proceso. **No interrumpas el contenedor durante la creación.**

```bash
# Monitorear el progreso del primer arranque
docker compose --profile oracle19c logs -f oracle19c
# Verás "DATABASE IS READY TO USE!" cuando termine
```

### Memoria y recursos

Oracle requiere un mínimo de 4 GB de RAM según la documentación oficial. En este entorno de lab está ajustado a **2 GB** (SGA 768 MB + PGA 256 MB). No es recomendable ejecutarlo simultáneamente con todos los demás motores.

### Conexión

```bash
# Como SYSDBA (dentro del contenedor)
docker exec -it oracle19c sqlplus / as sysdba

# Como pdbadmin a la PDB
docker exec -it oracle19c sqlplus pdbadmin/<pass>@ORCLPDB1

# Desde un cliente externo (SQL Developer, DBeaver, DataGrip)
# Host: BIND_ADDRESS   Puerto: 1521
# SID: ORCLCDB   Service Name: ORCLPDB1

# OEM Express (navegador)
# https://BIND_ADDRESS:5500/em
```

### Configuración

Oracle 19c en contenedor se configura mediante variables de entorno en la creación inicial (definidas en `.env`). Los ajustes posteriores van en:

- `config/setup/*.sql` — ejecutados una sola vez tras la creación de la base.
- `config/startup/*.sql` — ejecutados en cada arranque del contenedor.

### Scripts internos del contenedor

```bash
# Cambiar contraseña de SYS/SYSTEM/PDBADMIN
docker exec oracle19c ./setPassword.sh <nueva_contraseña>

# Reiniciar la instancia sin matar el contenedor
docker exec oracle19c /home/oracle/shutDown.sh
docker exec oracle19c /home/oracle/startUp.sh
```

---

## Estructura del repositorio

```
Docker_DBs/
├── compose.yaml              ← orquestador raíz (include de todos los servicios)
├── .bash_aliases             ← aliases para Bash/Zsh
├── DockerDBs.psm1            ← aliases para PowerShell 7+
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
├── mongodb/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── mongod.conf
└── oracle19c/
    ├── compose.yaml
    ├── .env.example
    └── config/
        ├── setup/       ← scripts post-creación (una sola vez)
        └── startup/     ← scripts post-arranque (cada inicio)
```

> **Nota**: Los datos, backups y logs se almacenan en Docker named volumes (no en el repositorio). Usá `docker volume ls` para verlos.
