# Docker_DBs

Repositorio de configuraciones Docker Compose para levantar motores de base de datos listos para desarrollo y pruebas en servidor (VM o nube). Cada motor vive en su propia carpeta con su configuración, variables de entorno y archivos de tuning independientes.

## Motores incluidos

| Servicio | Motor | Imagen | Puerto host | Perfil |
|---|---|---|---|---|
| `mssql_en` | SQL Server 2025 (collation inglés) | `mssql/server:2025-CU3-ubuntu-22.04` | `1433` | `mssql-en` |
| `mssql_es` | SQL Server 2025 (collation español) | `mssql/server:2025-CU3-ubuntu-22.04` | `1434` | `mssql-es` |
| `postgresql18` | PostgreSQL 18.2 | `postgres:18.2-alpine3.23` | `5432` | `postgresql18` |
| `postgresql17` | PostgreSQL 17.4 LTS | `postgres:17.4-alpine3.21` | `5433` | `postgresql17` |
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
├── mssql_en/
│   ├── compose.yaml
│   ├── .env.example
│   └── config/
│       └── mssql.conf
├── mssql_es/
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
cp mssql_en/.env.example     mssql_en/.env
cp mssql_es/.env.example     mssql_es/.env
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
docker compose --profile mssql-en up -d
docker compose --profile mssql-es up -d
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
  --profile mssql-en \
  --profile mssql-es \
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
docker logs -f sqlserver25_en
docker logs -f sqlserver25_es
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

## Gestión de volúmenes

```bash
# Listar volúmenes del proyecto
docker volume ls | grep docker-db

# Inspeccionar un volumen
docker volume inspect docker-db_postgresql18_data

# Eliminar un volumen manualmente (⚠ borra los datos)
docker volume rm docker-db_postgresql18_data
```

---

## Conexión a las bases de datos

| Motor | Host | Puerto | Usuario | Notas |
|---|---|---|---|---|
| PostgreSQL | `BIND_ADDRESS` | `5432` | `POSTGRES_USER` | — |
| MySQL | `BIND_ADDRESS` | `3306` | `MYSQL_USER` / `root` | — |
| MariaDB | `BIND_ADDRESS` | `3307` | `MARIADB_USER` / `root` | Puerto 3307 para no colisionar con MySQL |
| MongoDB | `BIND_ADDRESS` | `27017` | `MONGO_ROOT_USER` | Auth habilitado |
| SQL Server EN | `BIND_ADDRESS` | `1433` | `sa` | — |
| SQL Server ES | `BIND_ADDRESS` | `1434` | `sa` | Puerto 1434 para instancia separada |

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

## Nota: SQL Server y permisos de volumen

SQL Server 2025 corre por defecto como el usuario `mssql` (UID `10001`), un usuario sin privilegios. Cuando Docker crea los volúmenes por primera vez, los directorios quedan con dueño `root`, lo que provoca este error al iniciar:

```
ERROR: Setup FAILED copying system data file: 5(Access is denied.)
```

### Solución aplicada

En este repo los servicios `mssql_en` y `mssql_es` tienen configurado `user: "0"`, lo que fuerza al contenedor a correr como `root` y elimina el problema de permisos:

```yaml
services:
  mssql_en:
    image: mcr.microsoft.com/mssql/server:2025-latest
    user: "0"    # corre como root para evitar errores de acceso en los volúmenes
```

### Mejores prácticas para este caso

| Opción | Seguridad | Complejidad | Recomendado para |
|---|---|---|---|
| `user: "0"` (root) — **opción actual** | ⚠ Baja | Baja | Desarrollo / VM local |
| Init container (`chown` previo) | ✅ Alta | Media | Staging / producción |
| Volumen con `tmpfs` o permisos correctos desde el SO | ✅ Alta | Alta | Producción en nube |

**Para entornos de producción o exposición pública se recomienda:**

1. **No usar `user: "0"`** — correr como root dentro del contenedor amplía la superficie de ataque. Si el contenedor es comprometido, el atacante tiene acceso root al filesystem del volumen.

2. **Usar un init container** que arregle los permisos antes de arrancar SQL Server:

```yaml
services:
  mssql_en_init:
    image: busybox:latest
    user: "0"
    command:
      - sh
      - -c
      - chown -R 10001:10001 /var/opt/mssql/data /var/opt/mssql/backup /var/opt/mssql/jobs /var/opt/mssql/log
    volumes:
      - sqlserver25_en_data:/var/opt/mssql/data
      - sqlserver25_en_backup:/var/opt/mssql/backup
      - sqlserver25_en_jobs:/var/opt/mssql/jobs
      - sqlserver25_en_log:/var/opt/mssql/log

  mssql_en:
    image: mcr.microsoft.com/mssql/server:2025-latest
    # sin user: "0" — corre como mssql (UID 10001)
    depends_on:
      mssql_en_init:
        condition: service_completed_successfully
```

3. **Eliminar volúmenes corruptos** antes de recrear el contenedor (si el contenedor nunca arrancó correctamente, no hay datos que perder):

```bash
docker volume rm docker-db_sqlserver25_en_data docker-db_sqlserver25_en_backup \
                 docker-db_sqlserver25_en_jobs  docker-db_sqlserver25_en_log
docker compose --profile mssql-en up -d
```
