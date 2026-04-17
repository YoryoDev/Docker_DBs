# Docker_DBs

Entorno multi-motor de bases de datos sobre Docker Compose. Diseñado para desarrollo, pruebas y laboratorio en servidor, VM o nube. Cada motor es independiente, con configuración explícita, bind mounts y límites de recursos definidos.

## Motores

| Servicio | Imagen | Puerto host | Collation / Charset |
|---|---|---|---|
| `mssql2025` | `mssql/server:2025-CU3-ubuntu-22.04` | `1433` | `Latin1_General_100_CI_AS_SC` |
| `mssql2022` | `mssql/server:2022-CU23-ubuntu-22.04` | `1434` | `Latin1_General_100_CI_AS_SC` |
| `postgresql18` | `postgres:18.2` | `5432` | — |
| `postgresql17` | `postgres:17.4` | `5433` | — |
| `mariadb` | `mariadb:11.4.10` | `3307` | `utf8mb4_unicode_ci` |
| `mysql` | `mysql:8.4.8` | `3306` | `utf8mb4_unicode_ci` |
| `mongodb` | `mongo:8.0.20` | `27017` | — |
| `oracle19c` | `enterprise:19.3.0.0` | `1521` / `5500` | `AL32UTF8` |

---

## Requisitos

- Docker Engine >= 24
- Docker Compose >= 2.20
- Git

---

## Instalación

```bash
git clone <url> Docker_DBs && cd Docker_DBs

# Copia y edita solo los servicios que vayas a usar
cp mssql2025/.env.example  mssql2025/.env
cp mssql2022/.env.example  mssql2022/.env
cp postgresql18/.env.example postgresql18/.env
cp postgresql17/.env.example postgresql17/.env
cp mariadb/.env.example    mariadb/.env
cp mysql/.env.example      mysql/.env
cp mongodb/.env.example    mongodb/.env
cp oracle19c/.env.example  oracle19c/.env
```

### Variable `BIND_ADDRESS`

Controla en qué interfaz se expone cada puerto:

```env
BIND_ADDRESS=127.0.0.1       # solo acceso local (recomendado por defecto)
BIND_ADDRESS=192.168.1.10    # acceso desde la red local
BIND_ADDRESS=0.0.0.0         # todas las interfaces (no recomendado)
```

---

## Uso de comandos

| Comando | Cuándo usarlo |
|---|---|
| `up` | Primera vez o tras un `down`. Crea el contenedor y lo arranca. |
| `start` | Uso diario. Reanuda un contenedor parado con `stop`. |
| `stop` | Uso diario. Pausa el contenedor sin eliminarlo ni tocar datos. |
| `down` | Cuando necesites recrear el contenedor (cambio de config, nueva imagen). Elimina el contenedor pero **no los datos**. |
| `pull` | Antes de actualizar. Descarga la nueva imagen sin afectar el contenedor activo. |
| `logs` | Diagnóstico. Muestra los logs en tiempo real. |
| `shell` | Acceso directo al cliente del motor dentro del contenedor. |

### Con aliases (`~/.bash_aliases`)

```bash
# Primera vez
mssql25-up

# Operación diaria
mssql25-stop
mssql25-start

# Actualizar versión
mssql25-stop
mssql25-pull
mssql25-down
mssql25-up

# Estado global
dbs-ps
dbs-help   # cheatsheet completo
```

### Con Docker Compose directo (desde la raíz)

```bash
docker compose --profile mssql2025 up -d
docker compose --profile mssql2025 start
docker compose --profile mssql2025 stop
docker compose --profile mssql2025 down
docker compose --profile mssql2025 logs -f
```

### Levantar varios servicios a la vez

```bash
docker compose --profile mssql2025 --profile mssql2022 up -d
```

---

## Conexión desde clientes externos (SSMS, DBeaver, DataGrip)

| Motor | Host | Puerto | Usuario |
|---|---|---|---|
| SQL Server 2025 | `BIND_ADDRESS` | `1433` | `sa` |
| SQL Server 2022 | `BIND_ADDRESS` | `1434` | `sa` |
| PostgreSQL 18 | `BIND_ADDRESS` | `5432` | `POSTGRES_USER` |
| PostgreSQL 17 | `BIND_ADDRESS` | `5433` | `POSTGRES_USER` |
| MySQL 8 | `BIND_ADDRESS` | `3306` | `MYSQL_USER` / `root` |
| MariaDB 11 | `BIND_ADDRESS` | `3307` | `MARIADB_USER` / `root` |
| MongoDB 8 | `BIND_ADDRESS` | `27017` | `MONGO_ROOT_USER` |

En SSMS usa el formato `IP,puerto` (ej: `192.168.79.128,1434`).

---

## Arquitectura interna

### Init containers

Todos los servicios usan un init container (`busybox`) que crea los directorios `data/`, `backup/`, `log/` y aplica el `chown` correcto antes de que arranque el motor:

| Motor | UID del proceso |
|---|---|
| SQL Server | `10001` (usuario `mssql`) |
| PostgreSQL / MySQL / MariaDB / MongoDB | `999` |
| Oracle 19c | `54321` (usuario `oracle`) |

El motor arranca **sin** `user: "0"` — nunca corre como root.

### Bind mounts (no named volumes)

Los datos viven en carpetas locales del host, lo que permite:
- Acceso directo a ficheros sin pasar por Docker
- Backups con herramientas del SO (`rsync`, `tar`, etc.)
- Portabilidad entre hosts

```
<servicio>/
├── data/      ← datos del motor
├── backup/    ← directorio de backups
├── log/       ← logs del motor
└── config/    ← archivos de configuración (montados :ro)
```

### Límites de recursos

Todos los servicios tienen `deploy.resources` configurado:

| Motor | RAM límite | RAM reservada | CPU límite |
|---|---|---|---|
| SQL Server (ambos) | 1.2 GB | 256 MB | 1.5 |
| PostgreSQL (ambos) | 1.5 GB | 256 MB | 1.5 |
| MySQL / MariaDB | 1.5 GB | 256 MB | 1.5 |
| MongoDB | 1.0 GB | 256 MB | 1.0 |
| Oracle 19c | 2.0 GB | 512 MB | 2.0 |

Además, SQL Server tiene `memorylimitmb = 900` en `mssql.conf` para limitar el motor internamente.
Oracle 19c tiene `INIT_SGA_SIZE=768` y `INIT_PGA_SIZE=256` (total 1024 MB para el engine).

### Health checks

Todos los servicios tienen health check configurado. Verificar estado:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
# o
dbs-ps-healthy
```

### Política de reinicio

Todos los servicios tienen `restart: no` — **no arrancan automáticamente** al iniciar Docker o el host. Para cambiar el comportamiento de un servicio edita su `compose.yaml`:

```yaml
restart: unless-stopped   # arranca con Docker, excepto si fue detenido manualmente
```

---

## Configuración avanzada

Edita el archivo de configuración correspondiente y reinicia el contenedor:

| Motor | Archivo | Parámetros clave |
|---|---|---|
| SQL Server | `mssql.conf` | `memorylimitmb`, `tlsprotocols`, `forceencryption` |
| PostgreSQL | `postgresql.conf` / `pg_hba.conf` | `shared_buffers`, `max_connections`, autenticación |
| MySQL | `my.cnf` | `innodb_buffer_pool_size`, `max_connections`, binary log |
| MariaDB | `my.cnf` | Igual que MySQL + parámetros Aria |
| MongoDB | `mongod.conf` | `wiredTiger`, `net.tls`, `operationProfiling` |

```bash
# Aplicar cambios de configuración
docker compose --profile postgresql18 restart
```

---

## Gestión de datos

```bash
# Espacio usado por un servicio
du -sh ~/Docker_DBs/postgresql18/data/

# Destruir y recrear desde cero (⚠ borra todos los datos)
docker compose --profile postgresql18 down
rm -rf ~/Docker_DBs/postgresql18/data/
docker compose --profile postgresql18 up -d
```

---

## Nota: SQL Server y primera ejecución con collation personalizada

SQL Server 2022 con `Latin1_General_100_CI_AS_SC` (distinto al default) realiza un restart interno al primer arranque. El `start_period` del health check está fijado en **300s** para evitar falsos negativos. SQL Server 2025 tiene `start_period: 60s`.


## Motores incluidos

| Servicio | Motor | Imagen | Puerto host | Perfil |
|---|---|---|---|---|
| `mssql2025` | SQL Server 2025 | `mssql/server:2025-CU3-ubuntu-22.04` | `1433` | `mssql2025` |
| `mssql2022` | SQL Server 2022 | `mssql/server:2022-CU23-ubuntu-22.04` | `1434` | `mssql2022` |
| `postgresql18` | PostgreSQL 18.2 | `postgres:18.2` | `5432` | `postgresql18` |
| `postgresql17` | PostgreSQL 17.4 LTS | `postgres:17.4` | `5433` | `postgresql17` |
| `mariadb` | MariaDB 11.4.10 LTS | `mariadb:11.4.10` | `3307` | `mariadb` |
| `mysql` | MySQL 8.4.8 LTS | `mysql:8.4.8` | `3306` | `mysql` |
| `mongodb` | MongoDB 8.0.20 | `mongo:8.0.20` | `27017` | `mongodb` |
| `oracle19c` | Oracle 19c EE | `enterprise:19.3.0.0` | `1521` / `5500` | `oracle19c` |

---

## Requisitos previos

- [Docker Engine](https://docs.docker.com/engine/install/) >= 24
- [Docker Compose](https://docs.docker.com/compose/install/) >= 2.20 (incluido en Docker Desktop)
- Git

---

## Estructura del repositorio

```
Docker_DBs/
├── compose.yaml          ← orquestador raíz (include + profiles)
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

---

## Instalación y configuración inicial

### 1. Clonar el repositorio

```bash
git clone <url-del-repositorio> Docker_DBs
cd Docker_DBs
```

### 2. Crear archivos `.env` a partir de los ejemplos

Cada servicio tiene su propio `.env.example`. Copia y edita solo los que vayas a usar:

```bash
# Ejemplos — repite para cada servicio que necesites
cp postgresql18/.env.example postgresql18/.env
cp mysql/.env.example        mysql/.env
cp mariadb/.env.example      mariadb/.env
cp mongodb/.env.example      mongodb/.env
cp mssql2025/.env.example     mssql2025/.env
cp mssql2022/.env.example     mssql2022/.env
cp oracle19c/.env.example     oracle19c/.env
```

### 3. Editar el `.env` de cada servicio

Variables comunes en todos los `.env`:

```env
# IP de la interfaz del servidor/VM por donde se expondrá el puerto.
# 127.0.0.1 → solo acceso local (valor por defecto, recomendado).
# Cambia a la IP de tu servidor (p. ej. 192.168.1.10) para acceso remoto en tu red.
# Usa 0.0.0.0 solo si necesitas exponer en todas las interfaces (no recomendado).
BIND_ADDRESS=127.0.0.1
```

Cada motor tiene además sus propias credenciales — revisa el `.env.example` correspondiente para ver qué variables configurar.

---

## Uso

Todos los comandos se ejecutan desde la **raíz del repositorio** usando perfiles para seleccionar el servicio. También puedes entrar a la carpeta de cada servicio y ejecutar `docker compose` directamente.

### Política de reinicio (`restart`)

Todos los servicios tienen configurado `restart: no` — el contenedor **no se inicia automáticamente** cuando arranca el host o el daemon de Docker. Así decides tú qué servicios levantar en cada momento.

Si quieres que un servicio arranque automáticamente al encender la VM o el servidor, cambia esa línea en el `compose.yaml` del servicio correspondiente:

```yaml
# Solo se inicia manualmente — valor por defecto en este repo
restart: no

# Se reinicia automáticamente salvo que lo hayas detenido tú con `docker stop`
restart: unless-stopped
```

| Valor | Comportamiento |
|---|---|
| `no` | No se reinicia nunca de forma automática |
| `unless-stopped` | Se reinicia al arrancar Docker/host, excepto si fue detenido manualmente |
| `always` | Se reinicia siempre, incluso si fue detenido manualmente |
| `on-failure` | Solo se reinicia si el proceso termina con error |

### Levantar un servicio

```bash
docker compose --profile postgresql18 up -d
docker compose --profile mysql up -d
docker compose --profile mariadb up -d
docker compose --profile mongodb up -d
docker compose --profile mssql2025 up -d
docker compose --profile mssql2022 up -d
docker compose --profile oracle19c up -d
```

### Levantar varios servicios a la vez

```bash
docker compose --profile postgresql18 --profile mysql up -d
```

### Levantar todos los servicios

```bash
docker compose \
  --profile postgresql18 \
  --profile mysql \
  --profile mariadb \
  --profile mongodb \
  --profile mssql2025 \
  --profile mssql2022 \
  --profile oracle19c \
  up -d
```

### Detener un servicio (sin eliminar datos)

```bash
docker compose --profile postgresql18 stop
```

### Detener y eliminar el contenedor (los volúmenes se conservan)

```bash
docker compose --profile postgresql18 down
```

### Eliminar el contenedor **y sus volúmenes** (⚠ borra todos los datos)

```bash
docker compose --profile postgresql18 down -v
```

---

## Logs

### Ver logs en tiempo real de un servicio

```bash
docker compose --profile postgresql18 logs -f
```

### Ver las últimas N líneas

```bash
docker compose --profile postgresql18 logs --tail=100
```

### Ver logs de un contenedor directamente

```bash
docker logs -f postgresql18
docker logs -f mysql8
docker logs -f mariadb
docker logs -f mongodb8
docker logs -f sqlserver25
docker logs -f oracle19c
```

---

## Estado de los contenedores

```bash
# Ver todos los contenedores del proyecto (activos e inactivos)
docker compose ps -a

# Ver solo los activos
docker compose ps
```

---

## Actualizar una imagen

```bash
# 1. Descargar la nueva imagen
docker compose --profile postgresql18 pull

# 2. Recrear el contenedor con la nueva imagen
docker compose --profile postgresql18 up -d
```

> Recuerda actualizar primero el tag de la imagen en el `compose.yaml` del servicio antes de hacer pull, para tener control explícito de la versión.

---

## Gestión de datos

Los datos de cada motor se almacenan en subdirectorios dentro de la carpeta del servicio (`data/`, `backup/`, `log/`). Estos directorios están en `.gitignore` y son creados automáticamente por el init container al primer arranque.

```bash
# Ver el espacio usado por los datos de un servicio
du -sh ~/Docker_DBs/postgresql18/data/

# Eliminar los datos de un servicio (⚠ borra todo)
docker compose --profile postgresql18 down
rm -rf ~/Docker_DBs/postgresql18/data/
```

---

## Conexión a las bases de datos

| Motor | Host | Puerto | Usuario | Notas |
|---|---|---|---|---|
| PostgreSQL | `BIND_ADDRESS` | `5432` | `POSTGRES_USER` | — |
| MySQL | `BIND_ADDRESS` | `3306` | `MYSQL_USER` / `root` | — |
| MariaDB | `BIND_ADDRESS` | `3307` | `MARIADB_USER` / `root` | Puerto 3307 para no colisionar con MySQL |
| MongoDB | `BIND_ADDRESS` | `27017` | `MONGO_ROOT_USER` | Auth habilitado |
| SQL Server 2025 | `BIND_ADDRESS` | `1433` | `sa` | Collation: `Latin1_General_100_CI_AS_SC` |
| SQL Server 2022 | `BIND_ADDRESS` | `1434` | `sa` | Puerto 1434 para no colisionar con SQL Server 2025 |
| Oracle 19c | `BIND_ADDRESS` | `1521` | `sys` / `system` / `pdbadmin` | SID: `ORCLCDB`, PDB: `ORCLPDB1`, OEM Express: puerto `5500` |

---

## Configuración avanzada

Los archivos de configuración de cada motor se encuentran en `<servicio>/config/` y se montan como volúmenes de solo lectura (`:ro`) dentro del contenedor:

| Motor | Archivo | Descripción |
|---|---|---|
| PostgreSQL | `postgresql.conf` | Memoria, WAL, planner, logging, autovacuum |
| PostgreSQL | `pg_hba.conf` | Reglas de autenticación por host |
| MySQL | `my.cnf` | InnoDB, conexiones, binary log, slow query |
| MariaDB | `my.cnf` | Igual a MySQL + ajustes específicos de MariaDB |
| MongoDB | `mongod.conf` | WiredTiger, red, TLS, profiler |
| SQL Server | `mssql.conf` | Puerto, TLS, memoria, rutas de archivos |
| Oracle 19c | `config/setup/*.sql` | Scripts post-creación (una sola vez) |
| Oracle 19c | `config/startup/*.sql` | Scripts post-arranque (cada inicio) |

Edita el archivo correspondiente y reinicia el contenedor para aplicar los cambios:

```bash
docker compose --profile postgresql18 restart
```

---

## Nota: SQL Server y permisos de directorio

SQL Server 2022 y 2025 corren por defecto como el usuario `mssql` (UID `10001`). Este repo usa un **init container** (`mssql2025_init` / `mssql2022_init`) que crea los directorios locales (`data/`, `backup/`, `jobs/`, `log/`) y les aplica `chown 10001:0` antes de que arranque el motor. SQL Server arranca directamente como `mssql` sin necesidad de `user: "0"`.

## Nota: Oracle 19c Enterprise Edition

### Requisito previo

Antes de poder descargar la imagen, debes aceptar la licencia OTN:

1. Crea una cuenta en [container-registry.oracle.com](https://container-registry.oracle.com).
2. Navega a **Database → enterprise** y acepta la licencia.
3. Autentícate desde tu máquina:

```bash
docker login container-registry.oracle.com
```

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


