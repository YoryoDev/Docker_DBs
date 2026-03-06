# Docker_DBs

Repositorio de configuraciones Docker Compose para levantar motores de base de datos listos para desarrollo y pruebas en servidor (VM o nube). Cada motor vive en su propia carpeta con su configuración, variables de entorno y archivos de tuning independientes.

## Motores incluidos

| Servicio | Motor | Puerto host | Perfil |
|---|---|---|---|
| `mssql_en` | SQL Server 2025 (collation inglés) | `1433` | `mssql-en` |
| `mssql_es` | SQL Server 2025 (collation español) | `1434` | `mssql-es` |
| `postgresql` | PostgreSQL 18.2 | `5432` | `postgresql` |
| `mariadb` | MariaDB 11.4 LTS | `3307` | `mariadb` |
| `mysql` | MySQL 8.4 LTS | `3306` | `mysql` |
| `mongodb` | MongoDB 8.0 | `27017` | `mongodb` |

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
├── postgresql/
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
├── mysql/
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
cp postgresql/.env.example postgresql/.env
cp mysql/.env.example        mysql/.env
cp mariadb/.env.example      mariadb/.env
cp mongodb/.env.example      mongodb/.env
cp mssql_en/.env.example     mssql_en/.env
cp mssql_es/.env.example     mssql_es/.env
```

### 3. Editar el `.env` de cada servicio

Variables comunes en todos los `.env`:

```env
# IP de la interfaz de red del servidor/VM por donde se expondrá el puerto.
# Usa 0.0.0.0 solo si necesitas exponer en todas las interfaces (no recomendado).
BIND_ADDRESS=192.168.0.100
```

Cada motor tiene además sus propias credenciales — revisa el `.env.example` correspondiente para ver qué variables configurar.

---

## Uso

Todos los comandos se ejecutan desde la **raíz del repositorio** usando perfiles para seleccionar el servicio. También puedes entrar a la carpeta de cada servicio y ejecutar `docker compose` directamente.

### Levantar un servicio

```bash
docker compose --profile postgresql up -d
docker compose --profile mysql up -d
docker compose --profile mariadb up -d
docker compose --profile mongodb up -d
docker compose --profile mssql-en up -d
docker compose --profile mssql-es up -d
```

### Levantar varios servicios a la vez

```bash
docker compose --profile postgresql --profile mysql up -d
```

### Levantar todos los servicios

```bash
docker compose \
  --profile postgresql \
  --profile mysql \
  --profile mariadb \
  --profile mongodb \
  --profile mssql-en \
  --profile mssql-es \
  up -d
```

### Detener un servicio (sin eliminar datos)

```bash
docker compose --profile postgresql stop
```

### Detener y eliminar el contenedor (los volúmenes se conservan)

```bash
docker compose --profile postgresql down
```

### Eliminar el contenedor **y sus volúmenes** (⚠ borra todos los datos)

```bash
docker compose --profile postgresql down -v
```

---

## Logs

### Ver logs en tiempo real de un servicio

```bash
docker compose --profile postgresql logs -f
```

### Ver las últimas N líneas

```bash
docker compose --profile postgresql logs --tail=100
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
docker compose --profile postgresql pull

# 2. Recrear el contenedor con la nueva imagen
docker compose --profile postgresql up -d
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
docker compose --profile postgresql restart
```
