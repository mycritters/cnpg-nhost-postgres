# CNPG PostgreSQL with Nhost Extensions

A custom CloudNativePG PostgreSQL image that includes all the extensions available in [Nhost's PostgreSQL image](https://hub.docker.com/r/nhost/postgres).

## Overview

This Docker image is based on the official CloudNativePG PostgreSQL image and includes all extensions that Nhost provides in their managed PostgreSQL offering. This allows you to use Nhost-compatible databases with CloudNativePG in your Kubernetes cluster.

## Base Image

- **Base**: `ghcr.io/cloudnative-pg/postgresql:17-bookworm`
- **PostgreSQL Version**: 17.x (latest)

## Extension Compatibility with Nhost

This image includes **all 60 out of 60** extensions from the Nhost PostgreSQL stack - **100% compatibility**!

### ✅ All Nhost Extensions Included (60)

### Geospatial Extensions
- **PostGIS** 3.5.3 - Geometry and geography spatial types
- **postgis_raster** - Raster types and functions
- **postgis_topology** - Topology spatial types
- **postgis_tiger_geocoder** - Tiger geocoder and reverse geocoder
- **address_standardizer** - Address parsing
- **address_standardizer_data_us** - US address standardization dataset

### Time-Series & Analytics
- **TimescaleDB** 2.21.1 - Time-series data optimization
- **pg_stat_statements** - Query statistics tracking

### Search & Text Processing
- **pg_trgm** - Trigram-based text similarity
- **fuzzystrmatch** - String similarity and distance
- **unaccent** - Text search dictionary that removes accents

### Data Types
- **hstore** - Key-value pair storage
- **ltree** - Hierarchical tree structures
- **citext** - Case-insensitive text
- **cube** - Multidimensional cubes
- **seg** - Line segments or floating-point intervals
- **isn** - International product numbering standards
- **uuid-ossp** - UUID generation
- **vector** 0.8.0 - Vector embeddings for AI/ML

### Job Scheduling
- **pg_cron** 1.6 - PostgreSQL job scheduler

### Networking & External Access
- **http** 1.7 - HTTP client for web page retrieval
- **postgres_fdw** - Foreign data wrapper for remote PostgreSQL
- **file_fdw** - Foreign data wrapper for flat files
- **dblink** - Connect to other PostgreSQL databases

### Performance & Maintenance
- **pg_repack** 1.5.2 - Reorganize tables with minimal locks
- **pg_squeeze** 1.8 - Remove unused space from relations
- **pg_prewarm** - Prewarm relation data
- **hypopg** 1.4.2 - Hypothetical indexes
- **pg_buffercache** - Examine shared buffer cache

### Development & Utilities
- **pg_hashids** 1.3 - Generate short unique IDs
- **pg_ivm** 1.11 - Incremental view maintenance
- **pgcrypto** - Cryptographic functions
- **ip4r** 2.4 - IPv4/IPv6 data types

### Monitoring & Inspection
- **pageinspect** - Low-level page inspection
- **pg_visibility** - Visibility map inspection
- **pg_walinspect** - WAL content inspection
- **pg_freespacemap** - Free space map examination
- **pgrowlocks** - Row-level locking information
- **pgstattuple** - Tuple-level statistics

### Rust-Based Extensions (3)

These extensions are built with Rust/pgrx but are **now included** using pre-built packages to avoid long build times:

- **pg_jsonschema** 0.3.3 - JSON schema validation (from Pigsty repository)
- **pg_search** (ParadeDB) 0.18.11 - Full-text search using BM25 (from ParadeDB GitHub releases)
- **pgmq** 1.6.1 - Lightweight message queue like AWS SQS (from Pigsty repository)

### Standard Contrib Extensions (24)
- **amcheck** 1.4 - Functions for verifying relation integrity
- **autoinc** 1.0 - Functions for autoincrementing fields
- **bloom** 1.0 - Bloom access method signature file based index
- **btree_gin** 1.3 - Support for indexing common datatypes in GIN
- **btree_gist** 1.7 - Support for indexing common datatypes in GiST
- **dict_int** 1.0 - Text search dictionary template for integers
- **dict_xsyn** 1.0 - Text search dictionary template for extended synonym processing
- **earthdistance** 1.2 - Calculate great-circle distances on the surface of the Earth
- **insert_username** 1.0 - Functions for tracking who changed a table
- **intagg** 1.1 - Integer aggregator and enumerator (obsolete)
- **intarray** 1.5 - Functions, operators, and index support for 1-D arrays of integers
- **lo** 1.1 - Large Object maintenance
- **moddatetime** 1.0 - Functions for tracking last modification time
- **pg_surgery** 1.0 - Extension to perform surgery on a damaged relation
- **plpgsql** 1.0 - PL/pgSQL procedural language
- **refint** 1.0 - Functions for implementing referential integrity (obsolete)
- **seg** 1.4 - Data type for representing line segments or floating-point intervals
- **sslinfo** 1.2 - Information about SSL certificates
- **tablefunc** 1.0 - Functions that manipulate whole tables, including crosstab
- **tcn** 1.0 - Triggered change notifications
- **tsm_system_rows** 1.0 - TABLESAMPLE method which accepts number of rows as a limit
- **tsm_system_time** 1.0 - TABLESAMPLE method which accepts time in milliseconds as a limit
- **unaccent** 1.1 - Text search dictionary that removes accents
- **uuid-ossp** 1.1 - Generate universally unique identifiers (UUIDs)

## Building the Image

### Using Make (Recommended)

```bash
# View all available targets
make help

# Build the image
make build

# Build and push to registry
make push

# Test the image
make test

# Verify all extensions are available
make verify-extensions

# List all available extensions
make list-extensions
```

### Using Docker directly

```bash
# Build for PostgreSQL 17 (default)
docker build -t mycritters/cnpg-postgres:17 .

# Build for a specific PostgreSQL major version
docker build --build-arg PG_MAJOR=16 -t mycritters/cnpg-postgres:16 .
```

### Common Make Targets

- `make build` - Build the Docker image with all tags
- `make push` - Build and push to Harbor registry
- `make test` - Run basic tests on critical extensions
- `make verify-extensions` - Verify all Nhost extensions are available
- `make list-extensions` - List all available extensions
- `make shell` - Open a shell in the container
- `make run` - Run PostgreSQL locally for testing
- `make clean` - Clean up images and artifacts
- `make new-tag` - Generate a new timestamp tag
- `make build-16` - Build PostgreSQL 16 version
- `make buildx` - Build multi-platform (amd64 + arm64)

## Using with CloudNativePG

### 1. Push to Your Registry

```bash
# Tag and push to your registry
docker tag mycritters/cnpg-postgres:17 harbor.example.com/library/cnpg-postgres:17
docker push harbor.example.com/library/cnpg-postgres:17
```

### 2. Create a ClusterImageCatalog

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ClusterImageCatalog
metadata:
  name: cnpg-nhost
spec:
  images:
    - image: harbor.example.com/library/cnpg-postgres:17
      major: 17
```

### 3. Create a CNPG Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-database
  namespace: my-app
spec:
  imageCatalogRef:
    name: cnpg-nhost
    major: 17
    kind: ClusterImageCatalog
    apiGroup: postgresql.cnpg.io

  instances: 3

  postgresql:
    pg_hba:
      - hostnossl all all all md5
    shared_preload_libraries:
      - pg_stat_statements
      - timescaledb
      - pg_cron

  bootstrap:
    initdb:
      database: myapp
      owner: myapp
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS postgis;
        - CREATE EXTENSION IF NOT EXISTS timescaledb;
        - CREATE EXTENSION IF NOT EXISTS vector;
        - CREATE EXTENSION IF NOT EXISTS pg_cron;
        - CREATE EXTENSION IF NOT EXISTS pgmq;

  storage:
    size: 10Gi
    storageClass: your-storage-class
```

## Extension Usage Examples

### Vector Similarity Search

```sql
CREATE EXTENSION vector;

CREATE TABLE embeddings (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(1536)
);

CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);
```

### TimescaleDB Time-Series

```sql
CREATE EXTENSION timescaledb;

CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  device_id INTEGER,
  temperature DOUBLE PRECISION
);

SELECT create_hypertable('metrics', 'time');
```

### Message Queue with pgmq

```sql
CREATE EXTENSION pgmq;

SELECT pgmq.create('my_queue');
SELECT pgmq.send('my_queue', '{"hello": "world"}'::jsonb);
SELECT * FROM pgmq.read('my_queue', 30, 1);
```

### PostGIS Geospatial Queries

```sql
CREATE EXTENSION postgis;

CREATE TABLE locations (
  id SERIAL PRIMARY KEY,
  name TEXT,
  geom GEOMETRY(Point, 4326)
);

SELECT name FROM locations
WHERE ST_DWithin(geom, ST_MakePoint(-122.4, 37.8)::geography, 1000);
```

## Configuration

### Shared Preload Libraries

The image is pre-configured with these shared preload libraries:
- `pg_stat_statements`
- `timescaledb`
- `pg_cron`

Add more in your CNPG Cluster spec if needed:

```yaml
spec:
  postgresql:
    shared_preload_libraries:
      - pg_stat_statements
      - timescaledb
      - pg_cron
      - auto_explain
```

## Architecture Support

Currently built for:
- **x86_64** (amd64)

ARM64 builds can be added using multi-platform builds:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t mycritters/cnpg-postgres:17 .
```

## Maintenance

### Updating Extensions

To update extensions in a running cluster:

```sql
ALTER EXTENSION postgis UPDATE;
ALTER EXTENSION timescaledb UPDATE;
ALTER EXTENSION vector UPDATE;
```

### Checking Installed Extensions

```sql
-- List all available extensions
SELECT * FROM pg_available_extensions ORDER BY name;

-- List installed extensions
SELECT * FROM pg_extension;
```

## How We Achieved 100% Compatibility

The Rust-based extensions (pg_jsonschema, pg_search, pgmq) are typically challenging to include because they require:
- Rust toolchain (~500MB)
- pgrx framework
- Long compilation times (20-30 minutes)

**Our Solution**: We use pre-built packages instead of building from source:
- **pg_jsonschema & pgmq**: Installed from the [Pigsty](https://pigsty.io) APT repository
- **pg_search**: Downloaded from [ParadeDB GitHub releases](https://github.com/paradedb/paradedb/releases)

This approach provides:
- ✅ Fast builds (~5-10 minutes instead of 30+ minutes)
- ✅ Small image size (no Rust toolchain needed)
- ✅ Reliable, tested packages
- ✅ Easy version updates

## Differences from Nhost

This image provides **all 60 extensions** from Nhost's PostgreSQL image with:
- CloudNativePG as the operator instead of custom Nhost management
- CloudNativePG backup and recovery patterns
- Standard PostgreSQL configuration
- No Nhost-specific initialization scripts
- **100% extension compatibility**

## License

This project packages open-source PostgreSQL extensions. Each extension has its own license:
- PostgreSQL: PostgreSQL License
- PostGIS: GPL v2
- TimescaleDB: Apache 2.0 (Community Edition)
- pgvector: PostgreSQL License
- See individual extension documentation for specific licensing

## Contributing

Contributions are welcome! Please open an issue or pull request.

## Support

For issues specific to:
- **CloudNativePG**: https://github.com/cloudnative-pg/cloudnative-pg
- **Nhost Extensions**: https://github.com/nhost/postgres
- **This Image**: Open an issue in this repository
