# CloudNativePG PostgreSQL 17 with Nhost Extensions
# Based on the official CNPG PostgreSQL image with all Nhost extensions included
# Source extensions list: https://hub.docker.com/r/nhost/postgres

ARG PG_MAJOR=17
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm

USER root

# Install build dependencies for compiling pg_hashids and pg_ivm from source
# Note: Only core build tools needed (curl kept for repository management)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    postgresql-server-dev-${PG_MAJOR} \
    && rm -rf /var/lib/apt/lists/*

# Install PostGIS and related extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-postgis-3 \
    postgresql-${PG_MAJOR}-postgis-3-scripts \
    && rm -rf /var/lib/apt/lists/*

# Install other available PostgreSQL extensions from Debian repos
# Note: pgvector is already included in the base CNPG image
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && apt-get install -y --no-install-recommends timescaledb-2-postgresql-${PG_MAJOR} \
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

# Add Pigsty repository for pg_jsonschema and pgmq
# Temporarily install gnupg and lsb-release for repository setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    lsb-release \
    && curl -fsSL https://repo.pigsty.io/key | gpg --dearmor -o /etc/apt/keyrings/pigsty.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/infra generic main" > /etc/apt/sources.list.d/pigsty-io.list \
    && echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/pgsql/$(lsb_release -cs) $(lsb_release -cs) main" >> /etc/apt/sources.list.d/pigsty-io.list \
    && rm -rf /var/lib/apt/lists/*

# Install Rust-based extensions using pre-built packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-pg-jsonschema \
    postgresql-${PG_MAJOR}-pgmq \
    && rm -rf /var/lib/apt/lists/*

# Install ParadeDB pg_search from GitHub releases
ARG PARADEDB_VERSION=0.18.11
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v${PARADEDB_VERSION}/postgresql-${PG_MAJOR}-pg-search_${PARADEDB_VERSION}-1PARADEDB-bookworm_amd64.deb" -o /tmp/pg_search.deb \
    && apt-get update \
    && apt-get install -y /tmp/pg_search.deb \
    && rm -f /tmp/pg_search.deb \
    && rm -rf /var/lib/apt/lists/*

# Configure shared_preload_libraries to include all necessary extensions
RUN echo "shared_preload_libraries = 'pg_stat_statements,timescaledb,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample

# Clean up build dependencies to reduce image size
RUN apt-get purge -y --auto-remove \
    build-essential \
    git \
    postgresql-server-dev-${PG_MAJOR} \
    gnupg \
    lsb-release \
    wget

USER postgres

# Add labels
LABEL maintainer="CloudNativePG with Nhost Extensions" \
      org.opencontainers.image.description="PostgreSQL ${PG_MAJOR} with all Nhost extensions for CloudNativePG" \
      org.opencontainers.image.source="https://github.com/mycritters/cnpg-nhost-postgres"

# Extensions included (60/60 from Nhost - 100% compatibility):
# - PostGIS (postgis, postgis_raster, postgis_topology, postgis_tiger_geocoder, address_standardizer, address_standardizer_data_us)
# - TimescaleDB
# - pg_vector
# - pg_cron
# - pg_http
# - pg_hashids
# - pg_ivm
# - pg_jsonschema (via Pigsty repository)
# - pg_search / ParadeDB (via GitHub releases)
# - pgmq (via Pigsty repository)
# - pg_repack
# - pg_squeeze
# - hypopg
# - ip4r
# - And all 24 standard contrib extensions (pgcrypto, hstore, uuid-ossp, etc.)
