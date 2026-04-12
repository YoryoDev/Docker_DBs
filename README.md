# Docker_DBs

Repositorio de configuraciones Docker Compose para levantar motores de base de datos listos para desarrollo y pruebas en servidor (VM o nube). Cada motor vive en su propia carpeta con su configuración, variables de entorno y archivos de tuning independientes.

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
└── mongodb/
    ├── compose.yaml
    ├── .env.example
    └── config/
        └── mongod.conf
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

Edita el archivo correspondiente y reinicia el contenedor para aplicar los cambios:

```bash
docker compose --profile postgresql18 restart
```

---

## Nota: SQL Server y permisos de directorio

SQL Server 2022 y 2025 corren por defecto como el usuario `mssql` (UID `10001`). Este repo usa un **init container** (`mssql2025_init` / `mssql2022_init`) que crea los directorios locales (`data/`, `backup/`, `jobs/`, `log/`) y les aplica `chown 10001:0` antes de que arranque el motor. SQL Server arranca directamente como `mssql` sin necesidad de `user: "0"`.


