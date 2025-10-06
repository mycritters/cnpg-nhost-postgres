# CloudNativePG PostgreSQL 17 with Nhost Extensions
# Based on the official CNPG PostgreSQL image with all Nhost extensions included
# Source extensions list: https://hub.docker.com/r/nhost/postgres

ARG PG_MAJOR=17
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm

USER root

# Install build dependencies and PostgreSQL development packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    postgresql-server-dev-${PG_MAJOR} \
    libpq-dev \
    libssl-dev \
    libkrb5-dev \
    libcurl4-openssl-dev \
    pkg-config \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Install PostGIS and related extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-postgis-3 \
    postgresql-${PG_MAJOR}-postgis-3-scripts \
    && rm -rf /var/lib/apt/lists/*

# Install other available PostgreSQL extensions from Debian repos
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-pgvector \
    postgresql-${PG_MAJOR}-cron \
    postgresql-${PG_MAJOR}-http \
    postgresql-${PG_MAJOR}-hypopg \
    postgresql-${PG_MAJOR}-ip4r \
    postgresql-${PG_MAJOR}-repack \
    postgresql-${PG_MAJOR}-squeeze \
    && rm -rf /var/lib/apt/lists/*

# Install TimescaleDB
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    lsb-release \
    wget \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && apt-get install -y timescaledb-2-postgresql-${PG_MAJOR} \
    && rm -rf /var/lib/apt/lists/*

# Install pg_hashids from source
RUN git clone https://github.com/iCyberon/pg_hashids.git /tmp/pg_hashids \
    && cd /tmp/pg_hashids \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pg_hashids

# Install pg_ivm (Incremental View Maintenance) from source
RUN git clone https://github.com/sraoss/pg_ivm.git /tmp/pg_ivm \
    && cd /tmp/pg_ivm \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pg_ivm

# Note: pg_jsonschema, pg_search (ParadeDB), and pgmq require Rust/pgrx and are complex to build.
# They are available in Nhost's image but require significant build tooling.
# For now, these extensions are documented but not installed.
# Users can install them separately or use pre-built binaries if needed.

# Configure shared_preload_libraries to include all necessary extensions
RUN echo "shared_preload_libraries = 'pg_stat_statements,timescaledb,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample

# Clean up build dependencies to reduce image size
RUN apt-get purge -y --auto-remove \
    build-essential \
    git \
    postgresql-server-dev-${PG_MAJOR} \
    cmake \
    wget

USER postgres

# Add labels
LABEL maintainer="CloudNativePG with Nhost Extensions" \
      org.opencontainers.image.description="PostgreSQL ${PG_MAJOR} with all Nhost extensions for CloudNativePG" \
      org.opencontainers.image.source="https://github.com/mycritters/cnpg-nhost-postgres"

# Extensions included:
# - PostGIS (postgis, postgis_raster, postgis_topology, postgis_tiger_geocoder, address_standardizer, address_standardizer_data_us)
# - TimescaleDB
# - pg_vector
# - pg_cron
# - pg_http
# - pg_hashids
# - pg_ivm
# - pg_repack
# - pg_squeeze
# - hypopg
# - ip4r
# - And all standard contrib extensions (pgcrypto, hstore, uuid-ossp, etc.)
#
# Note: pg_jsonschema, pg_search (ParadeDB), and pgmq require Rust/pgrx build tooling
# and are not included in this image to keep build complexity and size manageable.
